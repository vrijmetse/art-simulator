import type { FurniturePropSpec } from './types';
import { FURNITURE_FOOTPRINTS } from './daily';
import { clampRoomXZ } from './math3d';

export type CharacterPose = 'idle' | 'walk' | 'scrub' | 'celebrate';

export interface PropAabb {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
}

export interface CharacterMotionState {
  x: number;
  z: number;
  targetX: number;
  targetZ: number;
  lookX: number;
  lookZ: number;
  rotY: number;
  pose: CharacterPose;
  animTime: number;
  scrubTimer: number;
  celebrateTimer: number;
  walkTimer: number;
}

export function getPropAabb(prop: FurniturePropSpec, padding = 0.22): PropAabb {
  // Rugs and elevated tabletop props don't block floor standing/walking
  if (prop.modelName.startsWith('rug') || prop.pos3D[1] > 0.2) {
    return { minX: 99, maxX: 99, minZ: 99, maxZ: 99 };
  }
  const base = FURNITURE_FOOTPRINTS[prop.modelName] ?? [0.25, 0.25];
  const s = prop.scale3D ?? 1;
  const hx = base[0] * s;
  const hz = base[1] * s;
  const r = prop.rotY3D ?? 0;
  const cos = Math.abs(Math.cos(r));
  const sin = Math.abs(Math.sin(r));
  const rx = hx * cos + hz * sin + padding;
  const rz = hx * sin + hz * cos + padding;
  return {
    minX: prop.pos3D[0] - rx,
    maxX: prop.pos3D[0] + rx,
    minZ: prop.pos3D[2] - rz,
    maxZ: prop.pos3D[2] + rz,
  };
}

export function isPointInsideAnyAabb(x: number, z: number, aabbs: PropAabb[]): boolean {
  for (const box of aabbs) {
    if (x >= box.minX && x <= box.maxX && z >= box.minZ && z <= box.maxZ) {
      return true;
    }
  }
  return false;
}

export function computeSafeStandPoint(
  actionX: number,
  actionZ: number,
  layout: FurniturePropSpec[],
  halfBounds = 2.02,
): [number, number] {
  const aabbs = layout.map((p) => getPropAabb(p, 0.22));
  const candidates: Array<{ x: number; z: number; score: number }> = [];
  const radii = [0.68, 0.96, 1.28];

  for (const rad of radii) {
    for (let i = 0; i < 12; i++) {
      // Bias starting angles toward front-right / open view (+Z/+X)
      const angle = (i / 12) * Math.PI * 2 + Math.PI / 4;
      const [cx, cz] = clampRoomXZ(
        actionX + Math.cos(angle) * rad,
        actionZ + Math.sin(angle) * rad,
        halfBounds,
      );
      if (!isPointInsideAnyAabb(cx, cz, aabbs)) {
        const dist = Math.hypot(cx - actionX, cz - actionZ);
        // Prefer positions slightly toward camera (+x, +z) so character stays visible
        const frontBias = (cx + cz) * -0.05;
        candidates.push({ x: cx, z: cz, score: dist + frontBias });
      }
    }
  }

  if (candidates.length > 0) {
    candidates.sort((a, b) => a.score - b.score);
    return [candidates[0].x, candidates[0].z];
  }

  // Fallback coarse room grid scan for packed layouts
  let best: [number, number] = [0, 0.8];
  let bestDist = Infinity;
  for (let gx = -1.75; gx <= 1.75; gx += 0.35) {
    for (let gz = -1.75; gz <= 1.75; gz += 0.35) {
      if (!isPointInsideAnyAabb(gx, gz, aabbs)) {
        const d = Math.hypot(gx - actionX, gz - actionZ);
        if (d < bestDist) {
          bestDist = d;
          best = [gx, gz];
        }
      }
    }
  }
  return best;
}

export function createCharacterState(startX = 0, startZ = 1.2): CharacterMotionState {
  return {
    x: startX,
    z: startZ,
    targetX: startX,
    targetZ: startZ,
    lookX: 0,
    lookZ: 0,
    rotY: Math.PI * 0.22,
    pose: 'idle',
    animTime: 0,
    scrubTimer: 0,
    celebrateTimer: 0,
    walkTimer: 0,
  };
}

