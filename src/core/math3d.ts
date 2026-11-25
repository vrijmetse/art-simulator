export interface ViewportRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export type Vec3 = [number, number, number];

export function screenToNDC(
  clientX: number,
  clientY: number,
  rect: ViewportRect,
): { x: number; y: number } | null {
  if (rect.width <= 0 || rect.height <= 0) return null;
  const nx = ((clientX - rect.left) / rect.width) * 2 - 1;
  const ny = -(((clientY - rect.top) / rect.height) * 2 - 1);
  return { x: nx || 0, y: ny || 0 };
}

export function intersectRayPlane(
  origin: Vec3,
  dir: Vec3,
  planePoint: Vec3,
  planeNormal: Vec3,
): Vec3 | null {
  const denom =
    dir[0] * planeNormal[0] + dir[1] * planeNormal[1] + dir[2] * planeNormal[2];
  if (Math.abs(denom) < 1e-6) return null;

  const diffX = planePoint[0] - origin[0];
  const diffY = planePoint[1] - origin[1];
  const diffZ = planePoint[2] - origin[2];
  const t =
    (diffX * planeNormal[0] + diffY * planeNormal[1] + diffZ * planeNormal[2]) / denom;
  if (t < 0) return null;

  return [
    origin[0] + dir[0] * t,
    origin[1] + dir[1] * t,
    origin[2] + dir[2] * t,
  ];
}

export function worldHitToDecalUV(
  hitPoint: Vec3,
  decalCenter: Vec3,
  decalSize: [number, number],
): { u: number; v: number } | null {
  const [w, h] = decalSize;
  if (w <= 0 || h <= 0) return null;
  const u = (hitPoint[0] - (decalCenter[0] - w / 2)) / w;
  const v = (hitPoint[2] - (decalCenter[2] - h / 2)) / h;
  if (u < 0 || u > 1 || v < 0 || v > 1) return null;
  return { u, v };
}

export function clampRoomXZ(x: number, z: number, halfExtent = 2.1): [number, number] {
  return [
    Math.max(-halfExtent, Math.min(halfExtent, x)),
    Math.max(-halfExtent, Math.min(halfExtent, z)),
  ];
}

export function distance3D(a: Vec3, b: Vec3): number {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

export const CAMERA_FOV_DEG = 52;
export const CAMERA_RADIUS = 8.2;
export const CAMERA_HEIGHT = 6.1;
export const CAMERA_LOOK_Y = 0.35;

export function projectWorldToCanvas(
  pos: Vec3,
  orbitAngleRad = 0,
  width = 450,
  height = 800,
): { x: number; y: number } | null {
  const baseAngle = Math.PI / 4 + orbitAngleRad;
  const ex = Math.sin(baseAngle) * CAMERA_RADIUS;
  const ey = CAMERA_HEIGHT;
  const ez = Math.cos(baseAngle) * CAMERA_RADIUS;

  let fx = -ex;
  let fy = CAMERA_LOOK_Y - ey;
  let fz = -ez;
  const fl = Math.hypot(fx, fy, fz);
  if (fl < 1e-6) return null;
  fx /= fl; fy /= fl; fz /= fl;

  let rx = -fz;
  let rz = fx;
  const rl = Math.hypot(rx, rz);
  if (rl < 1e-6) return null;
  rx /= rl; rz /= rl;

  const ux = -rz * fy;
  const uy = rz * fx - rx * fz;
  const uz = rx * fy;

  const dx = pos[0] - ex;
  const dy = pos[1] - ey;
  const dz = pos[2] - ez;

  const cx = dx * rx + dz * rz;
  const cy = dx * ux + dy * uy + dz * uz;
  const cz = -(dx * fx + dy * fy + dz * fz);
  if (cz >= -0.1) return null;

  const aspect = width / height;
  const fTan = Math.tan((CAMERA_FOV_DEG * Math.PI) / 360);
  const ndcX = cx / (-cz * fTan * aspect);
  const ndcY = cy / (-cz * fTan);
  return {
    x: (ndcX + 1) * 0.5 * width,
    y: (1 - ndcY) * 0.5 * height,
  };
}

export function isWithin3DSnapRadius(posA: Vec3, posB: Vec3, radiusMeters: number): boolean {
  return distance3D(posA, posB) <= radiusMeters;
}

export function isTapGesture(
  downX: number,
  downY: number,
  upX: number,
  upY: number,
  maxDistPx = 10,
): boolean {
  return Math.hypot(upX - downX, upY - downY) <= maxDistPx;
}
