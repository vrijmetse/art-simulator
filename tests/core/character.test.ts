import { describe, expect, it } from 'vitest';
import { JOBS } from '../../src/core/jobs';
import { buildPersonalKosFurniture, DECOR_ITEMS } from '../../src/core/decor';
import {
  computeSafeStandPoint,
  createCharacterState,
  getPropAabb,
  isPointInsideAnyAabb,
  stepCharacterMotion,
} from '../../src/core/character';

describe('character core (TDD)', () => {
  it('computes collision-free stand points across all 5 story rooms and personal Kos', () => {
    for (const job of JOBS) {
      const layout = job.furnitureLayout ?? [];
      const aabbs = layout.map((p) => getPropAabb(p, 0.22));
      for (const stain of job.stains) {
        const sx = stain.pos3D?.[0] ?? 0;
        const sz = stain.pos3D?.[2] ?? 0;
        const [tx, tz] = computeSafeStandPoint(sx, sz, layout);
        expect(Math.abs(tx)).toBeLessThanOrEqual(2.05);
        expect(Math.abs(tz)).toBeLessThanOrEqual(2.05);
        expect(isPointInsideAnyAabb(tx, tz, aabbs)).toBe(false);
      }
      for (const item of job.clutter) {
        const cx = item.targetPos3D?.[0] ?? 0;
        const cz = item.targetPos3D?.[2] ?? 0;
        const [tx, tz] = computeSafeStandPoint(cx, cz, layout);
        expect(Math.abs(tx)).toBeLessThanOrEqual(2.05);
        expect(Math.abs(tz)).toBeLessThanOrEqual(2.05);
        expect(isPointInsideAnyAabb(tx, tz, aabbs)).toBe(false);
      }
    }

    const fullKos = buildPersonalKosFurniture(DECOR_ITEMS.map((d) => d.id));
    const kosAabbs = fullKos.map((p) => getPropAabb(p, 0.22));
    const [kx, kz] = computeSafeStandPoint(0, 0.2, fullKos);
    expect(isPointInsideAnyAabb(kx, kz, kosAabbs)).toBe(false);
  });

  it('transitions walk -> idle (needsFrame=false), scrub -> idle, and celebrate -> idle cleanly', () => {
    let st = createCharacterState(0, 1.4);
    expect(st.pose).toBe('idle');

    // Command walk to (1.2, 0.8)
    st = { ...st, targetX: 1.2, targetZ: 0.8, pose: 'walk' };
    let movingFrames = 0;
    for (let i = 0; i < 80; i++) {
      const step = stepCharacterMotion(st, 0.03, []);
      st = step.state;
      if (step.needsFrame) movingFrames++;
    }
    expect(movingFrames).toBeGreaterThan(3);
    expect(st.pose).toBe('idle');
    expect(Math.hypot(st.x - 1.2, st.z - 0.8)).toBeLessThan(0.05);

    // Settled idle must stop demanding WebGL frames (battery conservation)
    const idleStep = stepCharacterMotion(st, 0.03, []);
    expect(idleStep.needsFrame).toBe(false);

    // Scrub decays back to idle
    st = { ...st, pose: 'scrub', scrubTimer: 0.2 };
    for (let i = 0; i < 12; i++) {
      st = stepCharacterMotion(st, 0.03, []).state;
    }
    expect(st.pose).toBe('idle');

    // Celebrate runs finite duration then rests
    st = { ...st, pose: 'celebrate', celebrateTimer: 0.3 };
    for (let i = 0; i < 15; i++) {
      st = stepCharacterMotion(st, 0.03, []).state;
    }
    expect(st.pose).toBe('idle');
  });
});
