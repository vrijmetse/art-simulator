import * as THREE from 'three';
import { GLTFLoader, type GLTF } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import * as SkeletonUtils from 'three/examples/jsm/utils/SkeletonUtils.js';
import { resolveClipName } from '../core/animationMatch';
import type { CharacterMotionState } from '../core/character';
import type { ToolMode } from '../core/types';

const sharedLoader = new GLTFLoader();
let decoderReady: Promise<void> | null = null;
const gltfCache = new Map<string, Promise<GLTF | null>>();

function ensureMeshopt(): Promise<void> {
  if (!decoderReady) {
    decoderReady = MeshoptDecoder.ready.then(() => {
      sharedLoader.setMeshoptDecoder(MeshoptDecoder);
    });
  }
  return decoderReady;
}

export function loadCachedGltf(modelPath: string): Promise<GLTF | null> {
  const cached = gltfCache.get(modelPath);
  if (cached) return cached;
  const p = ensureMeshopt().then(
    () =>
      new Promise<GLTF | null>((resolve) => {
        sharedLoader.load(
          `/models/${modelPath}`,
          (gltf) => resolve(gltf),
          undefined,
          () => resolve(null),
        );
      }),
  );
  gltfCache.set(modelPath, p);
  return p;
}

export interface RiggedActor {
  group: THREE.Group;
  modelRoot: THREE.Object3D | null;
  mixer: THREE.AnimationMixer | null;
  actions: Record<string, THREE.AnimationAction>;
  clipNames: string[];
  currentClip: string;
  lapMesh: THREE.Group | null;
  pelMesh: THREE.Group | null;
  readyPromise: Promise<void>;
  destroyed: boolean;
}

export type HomekeeperRig = RiggedActor;

function buildHandheldTools(invScale: number): { lapMesh: THREE.Group; pelMesh: THREE.Group } {
  const lapMesh = new THREE.Group();
  lapMesh.scale.setScalar(invScale);
  lapMesh.position.set(0, 0.04, 0.04);
  const cloth = new THREE.Mesh(
    new RoundedBoxGeometry(0.16, 0.045, 0.16, 2, 0.015),
    new THREE.MeshStandardMaterial({ color: 0x48cae4, roughness: 0.72 }),
  );
  lapMesh.add(cloth);

  const pelMesh = new THREE.Group();
  pelMesh.scale.setScalar(invScale);
  pelMesh.position.set(0, 0.02, 0.05);
  const stick = new THREE.Mesh(
    new THREE.CylinderGeometry(0.016, 0.018, 0.68, 10),
    new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.72 }),
  );
  stick.rotation.x = Math.PI * 0.28;
  stick.position.set(0, -0.04, 0.18);
  const mopHead = new THREE.Mesh(
    new RoundedBoxGeometry(0.24, 0.06, 0.12, 2, 0.02),
    new THREE.MeshStandardMaterial({ color: 0xfaf3e0, roughness: 0.85 }),
  );
  mopHead.position.set(0, -0.27, 0.40);
  pelMesh.add(stick, mopHead);
  pelMesh.visible = false;

  return { lapMesh, pelMesh };
}

