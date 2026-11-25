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

  private orbitAngle = 0;
  private orbitTargetAngle = 0;
  private lastTickMs = 0;
  private rafId = 0;
  private destroyed = false;

  private readonly onResizeBound = () => this.syncCanvasBounds();
  private readonly onContextLostBound = (e: Event) => e.preventDefault();

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
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xdbeafe);

    this.camera = new THREE.PerspectiveCamera(48, 450 / 800, 0.1, 40);
    this.updateCamera();

    this.contactShadowTex = createContactShadowTexture();
    this.setupLights();
    this.buildStreetEnvironment();

    // Player Avatar on sidewalk
    const avatarSpec = getAvatarSpec(avatarId);
    this.playerState = createCharacterState(0, 1.05);
    this.player = createHomekeeperRig(`characters/${avatarSpec.modelName}`, this.contactShadowTex);
    applyHomekeeperPose(this.player, this.playerState, 'lap', 0);
    this.scene.add(this.player.group);

    // 5 Strolling Family & Pet NPCs
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
        new THREE.SphereGeometry(0.42, 8, 8),
        new THREE.MeshBasicMaterial({ visible: false }),
      );
      hitProxy.position.y = 0.45;
      hitProxy.userData = { npcId: patrol.spec.id };
      actor.group.add(hitProxy);
      this.scene.add(actor.group);

      this.npcs.push({ patrol, actor, hitProxy });
    }

    this.syncCanvasBounds();
    window.addEventListener('resize', this.onResizeBound);
    this.threeCanvas.addEventListener('webglcontextlost', this.onContextLostBound);
    this.rafId = requestAnimationFrame(this.tick);
  }

  private setupLights(): void {
    this.scene.add(new THREE.HemisphereLight(0xfffaf0, 0x8d99ae, 1.05));
    const dir = new THREE.DirectionalLight(0xfff1d0, 1.15);
    dir.position.set(4, 7, 5);
    this.scene.add(dir);
  }

  private buildStreetEnvironment(): void {
    // Cozy warm paving sidewalk
    const sidewalkTex = createRichFloorTexture('#E8DFD1', 'tile');
    const sidewalk = new THREE.Mesh(
      new THREE.BoxGeometry(7.2, 0.16, 2.8),
      new THREE.MeshStandardMaterial({ map: sidewalkTex, roughness: 0.85 }),
    );
    sidewalk.position.set(0, -0.08, 0.5);
    this.scene.add(sidewalk);

    // Asphalt neighborhood lane in foreground
    const road = new THREE.Mesh(
      new THREE.BoxGeometry(7.2, 0.12, 2.4),
      new THREE.MeshStandardMaterial({ color: 0x4a4e69, roughness: 0.9 }),
    );
    road.position.set(0, -0.1, 3.0);
    this.scene.add(road);

    // Dashed road markings
    const dashMat = new THREE.MeshBasicMaterial({ color: 0xfdf6ec });
    for (let x = -2.7; x <= 2.7; x += 1.1) {
      const dash = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.01, 0.1), dashMat);
      dash.position.set(x, -0.035, 2.85);
      this.scene.add(dash);
    }

    // Background cozy neighborhood houses (terracotta, sage, mustard Indonesian facades)
    const facades = [
      { x: -1.9, w: 1.8, h: 2.1, color: 0xfdf6ec, roof: 0xe07a5f },
      { x: 0.0, w: 1.7, h: 2.3, color: 0xffe8d6, roof: 0x81b29a },
      { x: 1.9, w: 1.8, h: 2.0, color: 0xfefae0, roof: 0xb56576 },
    ];
    for (const f of facades) {
      const body = new THREE.Mesh(
        new THREE.BoxGeometry(f.w, f.h, 1.1),
        new THREE.MeshStandardMaterial({ color: f.color, roughness: 0.88 }),
      );
      body.position.set(f.x, f.h / 2, -1.35);
      const roof = new THREE.Mesh(
        new THREE.ConeGeometry(f.w * 0.78, 0.75, 4),
        new THREE.MeshStandardMaterial({ color: f.roof, roughness: 0.8 }),
      );
      roof.rotation.y = Math.PI / 4;
      roof.position.set(f.x, f.h + 0.36, -1.35);
      const door = new THREE.Mesh(
        new THREE.BoxGeometry(0.42, 0.85, 0.06),
        new THREE.MeshStandardMaterial({ color: 0x6d4c3d, roughness: 0.8 }),
      );
      door.position.set(f.x, 0.43, -0.79);
      const win = new THREE.Mesh(
        new THREE.BoxGeometry(0.42, 0.42, 0.06),
        new THREE.MeshBasicMaterial({ color: 0x90e0ef }),
      );
      win.position.set(f.x + 0.45, 1.15, -0.79);
      this.scene.add(body, roof, door, win);
    }

    // Trees & warm streetlamps along sidewalk edge
    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x7f5539, roughness: 0.9 });
    const leafMat = new THREE.MeshStandardMaterial({ color: 0x81b29a, roughness: 0.8 });
    const poleMat = new THREE.MeshStandardMaterial({ color: 0x3d405b, roughness: 0.6 });
    const glowMat = new THREE.MeshBasicMaterial({ color: 0xf2cc8f });

    for (const tx of [-2.75, 2.75]) {
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.8, 8), trunkMat);
      trunk.position.set(tx, 0.4, -0.45);
      const leaves = new THREE.Mesh(new THREE.SphereGeometry(0.45, 10, 10), leafMat);
      leaves.position.set(tx, 1.05, -0.45);
      this.scene.add(trunk, leaves);
    }
    for (const lx of [-1.05, 1.05]) {
      const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.04, 1.65, 8), poleMat);
      pole.position.set(lx, 0.82, 1.68);
      const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.11, 10, 10), glowMat);
      bulb.position.set(lx, 1.68, 1.68);
      this.scene.add(pole, bulb);
    }
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

    // 1. Check if player tapped a family/pet NPC
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
        // Walk player near the NPC and face each other
        const [wx, wz] = clampRoomXZ(entry.patrol.x - 0.55, entry.patrol.z + 0.15, 2.4);
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

    // 2. Otherwise walk along the sidewalk
    const o = this.raycaster.ray.origin;
    const d = this.raycaster.ray.direction;
    const hit = intersectRayPlane([o.x, o.y, o.z], [d.x, d.y, d.z], [0, 0, 0], [0, 1, 0]);
    if (!hit) return;
    const tx = Math.max(-2.5, Math.min(2.5, hit[0]));
    const tz = Math.max(0.1, Math.min(1.65, hit[2]));
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
    const baseAngle = this.orbitAngle;
    this.camera.position.set(Math.sin(baseAngle) * 6.5, 3.2, Math.cos(baseAngle) * 6.2);
    this.camera.lookAt(0, 0.5, 0.4);
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

    // Update Player
    const step = stepCharacterMotion(this.playerState, dtSec, []);
    this.playerState = step.state;
    applyHomekeeperPose(this.player, this.playerState, 'lap', dtSec);

    // Update NPCs & project floating badge screen coords
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

      const headHeight = entry.patrol.spec.kind === 'pet' ? 0.65 : 1.18;
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
