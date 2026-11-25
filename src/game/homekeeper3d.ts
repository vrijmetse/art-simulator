import * as THREE from 'three';
import { GLTFLoader, type GLTF } from 'three/examples/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/examples/jsm/utils/SkeletonUtils.js';
import type { ToolMode } from '../core/types';
import type { CharacterMotionState } from '../core/character';

const charLoader = new GLTFLoader();
const gltfCache = new Map<string, Promise<GLTF | null>>();

function loadCachedCharacterGltf(modelPath: string): Promise<GLTF | null> {
  const cached = gltfCache.get(modelPath);
  if (cached) return cached;
  const p = new Promise<GLTF | null>((resolve) => {
    charLoader.load(
      `/models/${modelPath}`,
      (gltf) => resolve(gltf),
      undefined,
      () => resolve(null),
    );
  });
  gltfCache.set(modelPath, p);
  return p;
}

export interface RiggedActor {
  group: THREE.Group;
  modelRoot: THREE.Object3D | null;
  mixer: THREE.AnimationMixer | null;
  actions: Record<string, THREE.AnimationAction>;
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
  lapMesh.position.set(0, -0.14, 0.04);
  const cloth = new THREE.Mesh(
    new THREE.BoxGeometry(0.15, 0.05, 0.15),
    new THREE.MeshStandardMaterial({ color: 0x48cae4, roughness: 0.7 }),
  );
  lapMesh.add(cloth);

  const pelMesh = new THREE.Group();
  pelMesh.scale.setScalar(invScale);
  pelMesh.position.set(0, -0.12, 0.05);
  const stick = new THREE.Mesh(
    new THREE.CylinderGeometry(0.018, 0.018, 0.66, 8),
    new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.7 }),
  );
  stick.rotation.x = Math.PI * 0.28;
  stick.position.set(0, -0.04, 0.18);
  const mopHead = new THREE.Mesh(
    new THREE.BoxGeometry(0.24, 0.06, 0.12),
    new THREE.MeshStandardMaterial({ color: 0xfaf3e0, roughness: 0.85 }),
  );
  mopHead.position.set(0, -0.26, 0.40);
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
    new THREE.PlaneGeometry(0.56, 0.56),
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
    currentClip: '',
    lapMesh: null,
    pelMesh: null,
    readyPromise: Promise.resolve(),
    destroyed: false,
  };

  actor.readyPromise = loadCachedCharacterGltf(modelPath).then((gltf) => {
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
      const rightArm = cloned.getObjectByName('arm-right');
      const tools = buildHandheldTools(1 / scale3D);
      actor.lapMesh = tools.lapMesh;
      actor.pelMesh = tools.pelMesh;
      if (rightArm) {
        rightArm.add(tools.lapMesh);
        rightArm.add(tools.pelMesh);
      } else {
        tools.lapMesh.position.set(0.22, 0.45, 0.2);
        tools.pelMesh.position.set(0.22, 0.45, 0.2);
        cloned.add(tools.lapMesh, tools.pelMesh);
      }
    }

    const mixer = new THREE.AnimationMixer(cloned);
    for (const clip of gltf.animations) {
      actor.actions[clip.name] = mixer.clipAction(clip);
    }
    const initialClip = actor.actions.idle
      ? 'idle'
      : Object.keys(actor.actions)[0] || '';
    if (initialClip && actor.actions[initialClip]) {
      actor.actions[initialClip].play();
      actor.currentClip = initialClip;
    }

    actor.modelRoot = cloned;
    actor.mixer = mixer;
    group.add(cloned);
  });

  return actor;
}

export function playActorAnimation(
  actor: RiggedActor,
  preferredNames: string[],
  dtSec = 0,
): void {
  if (actor.destroyed) return;
  if (actor.mixer && dtSec > 0) {
    actor.mixer.update(dtSec);
  }
  const target = preferredNames.find((name) => Boolean(actor.actions[name]));
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
): HomekeeperRig {
  return createRiggedActor(modelPath, 1.28, contactShadowTex, true);
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
    playActorAnimation(rig, ['walk', 'run', 'idle'], dtSec);
  } else if (state.pose === 'scrub') {
    playActorAnimation(rig, ['interact-right', 'attack-melee-right', 'idle'], dtSec);
  } else if (state.pose === 'celebrate') {
    playActorAnimation(rig, ['jump', 'emote-yes', 'dance', 'idle'], dtSec);
  } else {
    playActorAnimation(rig, ['idle', 'static'], dtSec);
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
