import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { JOBS, getJobById } from '../../src/core/jobs';

interface Box {
  label: string;
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

function overlaps(a: Box, b: Box): boolean {
  return a.x1 < b.x2 && a.x2 > b.x1 && a.y1 < b.y2 && a.y2 > b.y1;
}

describe('jobs catalog', () => {
  it('contains 5 progressive houses including Indonesian homes and UK Castle finale', () => {
    expect(JOBS.length).toBe(5);
    expect(JOBS.map((j) => j.level)).toEqual([1, 2, 3, 4, 5]);
    expect(JOBS[4].id).toBe('kastil-lord-arthur');
    expect(getJobById('kos-rina')?.level).toBe(1);
    expect(getJobById('missing-house')).toBeUndefined();
  });

  it('references existing CC0 .glb assets for every 3D furniture & clutter model', () => {
    const modelsDir = join(process.cwd(), 'public', 'models');
    for (const job of JOBS) {
      expect(job.furnitureLayout?.length ?? 0).toBeGreaterThanOrEqual(5);
      for (const prop of job.furnitureLayout ?? []) {
        expect(existsSync(join(modelsDir, prop.modelName))).toBe(true);
      }
      for (const st of job.stains) {
        expect(st.pos3D).toBeDefined();
        expect(st.size3D).toBeDefined();
      }
      for (const cl of job.clutter) {
        expect(cl.pos3D).toBeDefined();
        expect(cl.targetPos3D).toBeDefined();
        if (cl.modelName) {
          expect(existsSync(join(modelsDir, cl.modelName))).toBe(true);
        }
      }
    }
  });

  it('ensures every job has complete localized copy, stains, clutter, and non-overlapping playfield bounds', () => {
    const jobIds = new Set<string>();
    for (const job of JOBS) {
      expect(jobIds.has(job.id)).toBe(false);
      jobIds.add(job.id);

      expect(job.title.id.trim().length).toBeGreaterThan(0);
      expect(job.title.en.trim().length).toBeGreaterThan(0);
      expect(job.storyNote.id.trim().length).toBeGreaterThan(0);
      expect(job.storyNote.en.trim().length).toBeGreaterThan(0);
      expect(job.baseWageRp).toBeGreaterThan(0);
      expect(job.parTimeSec).toBeGreaterThan(10);

      expect(job.stains.length).toBeGreaterThanOrEqual(2);
      expect(job.clutter.length).toBeGreaterThanOrEqual(3);

      const stainBoxes: Box[] = [];
      const clutterStartBoxes: Box[] = [];
      const clutterTargetBoxes: Box[] = [];

      for (const s of job.stains) {
        expect(s.x).toBeGreaterThanOrEqual(16);
        expect(s.y).toBeGreaterThanOrEqual(110);
        expect(s.x + s.width).toBeLessThanOrEqual(434);
        expect(s.y + s.height).toBeLessThanOrEqual(650);
        stainBoxes.push({ label: `stain:${s.id}`, x1: s.x, y1: s.y, x2: s.x + s.width, y2: s.y + s.height });
      }

      for (const c of job.clutter) {
        const half = c.size / 2;
        expect(c.startX - half).toBeGreaterThanOrEqual(16);
        expect(c.startY - half).toBeGreaterThanOrEqual(110);
        expect(c.startX + half).toBeLessThanOrEqual(434);
        expect(c.startY + half).toBeLessThanOrEqual(650);

        expect(c.targetX - half).toBeGreaterThanOrEqual(16);
        expect(c.targetY - half).toBeGreaterThanOrEqual(110);
        expect(c.targetX + half).toBeLessThanOrEqual(434);
        expect(c.targetY + half).toBeLessThanOrEqual(650);

        clutterStartBoxes.push({
          label: `start:${c.id}`,
          x1: c.startX - half,
          y1: c.startY - half,
          x2: c.startX + half,
          y2: c.startY + half,
        });
        clutterTargetBoxes.push({
          label: `target:${c.id}`,
          x1: c.targetX - half,
          y1: c.targetY - half,
          x2: c.targetX + half,
          y2: c.targetY + half,
        });
      }

      // Clutter starts must not overlap stains or each other; targets must not overlap each other or stains
      for (let i = 0; i < clutterStartBoxes.length; i++) {
        for (let j = i + 1; j < clutterStartBoxes.length; j++) {
          expect(overlaps(clutterStartBoxes[i], clutterStartBoxes[j])).toBe(false);
          expect(overlaps(clutterTargetBoxes[i], clutterTargetBoxes[j])).toBe(false);
        }
        for (const sb of stainBoxes) {
          expect(overlaps(clutterStartBoxes[i], sb)).toBe(false);
          expect(overlaps(clutterTargetBoxes[i], sb)).toBe(false);
        }
      }
    }
  });
});