function nudgeOutOfBoxes(x: number, z: number, aabbs: PropAabb[]): [number, number] {
  let nx = x;
  let nz = z;
  for (const box of aabbs) {
    if (nx > box.minX && nx < box.maxX && nz > box.minZ && nz < box.maxZ) {
      const dLeft = Math.abs(nx - box.minX);
      const dRight = Math.abs(box.maxX - nx);
      const dTop = Math.abs(nz - box.minZ);
      const dBottom = Math.abs(box.maxZ - nz);
      const m = Math.min(dLeft, dRight, dTop, dBottom);
      if (m === dLeft) nx = box.minX - 0.01;
      else if (m === dRight) nx = box.maxX + 0.01;
      else if (m === dTop) nz = box.minZ - 0.01;
      else nz = box.maxZ + 0.01;
    }
  }
  return clampRoomXZ(nx, nz, 2.02);
}

function lerpAngle(current: number, target: number, alpha: number): number {
  let diff = ((target - current + Math.PI) % (Math.PI * 2)) - Math.PI;
  if (diff < -Math.PI) diff += Math.PI * 2;
  return current + diff * alpha;
}

export function stepCharacterMotion(
  prev: CharacterMotionState,
  rawDtSec: number,
  aabbs: PropAabb[],
): { state: CharacterMotionState; needsFrame: boolean } {
  const dt = Math.min(0.05, Math.max(0, rawDtSec));
  if (prev.pose === 'idle') {
    return { state: prev, needsFrame: false };
  }

  let { x, z, rotY, animTime, scrubTimer, celebrateTimer, walkTimer } = prev;
  let pose: CharacterPose = prev.pose;
  animTime += dt;

  if (pose === 'walk') {
    walkTimer += dt;
    const dx = prev.targetX - x;
    const dz = prev.targetZ - z;
    const dist = Math.hypot(dx, dz);
    const speed = 2.8;
    const stepDist = speed * dt;

    if (dist <= Math.max(0.04, stepDist) || walkTimer >= 2.2) {
      x = prev.targetX;
      z = prev.targetZ;
      const faceX = prev.lookX - x;
      const faceZ = prev.lookZ - z;
      if (Math.hypot(faceX, faceZ) > 0.05) {
        rotY = Math.atan2(faceX, faceZ);
      }
      pose = scrubTimer > 0 ? 'scrub' : 'idle';
      walkTimer = 0;
    } else {
      const nextX = x + (dx / dist) * stepDist;
      const nextZ = z + (dz / dist) * stepDist;
      const [sx, sz] = nudgeOutOfBoxes(nextX, nextZ, aabbs);
      x = sx;
      z = sz;
      const targetAngle = Math.atan2(dx, dz);
      rotY = lerpAngle(rotY, targetAngle, Math.min(1, dt * 12));
    }
    return {
      state: { ...prev, x, z, rotY, pose, animTime, scrubTimer, celebrateTimer, walkTimer },
      needsFrame: true,
    };
  }

  if (pose === 'scrub') {
    scrubTimer -= dt;
    const faceX = prev.lookX - x;
    const faceZ = prev.lookZ - z;
    if (Math.hypot(faceX, faceZ) > 0.05) {
      rotY = lerpAngle(rotY, Math.atan2(faceX, faceZ), Math.min(1, dt * 10));
    }
    if (scrubTimer <= 0) {
      scrubTimer = 0;
      pose = 'idle';
    }
    return {
      state: { ...prev, x, z, rotY, pose, animTime, scrubTimer, celebrateTimer, walkTimer },
      needsFrame: true,
    };
  }

  // pose === 'celebrate'
  celebrateTimer -= dt;
  rotY = lerpAngle(rotY, Math.PI / 4, Math.min(1, dt * 8));
  if (celebrateTimer <= 0) {
    celebrateTimer = 0;
    pose = 'idle';
  }
  return {
    state: { ...prev, x, z, rotY, pose, animTime, scrubTimer, celebrateTimer, walkTimer },
    needsFrame: true,
  };
}
