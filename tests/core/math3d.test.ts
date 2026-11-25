import { describe, it, expect } from 'vitest';
import {
  screenToNDC,
  intersectRayPlane,
  worldHitToDecalUV,
  clampRoomXZ,
  distance3D,
  isWithin3DSnapRadius,
  isTapGesture,
} from '../../src/core/math3d';

describe('math3d', () => {
  it('converts screen coordinates inside Phaser FIT rect into Three.js NDC [-1, 1]', () => {
    const rect = { left: 100, top: 50, width: 450, height: 800 };
    expect(screenToNDC(325, 450, rect)).toEqual({ x: 0, y: 0 });
    expect(screenToNDC(100, 50, rect)).toEqual({ x: -1, y: 1 });
    expect(screenToNDC(550, 850, rect)).toEqual({ x: 1, y: -1 });
    expect(screenToNDC(10, 10, { left: 0, top: 0, width: 0, height: 100 })).toBeNull();
  });

  it('intersects ray with horizontal plane at item elevation and rejects parallel/backward rays', () => {
    const hit = intersectRayPlane([0, 5, 5], [0, -1, -1], [0, 0.75, 0], [0, 1, 0]);
    expect(hit).not.toBeNull();
    expect(hit![1]).toBeCloseTo(0.75, 5);
    expect(hit![0]).toBeCloseTo(0, 5);
    expect(hit![2]).toBeCloseTo(0.75, 5);

    // Parallel ray
    expect(intersectRayPlane([0, 2, 0], [1, 0, 0], [0, 0, 0], [0, 1, 0])).toBeNull();
    // Ray pointing away from plane
    expect(intersectRayPlane([0, 2, 0], [0, 1, 0], [0, 0, 0], [0, 1, 0])).toBeNull();
  });

  it('maps 3D hit point on horizontal decal quad into local [0..1] UV', () => {
    const uvCenter = worldHitToDecalUV([1, 0.01, -1], [1, 0.01, -1], [2, 2]);
    expect(uvCenter).toEqual({ u: 0.5, v: 0.5 });

    const uvCorner = worldHitToDecalUV([0, 0.01, -2], [1, 0.01, -1], [2, 2]);
    expect(uvCorner).toEqual({ u: 0, v: 0 });

    expect(worldHitToDecalUV([5, 0.01, 5], [1, 0.01, -1], [2, 2])).toBeNull();
  });

  it('clamps XZ coordinates within room walls and checks 3D snap radius', () => {
    expect(clampRoomXZ(5, -4, 2.2)).toEqual([2.2, -2.2]);
    expect(clampRoomXZ(0.5, -1.0, 2.2)).toEqual([0.5, -1.0]);
    expect(distance3D([0, 0, 0], [0.3, 0.4, 0])).toBeCloseTo(0.5, 5);
    expect(isWithin3DSnapRadius([1, 0.5, 1], [1.2, 0.5, 1.2], 0.45)).toBe(true);
    expect(isWithin3DSnapRadius([1, 0.5, 1], [2.0, 0.5, 1.0], 0.45)).toBe(false);
    expect(isTapGesture(100, 100, 104, 103)).toBe(true);
    expect(isTapGesture(100, 100, 115, 100)).toBe(false);
  });
});