export function createRiggedActor(
  modelPath: string,
  scale3D: number,
  contactShadowTex: THREE.Texture,
  withTools = false,
): RiggedActor {
  const group = new THREE.Group();

  const shadowDisc = new THREE.Mesh(
    new THREE.PlaneGeometry(0.58, 0.58),
    new THREE.MeshBasicMaterial({
      map: contactShadowTex,
      transparent: true,
      depthWrite: false,
      opacity: 0.72,
    }),
  );
  shadowDisc.rotation.x = -Math.PI / 2;
  shadowDisc.position.y = 0.005;
  shadowDisc.userData.sharedAsset = false;
  group.add(shadowDisc);

  const actor: RiggedActor = {
    group,
    modelRoot: null,
    mixer: null,
    actions: {},
    clipNames: [],
    currentClip: '',
    lapMesh: null,
    pelMesh: null,
    readyPromise: Promise.resolve(),
    destroyed: false,
  };

  actor.readyPromise = loadCachedGltf(modelPath).then((gltf) => {
    if (actor.destroyed || !gltf) return;
    const cloned = SkeletonUtils.clone(gltf.scene);
    cloned.scale.setScalar(scale3D);
    cloned.updateMatrixWorld(true);

    const box = new THREE.Box3().setFromObject(cloned);
    if (Number.isFinite(box.min.y)) {
      cloned.position.y -= box.min.y;
    }

    cloned.traverse((obj) => {
      if ((obj as THREE.Mesh).isMesh) {
        const m = obj as THREE.Mesh;
        m.castShadow = false;
        m.receiveShadow = false;
        m.userData.sharedAsset = true;
        const mats = Array.isArray(m.material) ? m.material : [m.material];
        for (const mat of mats) {
          if (mat) mat.userData.sharedAsset = true;
        }
      }
    });

    if (withTools) {
      const rightHand =
        cloned.getObjectByName('FistR') ??
        cloned.getObjectByName('LowerArmR') ??
        cloned.getObjectByName('arm-right');
      const ws = new THREE.Vector3();
      if (rightHand) rightHand.getWorldScale(ws);
      const invScale = rightHand && ws.x > 0.01 ? 1 / ws.x : 1 / scale3D;
      const tools = buildHandheldTools(invScale);
      actor.lapMesh = tools.lapMesh;
      actor.pelMesh = tools.pelMesh;
      if (rightHand) {
        rightHand.add(tools.lapMesh);
        rightHand.add(tools.pelMesh);
      } else {
        tools.lapMesh.position.set(0.22, 0.45, 0.2);
        tools.pelMesh.position.set(0.22, 0.45, 0.2);
        cloned.add(tools.lapMesh, tools.pelMesh);
      }
    }

    const mixer = new THREE.AnimationMixer(cloned);
    for (const clip of gltf.animations) {
      actor.actions[clip.name] = mixer.clipAction(clip);
      actor.clipNames.push(clip.name);
    }
    const initialClip =
      resolveClipName(actor.clipNames, ['Idle', 'idle']) ?? actor.clipNames[0] ?? '';
    if (initialClip && actor.actions[initialClip]) {
      actor.actions[initialClip].play();
      actor.currentClip = initialClip;
      mixer.update(0.02);
    }

    actor.modelRoot = cloned;
    actor.mixer = mixer;
    group.add(cloned);
  });

  return actor;
}

export function playActorAnimation(
  actor: RiggedActor,
  preferredTokens: string[],
  dtSec = 0,
): void {
  if (actor.destroyed) return;
  if (actor.mixer && dtSec > 0) {
    actor.mixer.update(dtSec);
  }
  const target = resolveClipName(actor.clipNames, preferredTokens);
  if (!target || target === actor.currentClip) return;

  const next = actor.actions[target];
  const prev = actor.actions[actor.currentClip];
  next.reset().fadeIn(0.15).play();
  if (prev) {
    prev.fadeOut(0.15);
  }
  actor.currentClip = target;
}

export function createHomekeeperRig(
  modelPath: string,
  contactShadowTex: THREE.Texture,
  scale3D = 0.56,
): HomekeeperRig {
  return createRiggedActor(modelPath, scale3D, contactShadowTex, true);
}

export function applyHomekeeperPose(
  rig: HomekeeperRig,
  state: CharacterMotionState,
  toolMode: ToolMode,
  dtSec = 0,
): void {
  rig.group.position.set(state.x, 0, state.z);
  rig.group.rotation.y = state.rotY;

  if (rig.lapMesh) rig.lapMesh.visible = toolMode === 'lap';
  if (rig.pelMesh) rig.pelMesh.visible = toolMode === 'pel';

  if (state.pose === 'walk') {
    playActorAnimation(rig, ['Walk', 'Run', 'Idle'], dtSec);
  } else if (state.pose === 'scrub') {
    playActorAnimation(rig, ['Punch', 'PickUp', 'Interact', 'Idle'], dtSec);
  } else if (state.pose === 'celebrate') {
    playActorAnimation(rig, ['Victory', 'Jump', 'EmoteYes', 'Idle'], dtSec);
  } else {
    playActorAnimation(rig, ['Idle', 'idle', 'static'], dtSec);
  }
}

export function disposeRiggedActor(actor: RiggedActor): void {
  actor.destroyed = true;
  if (actor.mixer) {
    actor.mixer.stopAllAction();
    if (actor.modelRoot) {
      actor.mixer.uncacheRoot(actor.modelRoot);
    }
    actor.mixer = null;
  }
  actor.group.traverse((obj) => {
    if ((obj as THREE.Mesh).isMesh) {
      const m = obj as THREE.Mesh;
      if (m.userData.sharedAsset) return;
      m.geometry?.dispose();
      const mats = Array.isArray(m.material) ? m.material : [m.material];
      for (const mat of mats) {
        if (!mat || mat.userData.sharedAsset) continue;
        mat.dispose();
      }
    }
  });
}
