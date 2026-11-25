import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import type { ClutterItemSpec, JobSpec, StainKind, StainSpotSpec } from '../core/types';
import { CoverageGrid } from '../core/coverage';
import {
  CAMERA_FOV_DEG,
  CAMERA_HEIGHT,
  CAMERA_LOOK_Y,
  CAMERA_RADIUS,
  clampRoomXZ,
  intersectRayPlane,
  isWithin3DSnapRadius,
  screenToNDC,
  worldHitToDecalUV,
  type Vec3,
} from '../core/math3d';

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

function centerAndGroundGroup(raw: THREE.Object3D, scale = 1): THREE.Group {
  const wrapper = new THREE.Group();
  const clone = raw.clone(true);
  clone.scale.setScalar(scale);
  clone.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(clone);
  const center = new THREE.Vector3();
  box.getCenter(center);
  clone.position.set(-center.x, -box.min.y, -center.z);
  wrapper.add(clone);
  return wrapper;
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

function createWoodFloorTexture(hexColor: string): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext('2d')!;
  ctx.fillStyle = hexColor;
  ctx.fillRect(0, 0, 256, 256);

  ctx.strokeStyle = 'rgba(61, 64, 91, 0.14)';
  ctx.lineWidth = 2;
  for (let y = 0; y < 256; y += 32) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(256, y);
    ctx.stroke();
    const offset = (y / 32) % 2 === 0 ? 64 : 160;
    ctx.beginPath();
    ctx.moveTo(offset, y);
    ctx.lineTo(offset, y + 32);
    ctx.stroke();
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(4, 4);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export interface Room3DCallbacks {
  onProgress: (pct: number) => void;
  onStainCleared: () => void;
  onScrubStroke: () => void;
  onClutterSnapped: (item: ClutterItemSpec) => void;
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

export class Room3DView {
  private readonly phaserCanvas: HTMLCanvasElement;
  private readonly threeCanvas: HTMLCanvasElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene: THREE.Scene;
  private readonly camera: THREE.PerspectiveCamera;
  private readonly raycaster = new THREE.Raycaster();
  private readonly callbacks: Room3DCallbacks;
  private readonly job: JobSpec;

  private stains: Stain3DState[] = [];
  private clutter: Clutter3DState[] = [];
  private dragged: Clutter3DState | null = null;
  private lastScrubUV: { stainId: string; px: number; py: number } | null = null;

  private orbitAngle = 0;
  private orbitTargetAngle = 0;
  private dirty = true;
  private destroyed = false;
  private finished = false;
  private rafId = 0;
  private brushRadiusPx = 18;
  private snapRadiusMeters = 0.55;

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
  ) {
    this.phaserCanvas = phaserCanvas;
    this.job = job;
    this.brushRadiusPx = brushRadiusPx;
    this.snapRadiusMeters = snapRadiusMeters;
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
    this.scene.background = new THREE.Color(job.palette.wall);

    this.camera = new THREE.PerspectiveCamera(CAMERA_FOV_DEG, 450 / 800, 0.1, 30);
    this.updateCameraPosition();

    this.setupLights();
    this.buildRoomShell();
    this.buildStains();
    void this.buildFurnitureAndClutter();

    this.syncCanvasBounds();
    window.addEventListener('resize', this.onResizeBound);
    this.threeCanvas.addEventListener('webglcontextlost', this.onContextLostBound);
    this.threeCanvas.addEventListener('webglcontextrestored', this.onContextRestoredBound);

    this.rafId = requestAnimationFrame(this.tick);
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
        c.targetRing.scale.setScalar(1.35);
      }
    }
    this.markDirty();
  }

  markDirty(): void {
    this.dirty = true;
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
    const floorTex = createWoodFloorTexture(this.job.palette.floor);
    const floor = new THREE.Mesh(
      new THREE.BoxGeometry(4.8, 0.14, 4.8),
      new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.85 }),
    );
    floor.position.set(0, -0.07, 0);
    floor.receiveShadow = true;
    this.scene.add(floor);

    const wallMat = new THREE.MeshStandardMaterial({ color: this.job.palette.wall, roughness: 0.9 });
    const trimMat = new THREE.MeshStandardMaterial({ color: this.job.palette.trim, roughness: 0.7 });

    // Back wall
    const backWall = new THREE.Mesh(new THREE.BoxGeometry(4.8, 2.7, 0.12), wallMat);
    backWall.position.set(0, 1.35, -2.38);
    backWall.receiveShadow = true;
    this.scene.add(backWall);

    // Left wall
    const leftWall = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.7, 4.8), wallMat);
    leftWall.position.set(-2.38, 1.35, 0);
    leftWall.receiveShadow = true;
    this.scene.add(leftWall);

    // Baseboards
    const baseBack = new THREE.Mesh(new THREE.BoxGeometry(4.8, 0.12, 0.15), trimMat);
    baseBack.position.set(0, 0.06, -2.35);
    const baseLeft = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.12, 4.8), trimMat);
    baseLeft.position.set(-2.35, 0.06, 0);
    this.scene.add(baseBack, baseLeft);

    // Cozy sunny window on back wall
    const frame = new THREE.Mesh(new THREE.BoxGeometry(1.15, 0.92, 0.05), trimMat);
    frame.position.set(0.35, 1.55, -2.31);
    const glass = new THREE.Mesh(
      new THREE.PlaneGeometry(0.98, 0.76),
      new THREE.MeshBasicMaterial({ color: 0xffe8b6 }),
    );
    glass.position.set(0.35, 1.55, -2.28);
    this.scene.add(frame, glass);
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

  private async buildFurnitureAndClutter(): Promise<void> {
    const furniturePromises = (this.job.furnitureLayout ?? []).map(async (prop) => {
      const tpl = await loadGltfInstance(prop.modelName);
      if (this.destroyed || !tpl) return;
      const g = centerAndGroundGroup(tpl, prop.scale3D ?? 1);
      g.position.set(prop.pos3D[0], prop.pos3D[1], prop.pos3D[2]);
      g.rotation.y = prop.rotY3D ?? 0;
      this.scene.add(g);
    });

    const clutterPromises = this.job.clutter.map(async (item) => {
      const startPos: Vec3 = item.pos3D ?? [0, 0, 1.2];
      const targetPos: Vec3 = item.targetPos3D ?? [0, 0.5, -1.2];

      let visual: THREE.Group;
      if (item.modelName) {
        const tpl = await loadGltfInstance(item.modelName);
        if (this.destroyed) return;
        visual = tpl
          ? centerAndGroundGroup(tpl, item.scale3D ?? 1)
          : buildHeroOrFallbackProp(item.kind);
      } else {
        visual = buildHeroOrFallbackProp(item.kind);
      }
      if (this.destroyed) return;

      visual.position.set(startPos[0], startPos[1], startPos[2]);
      if (item.rotY3D) visual.rotation.y = item.rotY3D;

      // Generous invisible touch proxy for easy mobile grabbing
      const hitProxy = new THREE.Mesh(
        new THREE.SphereGeometry(0.32, 10, 10),
        new THREE.MeshBasicMaterial({ visible: false }),
      );
      hitProxy.position.y = 0.16;
      hitProxy.userData = { clutterId: item.id };
      visual.add(hitProxy);
      this.scene.add(visual);

      // Glowing green 3D target ring at targetPos
      const ringMat = new THREE.MeshBasicMaterial({
        color: 0x2a9d8f,
        side: THREE.DoubleSide,
        transparent: true,
        opacity: 0.78,
      });
      const targetRing = new THREE.Mesh(new THREE.RingGeometry(0.16, 0.24, 28), ringMat);
      targetRing.rotation.x = -Math.PI / 2;
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

    await Promise.all([...furniturePromises, ...clutterPromises]);
    this.renderer.shadowMap.needsUpdate = true;
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
    if (this.finished || this.destroyed) return;
    if (!this.pointerToRay(clientX, clientY)) return;

    // 1. Check clutter proxies first
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

    // 2. Otherwise try scrubbing stain decals
    this.scrubAt(clientX, clientY);
  }

  onPointerMove(clientX: number, clientY: number): void {
    if (this.finished || this.destroyed) return;
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

    this.scrubAt(clientX, clientY);
  }

  onPointerUp(): void {
    this.lastScrubUV = null;
    const item = this.dragged;
    if (!item) return;
    this.dragged = null;

    const currentPos: Vec3 = [item.group.position.x, item.targetPos[1], item.group.position.z];
    const snapped = isWithin3DSnapRadius(currentPos, item.targetPos, this.snapRadiusMeters);
    if (snapped) {
      item.done = true;
      item.group.position.set(item.targetPos[0], item.targetPos[1], item.targetPos[2]);
      item.targetRing.visible = false;
      this.callbacks.onClutterSnapped(item.spec);
      this.emitProgressAndCheckWin();
    } else {
      item.group.position.set(item.startPos[0], item.startPos[1], item.startPos[2]);
      (item.targetRing.material as THREE.MeshBasicMaterial).color.setHex(0x2a9d8f);
    }
    this.renderer.shadowMap.needsUpdate = true;
    this.markDirty();
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

    // Interpolate 2D canvas erase & CoverageGrid identically
    const r = this.brushRadiusPx;
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

    this.callbacks.onScrubStroke();

    if (st.grid.isComplete) {
      st.done = true;
      st.grid.markComplete();
      st.mesh.visible = false;
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
      this.callbacks.onComplete();
    }
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

  private tick = (): void => {
    if (this.destroyed) return;
    this.rafId = requestAnimationFrame(this.tick);

    // Smooth camera orbit interpolation (snappy & mobile-friendly)
    if (Math.abs(this.orbitTargetAngle - this.orbitAngle) > 0.008) {
      this.orbitAngle += (this.orbitTargetAngle - this.orbitAngle) * 0.28;
      this.updateCameraPosition();
      this.dirty = true;
    } else if (this.orbitAngle !== this.orbitTargetAngle) {
      this.orbitAngle = this.orbitTargetAngle;
      this.updateCameraPosition();
      this.dirty = true;
    }

    // Gentle decay if pulseRemaining scaled rings up
    for (const c of this.clutter) {
      if (!c.done && c.targetRing.scale.x > 1.01) {
        c.targetRing.scale.lerp(new THREE.Vector3(1, 1, 1), 0.08);
        this.dirty = true;
      }
    }

    // Batch stain canvas texture uploads & Dust Radar emissive pulse once per frame
    for (const st of this.stains) {
      if (st.texDirty) {
        st.tex.needsUpdate = true;
        st.texDirty = false;
        this.dirty = true;
      }
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

    if (this.dirty) {
      this.dirty = false;
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

    this.scene.traverse((obj) => {
      if ((obj as THREE.Mesh).isMesh) {
        const mesh = obj as THREE.Mesh;
        mesh.geometry?.dispose();
        const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
        for (const m of mats) {
          if (!m) continue;
          const std = m as THREE.MeshStandardMaterial;
          std.map?.dispose();
          m.dispose();
        }
      }
    });

    this.renderer.dispose();
    this.threeCanvas.remove();
  }
}
