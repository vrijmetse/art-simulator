import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import type { AvatarId } from '../core/types';
import { getAvatarSpec } from '../core/avatars';
import {
  createCharacterState,
  stepCharacterMotion,
  type CharacterMotionState,
} from '../core/character';
import {
  createNpcPatrols,
  stepNpcPatrol,
  type NeighborSpec,
  type NpcPatrolState,
} from '../core/neighborhood';
import { clampRoomXZ, intersectRayPlane, screenToNDC } from '../core/math3d';
import {
  applyHomekeeperPose,
  createHomekeeperRig,
  createRiggedActor,
  disposeRiggedActor,
  loadCachedGltf,
  playActorAnimation,
  type HomekeeperRig,
  type RiggedActor,
} from './homekeeper3d';
import { createContactShadowTexture, createRichFloorTexture } from './roomMaterials';

export interface StreetBadgePos {
  id: string;
  spec: NeighborSpec;
  x: number;
  y: number;
}

export interface Street3DCallbacks {
  onSelectNeighbor: (spec: NeighborSpec) => void;
  onBadgesUpdated: (badges: StreetBadgePos[]) => void;
}

interface NpcActorEntry {
  patrol: NpcPatrolState;
  actor: RiggedActor;
  hitProxy: THREE.Mesh;
}

export class Street3DView {
  private readonly phaserCanvas: HTMLCanvasElement;
  private readonly threeCanvas: HTMLCanvasElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene: THREE.Scene;
  private readonly camera: THREE.PerspectiveCamera;
  private readonly raycaster = new THREE.Raycaster();
  private readonly callbacks: Street3DCallbacks;

  private readonly contactShadowTex: THREE.CanvasTexture;
  private readonly player: HomekeeperRig;
  private playerState: CharacterMotionState;
  private npcs: NpcActorEntry[] = [];
  private activeNpcId: string | null = null;
  public readyPromise: Promise<void> = Promise.resolve();

  private orbitAngle = 0;
  private orbitTargetAngle = 0;
  private lastTickMs = 0;
  private lastRenderMs = 0;
  private rafId = 0;
  private destroyed = false;

  private readonly onResizeBound = () => this.syncCanvasBounds();
  private readonly onContextLostBound = (e: Event) => e.preventDefault();
  private readonly onContextRestoredBound = () => {
    this.renderer.shadowMap.needsUpdate = true;
  };

  constructor(
    phaserCanvas: HTMLCanvasElement,
    avatarId: AvatarId,
    callbacks: Street3DCallbacks,
  ) {
    this.phaserCanvas = phaserCanvas;
    this.callbacks = callbacks;

    this.threeCanvas = document.createElement('canvas');
    this.threeCanvas.id = 'three-layer';
    document.body.appendChild(this.threeCanvas);

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.threeCanvas,
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.shadowMap.autoUpdate = false;
    this.renderer.shadowMap.needsUpdate = true;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.06;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xd7ede0);
    this.scene.fog = new THREE.Fog(0xd7ede0, 11.5, 24);

    this.camera = new THREE.PerspectiveCamera(54, 450 / 800, 0.1, 45);
    this.updateCamera();

    this.contactShadowTex = createContactShadowTexture();
    this.setupLights();
    this.buildGroundAndCurbs();
    const sceneryPromise = this.loadSmoothScenery();

    const avatarSpec = getAvatarSpec(avatarId);
    this.playerState = createCharacterState(0.35, 1.15);
    this.player = createHomekeeperRig(
      `characters/${avatarSpec.modelName}`,
      this.contactShadowTex,
      avatarSpec.scale3D,
    );
    applyHomekeeperPose(this.player, this.playerState, 'lap', 0);
    this.scene.add(this.player.group);

