import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import type {
  AvatarId,
  ClutterItemSpec,
  FurniturePropSpec,
  JobSpec,
  StainKind,
  StainSpotSpec,
  ToolMode,
} from '../core/types';
import { getAvatarSpec } from '../core/avatars';
import { getNeighborForJob, NEIGHBORS } from '../core/neighborhood';
import { CoverageGrid } from '../core/coverage';
import { getToolMatchMultiplier } from '../core/economy';
import {
  CAMERA_FOV_DEG,
  CAMERA_HEIGHT,
  CAMERA_LOOK_Y,
  CAMERA_RADIUS,
  clampRoomXZ,
  intersectRayPlane,
  isTapGesture,
  isWithin3DSnapRadius,
  screenToNDC,
  worldHitToDecalUV,
  type Vec3,
} from '../core/math3d';
import {
  createContactShadowTexture,
  createRichFloorTexture,
  createWallArtTexture,
  createWallPaperTexture,
  createWindowSkyTexture,
} from './roomMaterials';
import {
  computeSafeStandPoint,
  createCharacterState,
  getPropAabb,
  stepCharacterMotion,
  type CharacterMotionState,
  type PropAabb,
} from '../core/character';
import {
  applyHomekeeperPose,
  createHomekeeperRig,
  createRiggedActor,
  disposeRiggedActor,
  playActorAnimation,
  type HomekeeperRig,
  type RiggedActor,
} from './homekeeper3d';

const gltfLoader = new GLTFLoader();

function loadGltfInstance(modelName: string): Promise<THREE.Group | null> {
  return new Promise<THREE.Group | null>((resolve) => {
    gltfLoader.load(
      `/models/${modelName}`,
      (gltf) => {
        const root = gltf.scene;
        root.traverse((obj) => {
          if ((obj as THREE.Mesh).isMesh) {
            const m = obj as THREE.Mesh;
            m.castShadow = true;
            m.receiveShadow = true;
          }
        });
        resolve(root);
      },
      undefined,
      () => resolve(null),
    );
  });
}

function centerAndGroundGroup(
  raw: THREE.Object3D,
  scale = 1,
): { wrapper: THREE.Group; size: THREE.Vector3 } {
  const wrapper = new THREE.Group();
  const clone = raw.clone(true);
  clone.scale.setScalar(scale);
  clone.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(clone);
  const center = new THREE.Vector3();
  const size = new THREE.Vector3();
  box.getCenter(center);
  box.getSize(size);
  clone.position.set(-center.x, -box.min.y, -center.z);
  wrapper.add(clone);
  return { wrapper, size };
}

function buildHeroOrFallbackProp(kind: ClutterItemSpec['kind']): THREE.Group {
  const g = new THREE.Group();
  if (kind === 'chalice') {
    const mat = new THREE.MeshStandardMaterial({ color: 0xe0e6ed, metalness: 0.75, roughness: 0.25 });
    const base = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.14, 0.04, 16), mat);
    base.position.y = 0.02;
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.14, 12), mat);
    stem.position.y = 0.11;
    const cup = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.06, 0.16, 16), mat);
    cup.position.y = 0.25;
    g.add(base, stem, cup);
  } else if (kind === 'crown') {
    const gold = new THREE.MeshStandardMaterial({ color: 0xf2cc8f, metalness: 0.7, roughness: 0.25 });
    const gem = new THREE.MeshStandardMaterial({ color: 0x7e57c2, metalness: 0.3, roughness: 0.2 });
    const band = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.14, 0.09, 16), gold);
    band.position.y = 0.05;
    g.add(band);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      const spike = new THREE.Mesh(new THREE.ConeGeometry(0.035, 0.09, 6), gold);
      spike.position.set(Math.cos(a) * 0.13, 0.13, Math.sin(a) * 0.13);
      g.add(spike);
    }
    const jewel = new THREE.Mesh(new THREE.OctahedronGeometry(0.035), gem);
    jewel.position.set(0, 0.06, 0.15);
    g.add(jewel);
  } else if (kind === 'scroll') {
    const paper = new THREE.MeshStandardMaterial({ color: 0xf8edeb, roughness: 0.8 });
    const ribbon = new THREE.MeshStandardMaterial({ color: 0xe07a5f, roughness: 0.5 });
    const roll = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.32, 14), paper);
    roll.rotation.z = Math.PI / 2;
    roll.position.y = 0.06;
    const band = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.045, 14), ribbon);
    band.rotation.z = Math.PI / 2;
    band.position.y = 0.06;
    g.add(roll, band);
  } else {
    const box = new THREE.Mesh(
      new THREE.BoxGeometry(0.24, 0.22, 0.24),
      new THREE.MeshStandardMaterial({ color: 0xe07a5f, roughness: 0.6 }),
    );
    box.position.y = 0.11;
    g.add(box);
  }
  g.traverse((o) => {
    if ((o as THREE.Mesh).isMesh) {
      o.castShadow = true;
      o.receiveShadow = true;
    }
  });
  return g;
}

