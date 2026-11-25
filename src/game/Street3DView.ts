import * as THREE from 'three';
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
  playActorAnimation,
  type HomekeeperRig,
  type RiggedActor,
} from './homekeeper3d';
import {
  createContactShadowTexture,
  createRichFloorTexture,
  createTerracottaRoofTexture,
} from './roomMaterials';

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

  private orbitAngle = 0;
  private orbitTargetAngle = 0;
  private lastTickMs = 0;
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
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.shadowMap.autoUpdate = false;
    this.renderer.shadowMap.needsUpdate = true;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xc8e7d5);

    this.camera = new THREE.PerspectiveCamera(54, 450 / 800, 0.1, 45);
    this.updateCamera();

    this.contactShadowTex = createContactShadowTexture();
    this.setupLights();
    this.buildStreetEnvironment();

    const avatarSpec = getAvatarSpec(avatarId);
    this.playerState = createCharacterState(0.35, 1.15);
    this.player = createHomekeeperRig(`characters/${avatarSpec.modelName}`, this.contactShadowTex);
    applyHomekeeperPose(this.player, this.playerState, 'lap', 0);
    this.scene.add(this.player.group);

    const patrols = createNpcPatrols();
    for (const patrol of patrols) {
      const actor = createRiggedActor(
        patrol.spec.modelPath,
        patrol.spec.scale3D,
        this.contactShadowTex,
        false,
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

    this.syncCanvasBounds();
    window.addEventListener('resize', this.onResizeBound);
    this.threeCanvas.addEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.addEventListener('webglcontextrestored', this.onContextRestoredBound);
    this.rafId = requestAnimationFrame(this.tick);
  }

  private setupLights(): void {
    this.scene.add(new THREE.HemisphereLight(0xfff7e6, 0x768970, 0.95));

    const sun = new THREE.DirectionalLight(0xffe6ba, 1.45);
    sun.position.set(5.5, 8.2, 4.5);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.near = 1;
    sun.shadow.camera.far = 22;
    sun.shadow.camera.left = -5.5;
    sun.shadow.camera.right = 5.5;
    sun.shadow.camera.top = 5.5;
    sun.shadow.camera.bottom = -5.5;
    sun.shadow.bias = -0.001;
    this.scene.add(sun);
  }

  private buildStreetEnvironment(): void {
    const lawn = new THREE.Mesh(
      new THREE.PlaneGeometry(16, 12),
      new THREE.MeshStandardMaterial({ color: 0x99c286, roughness: 0.95 }),
    );
    lawn.rotation.x = -Math.PI / 2;
    lawn.position.set(0, -0.04, -1.5);
    lawn.receiveShadow = true;
    this.scene.add(lawn);

    const sidewalkTex = createRichFloorTexture('#E8DFD1', 'tile');
    sidewalkTex.repeat.set(6, 2);
    const sidewalk = new THREE.Mesh(
      new THREE.BoxGeometry(11.0, 0.14, 2.7),
      new THREE.MeshStandardMaterial({ map: sidewalkTex, roughness: 0.85 }),
    );
    sidewalk.position.set(0, -0.07, 0.65);
    sidewalk.receiveShadow = true;
    this.scene.add(sidewalk);

    // Indonesian black-and-white Kanstin curb blocks
    const blackMat = new THREE.MeshStandardMaterial({ color: 0x2b2d42, roughness: 0.85 });
    const whiteMat = new THREE.MeshStandardMaterial({ color: 0xfdf6ec, roughness: 0.8 });
    for (let i = 0; i < 20; i++) {
      const curb = new THREE.Mesh(
        new THREE.BoxGeometry(0.54, 0.14, 0.16),
        i % 2 === 0 ? whiteMat : blackMat,
      );
      curb.position.set(-5.13 + i * 0.54, -0.04, 2.02);
      curb.castShadow = true;
      curb.receiveShadow = true;
      this.scene.add(curb);
    }

    const road = new THREE.Mesh(
      new THREE.BoxGeometry(11.0, 0.12, 3.0),
      new THREE.MeshStandardMaterial({ color: 0x45495e, roughness: 0.92 }),
    );
    road.position.set(0, -0.1, 3.5);
    road.receiveShadow = true;
    this.scene.add(road);

    const dashMat = new THREE.MeshBasicMaterial({ color: 0xfdf6ec });
    for (let x = -4.5; x <= 4.5; x += 1.2) {
      const dash = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.01, 0.1), dashMat);
      dash.position.set(x, -0.035, 3.35);
      this.scene.add(dash);
    }

    const houses = [
      { x: -2.6, wall: 0xfdf6ec, roof: '#B85D3B', trim: 0x81b29a },
      { x: 0.0, wall: 0xfff3d6, roof: '#A44A3F', trim: 0xe07a5f },
      { x: 2.6, wall: 0xf4ece1, roof: '#6D8B74', trim: 0xf2cc8f },
    ];
    for (const h of houses) {
      const roofTex = createTerracottaRoofTexture(h.roof);
      const body = new THREE.Mesh(
        new THREE.BoxGeometry(2.1, 1.55, 1.5),
        new THREE.MeshStandardMaterial({ color: h.wall, roughness: 0.88 }),
      );
      body.position.set(h.x, 0.78, -1.65);
      body.castShadow = true;
      body.receiveShadow = true;

      const roof = new THREE.Mesh(
        new THREE.ConeGeometry(1.72, 0.9, 4),
        new THREE.MeshStandardMaterial({ map: roofTex, roughness: 0.78 }),
      );
      roof.rotation.y = Math.PI / 4;
      roof.position.set(h.x, 1.98, -1.65);
      roof.castShadow = true;

      const awning = new THREE.Mesh(
        new THREE.BoxGeometry(1.5, 0.08, 0.55),
        new THREE.MeshStandardMaterial({ color: h.trim, roughness: 0.75 }),
      );
      awning.position.set(h.x, 1.08, -0.68);
      awning.castShadow = true;

      const door = new THREE.Mesh(
        new THREE.BoxGeometry(0.46, 0.92, 0.06),
        new THREE.MeshStandardMaterial({ color: 0x6f4e37, roughness: 0.8 }),
      );
      door.position.set(h.x - 0.3, 0.46, -0.89);

      const win = new THREE.Mesh(
        new THREE.BoxGeometry(0.55, 0.44, 0.06),
        new THREE.MeshStandardMaterial({ color: 0xa8dadc, roughness: 0.3 }),
      );
      win.position.set(h.x + 0.42, 0.88, -0.89);

      const fenceMat = new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.85 });
      const fenceL = new THREE.Mesh(new THREE.BoxGeometry(0.75, 0.42, 0.08), fenceMat);
      fenceL.position.set(h.x - 0.68, 0.21, -0.45);
      fenceL.castShadow = true;
      const fenceR = new THREE.Mesh(new THREE.BoxGeometry(0.75, 0.42, 0.08), fenceMat);
      fenceR.position.set(h.x + 0.68, 0.21, -0.45);
      fenceR.castShadow = true;

      this.scene.add(body, roof, awning, door, win, fenceL, fenceR);
    }

    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x6f4e37, roughness: 0.9 });
    const leafDark = new THREE.MeshStandardMaterial({ color: 0x4f772d, roughness: 0.82 });
    const leafBright = new THREE.MeshStandardMaterial({ color: 0x76a354, roughness: 0.8 });

    for (const [tx, tz, sc] of [
      [-4.1, -0.65, 1.15],
      [-1.3, -0.62, 0.85],
      [1.3, -0.62, 0.9],
      [4.1, -0.65, 1.15],
    ]) {
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08 * sc, 0.12 * sc, 0.9 * sc, 8), trunkMat);
      trunk.position.set(tx, 0.45 * sc, tz);
      trunk.castShadow = true;
      const c1 = new THREE.Mesh(new THREE.SphereGeometry(0.48 * sc, 10, 10), leafDark);
      c1.position.set(tx, 1.15 * sc, tz);
      c1.castShadow = true;
      const c2 = new THREE.Mesh(new THREE.SphereGeometry(0.36 * sc, 10, 10), leafBright);
      c2.position.set(tx + 0.22 * sc, 1.0 * sc, tz + 0.14 * sc);
      c2.castShadow = true;
      this.scene.add(trunk, c1, c2);
    }

    const poleMat = new THREE.MeshStandardMaterial({ color: 0x2b2d42, roughness: 0.6 });
    const glowMat = new THREE.MeshBasicMaterial({ color: 0xffd166 });
    for (const lx of [-1.75, 1.75]) {
      const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.05, 1.8, 8), poleMat);
      pole.position.set(lx, 0.9, 1.82);
      pole.castShadow = true;
      const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.12, 10, 10), glowMat);
      lamp.position.set(lx, 1.82, 1.82);
      this.scene.add(pole, lamp);
    }

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
    const dtSec = this.lastTickMs > 0 ? Math.min(0.05, (nowMs - this.lastTickMs) / 1000) : 0.016;
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
        playActorAnimation(entry.actor, ['walk', 'run', 'idle'], dtSec);
      } else {
        playActorAnimation(entry.actor, ['emote-yes', 'gesture-positive', 'dance', 'idle'], dtSec);
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
