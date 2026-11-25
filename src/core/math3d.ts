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

export function isWithin3DSnapRadius(posA: Vec3, posB: Vec3, radiusMeters: number): boolean {
  return distance3D(posA, posB) <= radiusMeters;
}