    const patrols = createNpcPatrols();
    for (const patrol of patrols) {
      const actor = createRiggedActor(
        patrol.spec.modelPath,
        patrol.spec.scale3D,
        this.contactShadowTex,
        false,
        patrol.spec.kind === 'pet'
          ? {}
          : {
              skinHex: patrol.spec.portrait.skin,
              shirtHex: patrol.spec.portrait.accent,
              hairHex: patrol.spec.portrait.hair,
            },
      );
      actor.group.position.set(patrol.x, 0, patrol.z);
      actor.group.rotation.y = patrol.rotY;

      const hitProxy = new THREE.Mesh(
        new THREE.SphereGeometry(0.54, 8, 8),
        new THREE.MeshBasicMaterial({ visible: false }),
      );
      hitProxy.position.y = 0.48;
      hitProxy.userData = { npcId: patrol.spec.id };
      actor.group.add(hitProxy);
      this.scene.add(actor.group);

      this.npcs.push({ patrol, actor, hitProxy });
    }

    this.readyPromise = Promise.all([
      sceneryPromise,
      this.player.readyPromise,
      ...this.npcs.map((n) => n.actor.readyPromise),
    ]).then(() => undefined);

    this.syncCanvasBounds();
    window.addEventListener('resize', this.onResizeBound);
    this.threeCanvas.addEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.addEventListener('webglcontextrestored', this.onContextRestoredBound);
    this.rafId = requestAnimationFrame(this.tick);
  }

  private setupLights(): void {
    this.scene.add(new THREE.HemisphereLight(0xfff9eb, 0x7c9076, 1.05));

    const sun = new THREE.DirectionalLight(0xffe9c4, 1.38);
    sun.position.set(5.5, 8.5, 4.8);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.near = 1;
    sun.shadow.camera.far = 24;
    sun.shadow.camera.left = -6.0;
    sun.shadow.camera.right = 6.0;
    sun.shadow.camera.top = 6.0;
    sun.shadow.camera.bottom = -6.0;
    sun.shadow.bias = -0.001;
    this.scene.add(sun);
  }

  private buildGroundAndCurbs(): void {
    const lawn = new THREE.Mesh(
      new THREE.PlaneGeometry(24, 18),
      new THREE.MeshStandardMaterial({ color: 0x9ac687, roughness: 0.96 }),
    );
    lawn.rotation.x = -Math.PI / 2;
    lawn.position.set(0, -0.07, -1.8);
    lawn.receiveShadow = true;
    this.scene.add(lawn);

    const sidewalkTex = createRichFloorTexture('#EDE4D6', 'tile');
    sidewalkTex.repeat.set(8, 2);
    const sidewalk = new THREE.Mesh(
      new THREE.PlaneGeometry(14.0, 2.7),
      new THREE.MeshStandardMaterial({ map: sidewalkTex, roughness: 0.88 }),
    );
    sidewalk.rotation.x = -Math.PI / 2;
    sidewalk.position.set(0, 0.002, 0.65);
    sidewalk.receiveShadow = true;
    this.scene.add(sidewalk);

    // Soft ambient-occlusion shadow strips along house front
    const aoMat = new THREE.MeshBasicMaterial({
      map: this.contactShadowTex,
      transparent: true,
      depthWrite: false,
      opacity: 0.36,
    });
    for (const aoX of [-2.85, 0.0, 2.85]) {
      const houseAo = new THREE.Mesh(new THREE.PlaneGeometry(3.1, 2.4), aoMat);
      houseAo.rotation.x = -Math.PI / 2;
      houseAo.position.set(aoX, 0.004, -1.75);
      this.scene.add(houseAo);
    }

    // Beveled Indonesian black-and-white Kanstin curb blocks
    const blackMat = new THREE.MeshStandardMaterial({ color: 0x2f3348, roughness: 0.85 });
    const whiteMat = new THREE.MeshStandardMaterial({ color: 0xfdf6ec, roughness: 0.82 });
    const curbGeo = new RoundedBoxGeometry(0.54, 0.13, 0.18, 2, 0.03);
    for (let i = 0; i < 22; i++) {
      const curb = new THREE.Mesh(curbGeo, i % 2 === 0 ? whiteMat : blackMat);
      curb.position.set(-5.67 + i * 0.54, -0.02, 2.02);
      curb.castShadow = true;
      curb.receiveShadow = true;
      this.scene.add(curb);
    }

    // Smooth asphalt residential street
    const road = new THREE.Mesh(
      new THREE.PlaneGeometry(16.0, 3.6),
      new THREE.MeshStandardMaterial({ color: 0x4b5066, roughness: 0.92 }),
    );
    road.rotation.x = -Math.PI / 2;
    road.position.set(0, -0.03, 3.8);
    road.receiveShadow = true;
    this.scene.add(road);

    const dashMat = new THREE.MeshBasicMaterial({ color: 0xfdf6ec, transparent: true, opacity: 0.85 });
    for (let x = -5.4; x <= 5.4; x += 1.2) {
      const dash = new THREE.Mesh(new THREE.PlaneGeometry(0.58, 0.09), dashMat);
      dash.rotation.x = -Math.PI / 2;
      dash.position.set(x, -0.022, 3.4);
      this.scene.add(dash);
    }
  }

  private async placeSceneryModel(
    modelPath: string,
    x: number,
    z: number,
    scale: number,
    rotY = 0,
    castShadow = true,
  ): Promise<void> {
    const gltf = await loadCachedGltf(modelPath);
    if (this.destroyed || !gltf) return;

    const clone = gltf.scene.clone(true);
    clone.scale.setScalar(scale);
    clone.rotation.y = rotY;
    clone.updateMatrixWorld(true);

    const box = new THREE.Box3().setFromObject(clone);
    const minY = Number.isFinite(box.min.y) ? box.min.y : 0;
    clone.position.set(x, -minY, z);

    clone.traverse((obj) => {
      if ((obj as THREE.Mesh).isMesh) {
        const m = obj as THREE.Mesh;
        m.castShadow = castShadow;
        m.receiveShadow = true;
        m.userData.sharedAsset = true;
        const mats = Array.isArray(m.material) ? m.material : [m.material];
        for (const mat of mats) {
          if (!mat) continue;
          mat.userData.sharedAsset = true;
          const std = mat as THREE.MeshStandardMaterial;
          if (typeof std.opacity === 'number' && std.opacity <= 0.05) {
            std.opacity = 1;
            std.alphaTest = 0;
            std.transparent = false;
            std.needsUpdate = true;
          }
        }
      }
    });

    this.scene.add(clone);
  }

  private async loadSmoothScenery(): Promise<void> {
    const placements: Promise<void>[] = [
      // Homeowner residential houses (outside view of the houses we clean)
      this.placeSceneryModel('street/building-type-a.glb', -2.85, -1.75, 0.36, 0, true),
      this.placeSceneryModel('street/building-type-b.glb', 0.0, -1.85, 0.36, 0, true),
      this.placeSceneryModel('street/building-type-f.glb', 2.85, -1.75, 0.36, 0, true),
      this.placeSceneryModel('street/building-type-c.glb', -5.4, -1.75, 0.36, 0, true),
      this.placeSceneryModel('street/building-type-a.glb', 5.4, -1.75, 0.36, 0, true),

      // Yard wooden fences & porch planters
      this.placeSceneryModel('street/fence-1x3.glb', -1.65, -0.52, 0.42, 0, true),
      this.placeSceneryModel('street/fence-1x3.glb', 1.65, -0.52, 0.42, 0, true),
      this.placeSceneryModel('street/planter.glb', -0.78, -0.45, 0.45, 0, true),
      this.placeSceneryModel('street/planter.glb', 0.78, -0.45, 0.45, 0, true),

      // Quaternius organic stylized trees & flowering bushes
      this.placeSceneryModel('street/common-tree-1.glb', -4.2, -0.85, 0.29, 0.4, true),
      this.placeSceneryModel('street/common-tree-2.glb', -1.42, -0.78, 0.24, 1.1, true),
      this.placeSceneryModel('street/common-tree-1.glb', 1.42, -0.78, 0.25, -0.6, true),
      this.placeSceneryModel('street/common-tree-2.glb', 4.2, -0.85, 0.29, 0.8, true),
      this.placeSceneryModel('street/bush-common-flowers.glb', -2.1, -0.42, 0.28, 0.2, false),
      this.placeSceneryModel('street/bush-common.glb', 0.48, -0.42, 0.26, 0.9, false),
      this.placeSceneryModel('street/bush-common-flowers.glb', 2.25, -0.42, 0.28, -0.4, false),

      // Parked family cars along the residential street
      this.placeSceneryModel('street/sedan.glb', -2.4, 2.78, 0.46, Math.PI / 2, true),
      this.placeSceneryModel('street/van.glb', 2.65, 4.12, 0.46, -Math.PI / 2, true),
    ];

    await Promise.all(placements);
    if (this.destroyed) return;
    this.renderer.shadowMap.needsUpdate = true;
  }

  rotateStep(deltaRad: number): void {
    this.orbitTargetAngle = Math.max(-0.45, Math.min(0.45, this.orbitTargetAngle + deltaRad));
  }

  resumeNpc(npcId: string | null): void {
    if (!npcId) return;
    const entry = this.npcs.find((n) => n.patrol.spec.id === npcId);
    if (entry) entry.patrol.talking = false;
    if (this.activeNpcId === npcId) this.activeNpcId = null;
  }

  handleTap(clientX: number, clientY: number): void {
    if (this.destroyed) return;
    const rect = this.phaserCanvas.getBoundingClientRect();
    const ndc = screenToNDC(clientX, clientY, rect);
    if (!ndc) return;

    this.raycaster.setFromCamera(new THREE.Vector2(ndc.x, ndc.y), this.camera);

    const proxies = this.npcs.map((n) => n.hitProxy);
    const hits = this.raycaster.intersectObjects(proxies, false);
    if (hits.length > 0) {
      const npcId = hits[0].object.userData.npcId as string;
      const entry = this.npcs.find((n) => n.patrol.spec.id === npcId);
      if (entry) {
        if (this.activeNpcId && this.activeNpcId !== npcId) {
          this.resumeNpc(this.activeNpcId);
        }
        this.activeNpcId = npcId;
        entry.patrol.talking = true;
        const [wx, wz] = clampRoomXZ(entry.patrol.x - 0.55, entry.patrol.z + 0.15, 2.45);
        this.playerState = {
          ...this.playerState,
          targetX: wx,
          targetZ: wz,
          lookX: entry.patrol.x,
          lookZ: entry.patrol.z,
          pose: 'walk',
          walkTimer: 0,
        };
        entry.actor.group.rotation.y = Math.atan2(
          this.playerState.x - entry.patrol.x,
          this.playerState.z - entry.patrol.z,
        );
        this.callbacks.onSelectNeighbor(entry.patrol.spec);
        return;
      }
    }

    const o = this.raycaster.ray.origin;
    const d = this.raycaster.ray.direction;
    const hit = intersectRayPlane([o.x, o.y, o.z], [d.x, d.y, d.z], [0, 0, 0], [0, 1, 0]);
    if (!hit) return;
    const tx = Math.max(-2.5, Math.min(2.5, hit[0]));
    const tz = Math.max(0.05, Math.min(1.7, hit[2]));
    this.playerState = {
      ...this.playerState,
      targetX: tx,
      targetZ: tz,
      lookX: tx,
      lookZ: tz,
      pose: 'walk',
      walkTimer: 0,
    };
  }

  private updateCamera(): void {
    const baseAngle = 0.42 + this.orbitAngle;
    const radius = 8.6;
    this.camera.position.set(Math.sin(baseAngle) * radius, 5.8, Math.cos(baseAngle) * radius);
    this.camera.lookAt(0, 0.35, 0.35);
  }

  syncCanvasBounds(): void {
    if (this.destroyed) return;
    const rect = this.phaserCanvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    this.threeCanvas.style.left = `${rect.left}px`;
    this.threeCanvas.style.top = `${rect.top}px`;
    this.threeCanvas.style.width = `${rect.width}px`;
    this.threeCanvas.style.height = `${rect.height}px`;
    this.renderer.setSize(rect.width, rect.height, false);
    this.camera.aspect = rect.width / rect.height;
    this.camera.updateProjectionMatrix();
  }

  private tick = (nowMs: number): void => {
    if (this.destroyed) return;
    this.rafId = requestAnimationFrame(this.tick);
    if (this.lastRenderMs > 0 && nowMs - this.lastRenderMs < 32) return;
    this.lastRenderMs = nowMs;
    const dtSec = this.lastTickMs > 0 ? Math.min(0.05, (nowMs - this.lastTickMs) / 1000) : 0.032;
    this.lastTickMs = nowMs;

    if (Math.abs(this.orbitTargetAngle - this.orbitAngle) > 0.005) {
      this.orbitAngle += (this.orbitTargetAngle - this.orbitAngle) * 0.2;
      this.updateCamera();
    }

    const step = stepCharacterMotion(this.playerState, dtSec, []);
    this.playerState = step.state;
    applyHomekeeperPose(this.player, this.playerState, 'lap', dtSec);

    const badges: StreetBadgePos[] = [];
    const v = new THREE.Vector3();
    for (const entry of this.npcs) {
      entry.patrol = stepNpcPatrol(entry.patrol, dtSec);
      entry.actor.group.position.set(entry.patrol.x, 0, entry.patrol.z);
      if (!entry.patrol.talking) {
        entry.actor.group.rotation.y = entry.patrol.rotY;
        playActorAnimation(entry.actor, ['Walk', 'Jump', 'Run', 'Idle'], dtSec);
      } else {
        playActorAnimation(entry.actor, ['Victory', 'EmoteYes', 'Jump', 'Idle'], dtSec);
      }

      const headHeight = entry.patrol.spec.kind === 'pet' ? 0.68 : 1.18;
      v.set(entry.patrol.x, headHeight, entry.patrol.z).project(this.camera);
      badges.push({
        id: entry.patrol.spec.id,
        spec: entry.patrol.spec,
        x: (v.x + 1) * 0.5 * 450,
        y: (1 - v.y) * 0.5 * 800,
      });
    }

    this.callbacks.onBadgesUpdated(badges);
    this.renderer.render(this.scene, this.camera);
  };

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    cancelAnimationFrame(this.rafId);
    window.removeEventListener('resize', this.onResizeBound);
    this.threeCanvas.removeEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.removeEventListener('webglcontextrestored', this.onContextRestoredBound);

    this.scene.remove(this.player.group);
    disposeRiggedActor(this.player);
    for (const entry of this.npcs) {
      this.scene.remove(entry.actor.group);
      disposeRiggedActor(entry.actor);
    }

    this.scene.traverse((obj) => {
      if ((obj as THREE.Mesh).isMesh) {
        const m = obj as THREE.Mesh;
        if (m.userData.sharedAsset) return;
        m.geometry?.dispose();
        const mats = Array.isArray(m.material) ? m.material : [m.material];
        for (const mat of mats) {
          if (!mat || mat.userData.sharedAsset) continue;
          const std = mat as THREE.MeshStandardMaterial;
          if (std.map && std.map !== this.contactShadowTex) std.map.dispose();
          mat.dispose();
        }
      }
    });

    this.contactShadowTex.dispose();
    this.renderer.dispose();
    this.threeCanvas.remove();
  }
}