function paintStainCanvas(kind: StainKind, size = 256): { canvas: HTMLCanvasElement; ctx: CanvasRenderingContext2D } {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;

  const palette: Record<StainKind, [string, string]> = {
    dust: ['rgba(145, 135, 125, 0.85)', 'rgba(185, 175, 165, 0.55)'],
    spill: ['rgba(105, 68, 42, 0.90)', 'rgba(148, 95, 58, 0.65)'],
    grease: ['rgba(202, 138, 4, 0.88)', 'rgba(234, 179, 8, 0.58)'],
    crayon: ['rgba(224, 122, 95, 0.86)', 'rgba(129, 178, 154, 0.68)'],
    mud: ['rgba(86, 58, 44, 0.92)', 'rgba(122, 86, 62, 0.68)'],
  };
  const [c1, c2] = palette[kind];

  const blobs = [
    [0.32, 0.36, 0.25],
    [0.54, 0.48, 0.29],
    [0.7, 0.4, 0.22],
    [0.44, 0.66, 0.24],
    [0.64, 0.66, 0.2],
  ];
  blobs.forEach(([bx, by, br], idx) => {
    ctx.fillStyle = idx % 2 === 0 ? c1 : c2;
    ctx.beginPath();
    ctx.ellipse(size * bx, size * by, size * br, size * br * 0.88, idx * 0.5, 0, Math.PI * 2);
    ctx.fill();
  });

  if (kind === 'dust') {
    ctx.fillStyle = 'rgba(255,255,255,0.45)';
    for (let i = 0; i < 16; i++) {
      const px = ((i * 37) % 70 + 15) * 0.01 * size;
      const py = ((i * 53) % 70 + 15) * 0.01 * size;
      ctx.beginPath();
      ctx.arc(px, py, 4, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  return { canvas, ctx };
}

export interface Room3DCallbacks {
  onProgress: (pct: number) => void;
  onStainCleared: () => void;
  onScrubStroke: () => void;
  onClutterSnapped: (item: ClutterItemSpec) => void;
  onClutterSelected?: (item: ClutterItemSpec) => void;
  onToolFeedback?: (kind: 'match' | 'mismatch', expectedTool: ToolMode) => void;
  onComplete: () => void;
}

interface Stain3DState {
  spec: StainSpotSpec;
  center: Vec3;
  size: [number, number];
  mesh: THREE.Mesh;
  canvas: HTMLCanvasElement;
  ctx: CanvasRenderingContext2D;
  tex: THREE.CanvasTexture;
  texDirty: boolean;
  pulseWeight: number;
  grid: CoverageGrid;
  done: boolean;
}

interface Clutter3DState {
  spec: ClutterItemSpec;
  group: THREE.Group;
  hitProxy: THREE.Mesh;
  targetRing: THREE.Mesh;
  startPos: Vec3;
  targetPos: Vec3;
  done: boolean;
}

interface ParticleSlot {
  active: boolean;
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  life: number;
}

const MAX_PARTICLES = 28;

export class Room3DView {
  private readonly phaserCanvas: HTMLCanvasElement;
  private readonly threeCanvas: HTMLCanvasElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene: THREE.Scene;
  private readonly camera: THREE.PerspectiveCamera;
  private readonly raycaster = new THREE.Raycaster();
  private readonly callbacks: Room3DCallbacks;
  private readonly job: JobSpec;
  private readonly readonlyMode: boolean;

  private furnitureGroup = new THREE.Group();
  private contactShadowTex: THREE.CanvasTexture;
  private homekeeper: HomekeeperRig;
  private resident: RiggedActor | null = null;
  private characterState: CharacterMotionState;
  private propAabbs: PropAabb[] = [];
  private lastTickMs = 0;
  private lastFeedbackMs = 0;
  private stains: Stain3DState[] = [];
  private clutter: Clutter3DState[] = [];
  private dragged: Clutter3DState | null = null;
  private selectedClutter: Clutter3DState | null = null;
  private pointerDownClient: { x: number; y: number } | null = null;
  private pointerMovedDist = 0;
  private lastScrubUV: { stainId: string; px: number; py: number } | null = null;

  private toolMode: ToolMode = 'lap';
  private orbitAngle = 0;
  private orbitTargetAngle = 0;
  private dirty = true;
  private destroyed = false;
  private finished = false;
  private assetsLoaded = false;
  private beforeSnapshot: string | null = null;
  private afterSnapshot: string | null = null;
  public readyPromise: Promise<void> = Promise.resolve();
  private rafId = 0;
  private brushRadiusPx = 24;
  private snapRadiusMeters = 0.55;

  // Pooled 3D burst particles
  private particlePoints: THREE.Points;
  private particlePositions = new Float32Array(MAX_PARTICLES * 3);
  private particleSlots: ParticleSlot[] = Array.from({ length: MAX_PARTICLES }, () => ({
    active: false,
    x: 0,
    y: -10,
    z: 0,
    vx: 0,
    vy: 0,
    vz: 0,
    life: 0,
  }));

  private readonly onResizeBound = () => this.syncCanvasBounds();
  private readonly onContextLostBound = (e: Event) => {
    e.preventDefault();
  };
  private readonly onContextRestoredBound = () => {
    this.renderer.shadowMap.needsUpdate = true;
    this.markDirty();
  };

  constructor(
    phaserCanvas: HTMLCanvasElement,
    job: JobSpec,
    brushRadiusPx: number,
    snapRadiusMeters: number,
    callbacks: Room3DCallbacks,
    readonlyMode = false,
    avatarId: AvatarId = 'sari',
  ) {
    this.phaserCanvas = phaserCanvas;
    this.job = job;
    this.brushRadiusPx = brushRadiusPx;
    this.snapRadiusMeters = snapRadiusMeters;
    this.callbacks = callbacks;
    this.readonlyMode = readonlyMode;

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
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.06;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(job.palette.wall);
    this.scene.add(this.furnitureGroup);

    this.contactShadowTex = createContactShadowTexture();
    const layout = this.job.furnitureLayout ?? [];
    this.propAabbs = layout.map((p) => getPropAabb(p, 0.22));
    const [startCharX, startCharZ] = computeSafeStandPoint(0.2, 0.85, layout);
    this.characterState = createCharacterState(startCharX, startCharZ);
    const avatarSpec = getAvatarSpec(avatarId);
    this.homekeeper = createHomekeeperRig(
      `characters/${avatarSpec.modelName}`,
      this.contactShadowTex,
      avatarSpec.scale3D,
    );
    applyHomekeeperPose(this.homekeeper, this.characterState, this.toolMode);
    this.scene.add(this.homekeeper.group);

    // Friendly Household Resident / Pet in an open corner
    const residentSpec = readonlyMode ? NEIGHBORS[0] : getNeighborForJob(job.id);
    const [resX, resZ] = computeSafeStandPoint(-1.45, 1.35, layout);
    this.resident = createRiggedActor(
      residentSpec.modelPath,
      residentSpec.scale3D,
      this.contactShadowTex,
      false,
      residentSpec.kind === 'pet'
        ? {}
        : {
            skinHex: residentSpec.portrait.skin,
            shirtHex: residentSpec.portrait.accent,
            hairHex: residentSpec.portrait.hair,
          },
    );
    this.resident.group.position.set(resX, 0, resZ);
    this.resident.group.rotation.y = Math.atan2(0 - resX, 0 - resZ);
    this.scene.add(this.resident.group);

    this.camera = new THREE.PerspectiveCamera(CAMERA_FOV_DEG, 450 / 800, 0.1, 30);
    this.updateCameraPosition();

    // Initialize pooled particles
    for (let i = 0; i < MAX_PARTICLES; i++) {
      this.particlePositions[i * 3 + 1] = -20;
    }
    const pGeo = new THREE.BufferGeometry();
    pGeo.setAttribute('position', new THREE.BufferAttribute(this.particlePositions, 3));
    const pMat = new THREE.PointsMaterial({
      color: 0xfff8e7,
      size: 0.14,
      transparent: true,
      opacity: 0.9,
      depthWrite: false,
    });
    this.particlePoints = new THREE.Points(pGeo, pMat);
    this.particlePoints.frustumCulled = false;
    this.scene.add(this.particlePoints);

    this.setupLights();
    this.buildRoomShell();
    if (!readonlyMode) {
      this.buildStains();
    }
    this.readyPromise = this.buildFurnitureAndClutter(this.job.furnitureLayout ?? []);

    this.syncCanvasBounds();
    window.addEventListener('resize', this.onResizeBound);
    this.threeCanvas.addEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.addEventListener('webglcontextrestored', this.onContextRestoredBound);

    this.rafId = requestAnimationFrame(this.tick);
  }

  setToolMode(mode: ToolMode): void {
    this.toolMode = mode;
    applyHomekeeperPose(this.homekeeper, this.characterState, this.toolMode);
    this.markDirty();
  }

  onFloorTap(clientX: number, clientY: number): void {
    if (!this.readonlyMode || this.destroyed) return;
    if (!this.pointerToRay(clientX, clientY)) return;
    const o = this.raycaster.ray.origin;
    const d = this.raycaster.ray.direction;
    const hit = intersectRayPlane([o.x, o.y, o.z], [d.x, d.y, d.z], [0, 0, 0], [0, 1, 0]);
    if (!hit) return;
    const [cx, cz] = clampRoomXZ(hit[0], hit[2], 2.02);
    this.commandCharacter(cx, cz, false);
  }

  private commandCharacter(actionX: number, actionZ: number, withScrub: boolean): void {
    const [tx, tz] = computeSafeStandPoint(actionX, actionZ, this.job.furnitureLayout ?? []);
    const dist = Math.hypot(tx - this.characterState.x, tz - this.characterState.z);
    this.characterState = {
      ...this.characterState,
      targetX: tx,
      targetZ: tz,
      lookX: actionX,
      lookZ: actionZ,
      pose: dist > 0.14 ? 'walk' : withScrub ? 'scrub' : 'idle',
      scrubTimer: withScrub ? 0.45 : 0,
      walkTimer: 0,
    };
    this.markDirty();
  }

  getToolMode(): ToolMode {
    return this.toolMode;
  }

  getSnapshots(): { before: string | null; after: string | null } {
    return { before: this.beforeSnapshot, after: this.afterSnapshot };
  }

  updateToolStats(brushRadiusPx: number, snapRadiusMeters: number): void {
    this.brushRadiusPx = brushRadiusPx;
    this.snapRadiusMeters = snapRadiusMeters;
  }

  rotateStep(deltaRad: number): void {
    this.orbitTargetAngle = Math.max(-0.55, Math.min(0.55, this.orbitTargetAngle + deltaRad));
    this.markDirty();
  }

  pulseRemaining(): void {
    for (const st of this.stains) {
      if (!st.done) {
        st.pulseWeight = 1.0;
      }
    }
    for (const c of this.clutter) {
      if (!c.done) {
        c.targetRing.scale.setScalar(1.38);
      }
    }
    this.markDirty();
  }

  markDirty(): void {
    this.dirty = true;
  }

  async reloadFurnitureLayout(layout: FurniturePropSpec[]): Promise<void> {
    if (this.destroyed) return;
    while (this.furnitureGroup.children.length > 0) {
      const child = this.furnitureGroup.children[this.furnitureGroup.children.length - 1];
      this.furnitureGroup.remove(child);
      child.traverse((obj) => {
        if ((obj as THREE.Mesh).isMesh) {
          const m = obj as THREE.Mesh;
          m.geometry?.dispose();
          const mats = Array.isArray(m.material) ? m.material : [m.material];
          for (const mat of mats) {
            if (!mat) continue;
            const std = mat as THREE.MeshStandardMaterial;
            if (std.map && std.map !== this.contactShadowTex) std.map.dispose();
            mat.dispose();
          }
        }
      });
    }
    await this.buildFurnitureOnly(layout);
    if (this.destroyed) return;
    this.renderer.shadowMap.needsUpdate = true;
    this.markDirty();
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
    this.markDirty();
  }

  private setupLights(): void {
    const hemi = new THREE.HemisphereLight(0xfffaf0, 0x9c8974, 0.95);
    this.scene.add(hemi);

    const dir = new THREE.DirectionalLight(0xfff5e4, 1.35);
    dir.position.set(4.5, 6.8, 3.8);
    dir.castShadow = true;
    dir.shadow.mapSize.set(512, 512);
    dir.shadow.camera.near = 1;
    dir.shadow.camera.far = 18;
    const d = 3.5;
    dir.shadow.camera.left = -d;
    dir.shadow.camera.right = d;
    dir.shadow.camera.top = d;
    dir.shadow.camera.bottom = -d;
    dir.shadow.bias = -0.001;
    this.scene.add(dir);
  }

  private buildRoomShell(): void {
    const floorStyle =
      this.job.id === 'dapur-sari' || this.job.id === 'villa-senja' ? 'tile' : 'wood';
    const floorTex = createRichFloorTexture(this.job.palette.floor, floorStyle);
    const floor = new THREE.Mesh(
      new THREE.BoxGeometry(4.8, 0.14, 4.8),
      new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.82 }),
    );
    floor.position.set(0, -0.07, 0);
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Warm grounded patio/garden surround strictly below floor bottom (-0.14) to avoid void look
    const skirt = new THREE.Mesh(
      new THREE.PlaneGeometry(11, 11),
      new THREE.MeshStandardMaterial({ color: 0xdfe6cf, roughness: 0.96 }),
    );
    skirt.rotation.x = -Math.PI / 2;
    skirt.position.set(0, -0.15, 0);
    skirt.receiveShadow = false;
    this.scene.add(skirt);

    const wallTex = createWallPaperTexture(this.job.palette.wall, this.job.palette.accent);
    const wallMat = new THREE.MeshStandardMaterial({ map: wallTex, roughness: 0.9 });
    const trimMat = new THREE.MeshStandardMaterial({ color: this.job.palette.trim, roughness: 0.7 });

    const backWall = new THREE.Mesh(new THREE.BoxGeometry(4.8, 2.7, 0.12), wallMat);
    backWall.position.set(0, 1.35, -2.38);
    backWall.receiveShadow = true;
    this.scene.add(backWall);

    const leftWall = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.7, 4.8), wallMat);
    leftWall.position.set(-2.38, 1.35, 0);
    leftWall.receiveShadow = true;
    this.scene.add(leftWall);

    const baseBack = new THREE.Mesh(new RoundedBoxGeometry(4.8, 0.14, 0.15, 2, 0.025), trimMat);
    baseBack.position.set(0, 0.07, -2.35);
    const baseLeft = new THREE.Mesh(new RoundedBoxGeometry(0.15, 0.14, 4.8, 2, 0.025), trimMat);
    baseLeft.position.set(-2.35, 0.07, 0);
    this.scene.add(baseBack, baseLeft);

    // Sky gradient window with beveled frame & mullion bars
    const frame = new THREE.Mesh(new RoundedBoxGeometry(1.18, 0.94, 0.06, 2, 0.02), trimMat);
    frame.position.set(0.45, 1.58, -2.31);
    const skyTex = createWindowSkyTexture();
    const glass = new THREE.Mesh(
      new THREE.PlaneGeometry(1.0, 0.78),
      new THREE.MeshBasicMaterial({ map: skyTex }),
    );
    glass.position.set(0.45, 1.58, -2.275);
    const barV = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.78, 0.02), trimMat);
    barV.position.set(0.45, 1.58, -2.265);
    const barH = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.03, 0.02), trimMat);
    barH.position.set(0.45, 1.58, -2.265);
    this.scene.add(frame, glass, barV, barH);

    // Framed decorative wall poster on left wall
    const artFrame = new THREE.Mesh(new RoundedBoxGeometry(0.05, 0.68, 0.56, 2, 0.015), trimMat);
    artFrame.position.set(-2.31, 1.58, -0.35);
    const artTex = createWallArtTexture(this.job.palette.accent);
    const artPlane = new THREE.Mesh(
      new THREE.PlaneGeometry(0.46, 0.58),
      new THREE.MeshBasicMaterial({ map: artTex }),
    );
    artPlane.rotation.y = Math.PI / 2;
    artPlane.position.set(-2.285, 1.58, -0.35);
    this.scene.add(artFrame, artPlane);
  }

  private buildStains(): void {
    for (const spec of this.job.stains) {
      const center: Vec3 = spec.pos3D ?? [0, 0.02, 0];
      const size: [number, number] = spec.size3D ?? [0.9, 0.9];
      const { canvas, ctx } = paintStainCanvas(spec.kind, 256);
      const tex = new THREE.CanvasTexture(canvas);
      tex.colorSpace = THREE.SRGBColorSpace;

      const mat = new THREE.MeshStandardMaterial({
        map: tex,
        transparent: true,
        depthWrite: false,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        polygonOffsetUnits: -1,
        roughness: 0.9,
      });

      const mesh = new THREE.Mesh(new THREE.PlaneGeometry(size[0], size[1]), mat);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(center[0], center[1] + 0.008, center[2]);
      mesh.userData = { stainId: spec.id };
      this.scene.add(mesh);

      const grid = new CoverageGrid(256, 256, 12, 0.78);
      this.stains.push({
        spec,
        center,
        size,
        mesh,
        canvas,
        ctx,
        tex,
        texDirty: false,
        pulseWeight: 0,
        grid,
        done: false,
      });
    }
  }

  private async buildFurnitureOnly(layout: FurniturePropSpec[]): Promise<void> {
    await Promise.all(
      layout.map(async (prop) => {
        const tpl = await loadGltfInstance(prop.modelName);
        if (this.destroyed || !tpl) return;
        const { wrapper, size } = centerAndGroundGroup(tpl, prop.scale3D ?? 1);
        wrapper.position.set(prop.pos3D[0], prop.pos3D[1], prop.pos3D[2]);
        wrapper.rotation.y = prop.rotY3D ?? 0;
        this.furnitureGroup.add(wrapper);

        // Soft contact shadow decal for grounded props
        if (prop.pos3D[1] <= 0.02 && !prop.modelName.startsWith('rug')) {
          const shadow = new THREE.Mesh(
            new THREE.PlaneGeometry(Math.max(0.35, size.x * 1.18), Math.max(0.35, size.z * 1.18)),
            new THREE.MeshBasicMaterial({
              map: this.contactShadowTex,
              transparent: true,
              depthWrite: false,
              opacity: 0.75,
            }),
          );
          shadow.rotation.x = -Math.PI / 2;
          shadow.position.set(prop.pos3D[0], 0.004, prop.pos3D[2]);
          shadow.rotation.z = prop.rotY3D ?? 0;
          this.furnitureGroup.add(shadow);
        }
      }),
    );
  }

  private async buildFurnitureAndClutter(layout: FurniturePropSpec[]): Promise<void> {
    const fPromise = this.buildFurnitureOnly(layout);

    const clutterPromises = this.readonlyMode
      ? []
      : this.job.clutter.map(async (item) => {
          const startPos: Vec3 = item.pos3D ?? [0, 0, 1.2];
          const targetPos: Vec3 = item.targetPos3D ?? [0, 0.5, -1.2];

          let visual: THREE.Group;
          if (item.modelName) {
            const tpl = await loadGltfInstance(item.modelName);
            if (this.destroyed) return;
            visual = tpl
              ? centerAndGroundGroup(tpl, item.scale3D ?? 1).wrapper
              : buildHeroOrFallbackProp(item.kind);
          } else {
            visual = buildHeroOrFallbackProp(item.kind);
          }
          if (this.destroyed) return;

          visual.position.set(startPos[0], startPos[1], startPos[2]);
          if (item.rotY3D) visual.rotation.y = item.rotY3D;

          const hitProxy = new THREE.Mesh(
            new THREE.SphereGeometry(0.34, 10, 10),
            new THREE.MeshBasicMaterial({ visible: false }),
          );
          hitProxy.position.y = 0.16;
          hitProxy.userData = { clutterId: item.id };
          visual.add(hitProxy);
          this.scene.add(visual);

          const ringMat = new THREE.MeshBasicMaterial({
            color: 0x2a9d8f,
            side: THREE.DoubleSide,
            transparent: true,
            opacity: 0.85,
            depthTest: false,
          });
          const targetRing = new THREE.Mesh(new THREE.RingGeometry(0.16, 0.25, 28), ringMat);
          targetRing.rotation.x = -Math.PI / 2;
          targetRing.renderOrder = 10;
          targetRing.position.set(targetPos[0], targetPos[1] + 0.015, targetPos[2]);
          this.scene.add(targetRing);

          this.clutter.push({
            spec: item,
            group: visual,
            hitProxy,
            targetRing,
            startPos,
            targetPos,
            done: false,
          });
        });

    await Promise.all([
      fPromise,
      ...clutterPromises,
      this.homekeeper.readyPromise,
      this.resident?.readyPromise ?? Promise.resolve(),
    ]);
    if (this.destroyed) return;
    applyHomekeeperPose(this.homekeeper, this.characterState, this.toolMode, 0.02);
    if (this.resident) playActorAnimation(this.resident, ['idle', 'static'], 0.02);
    this.assetsLoaded = true;
    this.renderer.shadowMap.needsUpdate = true;
    this.markDirty();
  }

  private emitParticles(x: number, y: number, z: number, count: number): void {
    let spawned = 0;
    for (let i = 0; i < MAX_PARTICLES && spawned < count; i++) {
      const slot = this.particleSlots[i];
      if (!slot.active) {
        slot.active = true;
        slot.x = x + (Math.random() - 0.5) * 0.22;
        slot.y = y + 0.08 + Math.random() * 0.08;
        slot.z = z + (Math.random() - 0.5) * 0.22;
        slot.vx = (Math.random() - 0.5) * 0.03;
        slot.vy = 0.025 + Math.random() * 0.025;
        slot.vz = (Math.random() - 0.5) * 0.03;
        slot.life = 1.0;
        spawned++;
      }
    }
    this.markDirty();
  }

  private pointerToRay(clientX: number, clientY: number): boolean {
    const rect = this.phaserCanvas.getBoundingClientRect();
    const ndc = screenToNDC(clientX, clientY, rect);
    if (!ndc) return false;
    this.raycaster.setFromCamera(new THREE.Vector2(ndc.x, ndc.y), this.camera);
    return true;
  }

  onPointerDown(clientX: number, clientY: number): void {
    if (this.finished || this.destroyed || this.readonlyMode) return;
    this.pointerDownClient = { x: clientX, y: clientY };
    this.pointerMovedDist = 0;
    if (!this.pointerToRay(clientX, clientY)) return;

    // 1. Check unplaced clutter hit proxies
    const proxies = this.clutter.filter((c) => !c.done).map((c) => c.hitProxy);
    const hits = this.raycaster.intersectObjects(proxies, false);
    if (hits.length > 0) {
      const id = hits[0].object.userData.clutterId as string;
      const found = this.clutter.find((c) => c.spec.id === id && !c.done) ?? null;
      if (found) {
        this.dragged = found;
        found.group.position.y = found.startPos[1] + 0.16;
        (found.targetRing.material as THREE.MeshBasicMaterial).color.setHex(0xf2cc8f);
        this.renderer.shadowMap.needsUpdate = true;
        this.markDirty();
        return;
      }
    }

    // 2. If a clutter item was already selected by tap, defer scrubbing until drag >= 8px
    if (this.selectedClutter && !this.selectedClutter.done) {
      return;
    }

    this.scrubAt(clientX, clientY);
  }

  onPointerMove(clientX: number, clientY: number): void {
    if (this.finished || this.destroyed || this.readonlyMode) return;
    if (this.pointerDownClient) {
      this.pointerMovedDist = Math.max(
        this.pointerMovedDist,
        Math.hypot(clientX - this.pointerDownClient.x, clientY - this.pointerDownClient.y),
      );
    }
    if (!this.pointerToRay(clientX, clientY)) return;

    if (this.dragged) {
      const o = this.raycaster.ray.origin;
      const d = this.raycaster.ray.direction;
      const dragY = Math.max(this.dragged.startPos[1], this.dragged.targetPos[1]);
      const hit = intersectRayPlane(
        [o.x, o.y, o.z],
        [d.x, d.y, d.z],
        [0, dragY, 0],
        [0, 1, 0],
      );
      if (hit) {
        const [cx, cz] = clampRoomXZ(hit[0], hit[2], 2.05);
        this.dragged.group.position.set(cx, dragY + 0.15, cz);
        this.renderer.shadowMap.needsUpdate = true;
        this.markDirty();
      }
      return;
    }

    if (this.selectedClutter && this.pointerMovedDist < 8) return;
    this.scrubAt(clientX, clientY);
  }

  onPointerUp(clientX?: number, clientY?: number): void {
    this.lastScrubUV = null;
    const down = this.pointerDownClient;
    this.pointerDownClient = null;
    const isTap =
      down && typeof clientX === 'number' && typeof clientY === 'number'
        ? isTapGesture(down.x, down.y, clientX, clientY, 10)
        : false;

    const item = this.dragged;
    if (item) {
      this.dragged = null;
      const currentPos: Vec3 = [item.group.position.x, item.targetPos[1], item.group.position.z];
      const snapped = isWithin3DSnapRadius(currentPos, item.targetPos, this.snapRadiusMeters);
      if (snapped) {
        this.snapClutterItem(item);
      } else if (isTap) {
        // Select clutter for easy tap-target placement
        if (this.selectedClutter && this.selectedClutter !== item) {
          (this.selectedClutter.targetRing.material as THREE.MeshBasicMaterial).color.setHex(0x2a9d8f);
          this.selectedClutter.group.position.set(
            this.selectedClutter.startPos[0],
            this.selectedClutter.startPos[1],
            this.selectedClutter.startPos[2],
          );
        }
        this.selectedClutter = item;
        item.group.position.set(item.startPos[0], item.startPos[1] + 0.12, item.startPos[2]);
        (item.targetRing.material as THREE.MeshBasicMaterial).color.setHex(0xf2cc8f);
        this.callbacks.onClutterSelected?.(item.spec);
      } else {
        if (this.selectedClutter === item) this.selectedClutter = null;
        item.group.position.set(item.startPos[0], item.startPos[1], item.startPos[2]);
        (item.targetRing.material as THREE.MeshBasicMaterial).color.setHex(0x2a9d8f);
      }
      this.renderer.shadowMap.needsUpdate = true;
      this.markDirty();
      return;
    }

    // Handle tap-to-place onto glowing target ring
    if (isTap && this.selectedClutter && !this.selectedClutter.done && typeof clientX === 'number' && typeof clientY === 'number') {
      if (this.pointerToRay(clientX, clientY)) {
        const sel = this.selectedClutter;
        const o = this.raycaster.ray.origin;
        const d = this.raycaster.ray.direction;
        const hit = intersectRayPlane([o.x, o.y, o.z], [d.x, d.y, d.z], [0, sel.targetPos[1], 0], [0, 1, 0]);
        if (hit && isWithin3DSnapRadius(hit, sel.targetPos, this.snapRadiusMeters * 1.45)) {
          this.snapClutterItem(sel);
          this.renderer.shadowMap.needsUpdate = true;
          this.markDirty();
          return;
        }
      }
      // Fallback: if tapped elsewhere on a stain, scrub
      this.scrubAt(clientX, clientY);
    }
  }

  private snapClutterItem(item: Clutter3DState): void {
    item.done = true;
    if (this.selectedClutter === item) this.selectedClutter = null;
    item.group.position.set(item.targetPos[0], item.targetPos[1], item.targetPos[2]);
    item.targetRing.visible = false;
    this.commandCharacter(item.targetPos[0], item.targetPos[2], true);
    this.emitParticles(item.targetPos[0], item.targetPos[1] + 0.15, item.targetPos[2], 8);
    this.callbacks.onClutterSnapped(item.spec);
    this.emitProgressAndCheckWin();
  }

  private scrubAt(clientX: number, clientY: number): void {
    if (!this.pointerToRay(clientX, clientY)) return;
    const stainMeshes = this.stains.filter((s) => !s.done).map((s) => s.mesh);
    if (stainMeshes.length === 0) return;

    const hits = this.raycaster.intersectObjects(stainMeshes, false);
    if (hits.length === 0) {
      this.lastScrubUV = null;
      return;
    }

    const hit = hits[0];
    const stainId = hit.object.userData.stainId as string;
    const st = this.stains.find((s) => s.spec.id === stainId && !s.done);
    if (!st) return;

    const uv = worldHitToDecalUV([hit.point.x, hit.point.y, hit.point.z], st.center, st.size);
    if (!uv) return;

    const px = uv.u * 256;
    const py = uv.v * 256;
    const prev =
      this.lastScrubUV && this.lastScrubUV.stainId === stainId
        ? { px: this.lastScrubUV.px, py: this.lastScrubUV.py }
        : { px, py };
    this.lastScrubUV = { stainId, px, py };

    const matchMult = getToolMatchMultiplier(this.toolMode, st.spec.kind);
    const now = Date.now();
    if (now - this.lastFeedbackMs > 1200) {
      this.lastFeedbackMs = now;
      if (matchMult > 1) {
        this.callbacks.onToolFeedback?.('match', this.toolMode);
      } else {
        const expected: ToolMode =
          st.spec.kind === 'dust' || st.spec.kind === 'crayon' ? 'lap' : 'pel';
        this.callbacks.onToolFeedback?.('mismatch', expected);
      }
    }
    const r = Math.round(this.brushRadiusPx * matchMult);
    const dist = Math.hypot(px - prev.px, py - prev.py);
    const step = Math.max(4, r * 0.4);
    const steps = Math.max(1, Math.ceil(dist / step));

    st.ctx.save();
    st.ctx.globalCompositeOperation = 'destination-out';
    for (let i = 0; i <= steps; i++) {
      const f = i / steps;
      const ix = prev.px + (px - prev.px) * f;
      const iy = prev.py + (py - prev.py) * f;
      st.ctx.beginPath();
      st.ctx.arc(ix, iy, r, 0, Math.PI * 2);
      st.ctx.fill();
      st.grid.scrubCircle(ix, iy, r);
    }
    st.ctx.restore();
    st.texDirty = true;

    this.commandCharacter(hit.point.x, hit.point.z, true);
    this.emitParticles(hit.point.x, hit.point.y + 0.05, hit.point.z, 2);
    this.callbacks.onScrubStroke();

    if (st.grid.isComplete) {
      st.done = true;
      st.grid.markComplete();
      st.mesh.visible = false;
      this.emitParticles(st.center[0], st.center[1] + 0.15, st.center[2], 10);
      this.callbacks.onStainCleared();
    }
    this.emitProgressAndCheckWin();
    this.markDirty();
  }

  private emitProgressAndCheckWin(): void {
    const total = this.stains.length + this.clutter.length;
    if (total === 0) return;
    const stainPct = this.stains.reduce((s, st) => s + (st.done ? 1 : st.grid.ratio), 0);
    const clutterDone = this.clutter.filter((c) => c.done).length;
    const pct = Math.min(100, Math.round(((stainPct + clutterDone) / total) * 100));
    this.callbacks.onProgress(pct);

    if (!this.finished && this.stains.every((s) => s.done) && this.clutter.every((c) => c.done)) {
      this.finished = true;
      this.characterState = {
        ...this.characterState,
        pose: 'celebrate',
        celebrateTimer: 1.8,
        animTime: 0.25,
      };
      applyHomekeeperPose(this.homekeeper, this.characterState, this.toolMode, 0.25);
      if (this.resident) {
        playActorAnimation(this.resident, ['dance', 'emote-yes', 'gesture-positive', 'idle'], 0.25);
      }
      // Flush final clean render & capture After snapshot synchronously
      this.flushDirtyStainTextures();
      this.renderer.render(this.scene, this.camera);
      this.afterSnapshot = this.captureThumbnailDataUrl();
      this.callbacks.onComplete();
      this.markDirty();
    }
  }

  private captureThumbnailDataUrl(): string | null {
    try {
      const c = document.createElement('canvas');
      c.width = 180;
      c.height = 320;
      const ctx = c.getContext('2d');
      if (!ctx) return null;
      ctx.drawImage(this.threeCanvas, 0, 0, c.width, c.height);
      return c.toDataURL('image/jpeg', 0.72);
    } catch {
      return null;
    }
  }

  private flushDirtyStainTextures(): boolean {
    let any = false;
    for (const st of this.stains) {
      if (st.texDirty) {
        st.tex.needsUpdate = true;
        st.texDirty = false;
        any = true;
      }
    }
    return any;
  }

  private updateCameraPosition(): void {
    const baseAngle = Math.PI / 4 + this.orbitAngle;
    this.camera.position.set(
      Math.sin(baseAngle) * CAMERA_RADIUS,
      CAMERA_HEIGHT,
      Math.cos(baseAngle) * CAMERA_RADIUS,
    );
    this.camera.lookAt(0, CAMERA_LOOK_Y, 0);
  }

  private tick = (nowMs: number): void => {
    if (this.destroyed) return;
    this.rafId = requestAnimationFrame(this.tick);
    const dtSec = this.lastTickMs > 0 ? (nowMs - this.lastTickMs) / 1000 : 0.016;
    this.lastTickMs = nowMs;

    const charStep = stepCharacterMotion(this.characterState, dtSec, this.propAabbs);
    this.characterState = charStep.state;
    if (charStep.needsFrame) {
      applyHomekeeperPose(this.homekeeper, this.characterState, this.toolMode, dtSec);
      if (this.resident && this.characterState.pose === 'celebrate') {
        playActorAnimation(this.resident, ['dance', 'emote-yes', 'gesture-positive', 'idle'], dtSec);
      }
      this.dirty = true;
    }

    if (Math.abs(this.orbitTargetAngle - this.orbitAngle) > 0.008) {
      this.orbitAngle += (this.orbitTargetAngle - this.orbitAngle) * 0.28;
      this.updateCameraPosition();
      this.dirty = true;
    } else if (this.orbitAngle !== this.orbitTargetAngle) {
      this.orbitAngle = this.orbitTargetAngle;
      this.updateCameraPosition();
      this.dirty = true;
    }

    for (const c of this.clutter) {
      if (!c.done && c.targetRing.scale.x > 1.01) {
        c.targetRing.scale.lerp(new THREE.Vector3(1, 1, 1), 0.08);
        this.dirty = true;
      }
    }

    if (this.flushDirtyStainTextures()) {
      this.dirty = true;
    }

    for (const st of this.stains) {
      if (!st.done && st.pulseWeight > 0.01) {
        const mat = st.mesh.material as THREE.MeshStandardMaterial;
        mat.emissive.setHex(0xf2cc8f);
        mat.emissiveIntensity = st.pulseWeight * 0.9;
        st.pulseWeight *= 0.9;
        this.dirty = true;
      } else if (st.pulseWeight !== 0) {
        st.pulseWeight = 0;
        const mat = st.mesh.material as THREE.MeshStandardMaterial;
        mat.emissiveIntensity = 0;
        this.dirty = true;
      }
    }

    // Update active 3D particles & gate dirty flag
    let activeParticles = 0;
    for (let i = 0; i < MAX_PARTICLES; i++) {
      const slot = this.particleSlots[i];
      if (!slot.active) continue;
      slot.x += slot.vx;
      slot.y += slot.vy;
      slot.z += slot.vz;
      slot.life -= 0.045;
      if (slot.life <= 0) {
        slot.active = false;
        this.particlePositions[i * 3 + 1] = -20;
      } else {
        activeParticles++;
        this.particlePositions[i * 3] = slot.x;
        this.particlePositions[i * 3 + 1] = slot.y;
        this.particlePositions[i * 3 + 2] = slot.z;
      }
    }
    if (activeParticles > 0 || this.dirty) {
      if (activeParticles > 0) {
        this.particlePoints.geometry.attributes.position.needsUpdate = true;
      }
      this.dirty = false;
      if (this.assetsLoaded && !this.beforeSnapshot && !this.readonlyMode) {
        this.homekeeper.group.visible = false;
        if (this.resident) this.resident.group.visible = false;
        this.renderer.render(this.scene, this.camera);
        this.beforeSnapshot = this.captureThumbnailDataUrl();
        this.homekeeper.group.visible = true;
        if (this.resident) this.resident.group.visible = true;
      }
      this.renderer.render(this.scene, this.camera);
    }
  };

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    cancelAnimationFrame(this.rafId);

    window.removeEventListener('resize', this.onResizeBound);
    this.threeCanvas.removeEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.removeEventListener('webglcontextrestored', this.onContextRestoredBound);

    this.scene.remove(this.homekeeper.group);
    if (this.resident) this.scene.remove(this.resident.group);
    this.scene.traverse((obj) => {
      if ((obj as THREE.Mesh).isMesh || (obj as THREE.Points).isPoints) {
        const renderable = obj as THREE.Mesh | THREE.Points;
        if (renderable.userData.sharedAsset) return;
        renderable.geometry?.dispose();
        const mats = Array.isArray(renderable.material)
          ? renderable.material
          : [renderable.material];
        for (const m of mats) {
          if (!m || m.userData.sharedAsset) continue;
          const std = m as THREE.MeshStandardMaterial;
          if (std.map && std.map !== this.contactShadowTex) std.map.dispose();
          m.dispose();
        }
      }
    });

    disposeRiggedActor(this.homekeeper);
    if (this.resident) disposeRiggedActor(this.resident);
    this.contactShadowTex.dispose();
    this.renderer.dispose();
    this.threeCanvas.remove();
  }
}
