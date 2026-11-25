import { describe, it, expect } from 'vitest';
import { FURNITURE_FOOTPRINTS, generateDailyJob } from '../../src/core/daily';
import { projectWorldToCanvas } from '../../src/core/math3d';

describe('procedural daily shift generator', () => {
  it('generates deterministic daily shift per dateKey with valid bounds & zero furniture overlap', () => {
    const a = generateDailyJob('2026-11-25', 3);
    const b = generateDailyJob('2026-11-25', 3);
    const c = generateDailyJob('2026-11-26', 3);

    expect(a.id).toBe('daily-2026-11-25');
    expect(a.isDaily).toBe(true);
    expect(a.dailyDateKey).toBe('2026-11-25');
    expect(a).toEqual(b);
    expect(c.id).toBe('daily-2026-11-26');
    expect(a.stains.length).toBeGreaterThanOrEqual(3);
    expect(a.clutter.length).toBe(3);

    for (const st of a.stains) {
      const pt = projectWorldToCanvas(st.pos3D!);
      expect(pt).not.toBeNull();
      expect(pt!.x).toBeGreaterThanOrEqual(16);
      expect(pt!.x).toBeLessThanOrEqual(434);
      expect(pt!.y).toBeGreaterThanOrEqual(106);
      expect(pt!.y).toBeLessThanOrEqual(666);

      // Floor stains must not spawn inside furniture footprints
      if (st.pos3D![1] < 0.1) {
        for (const prop of a.furnitureLayout ?? []) {
          const fp = FURNITURE_FOOTPRINTS[prop.modelName];
          if (!fp || prop.modelName.startsWith('rug')) continue;
          const sc = prop.scale3D ?? 1;
          const hx = fp[0] * sc;
          const hz = fp[1] * sc;
          const inside =
            Math.abs(st.pos3D![0] - prop.pos3D[0]) < hx &&
            Math.abs(st.pos3D![2] - prop.pos3D[2]) < hz;
          expect(inside, `stain ${st.id} inside ${prop.modelName}`).toBe(false);
        }
      }
    }
  });
});
