import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { JOBS, getJobById } from '../../src/core/jobs';
import { projectWorldToCanvas } from '../../src/core/math3d';

function readGlbBounds(modelName: string): { w: number; h: number; d: number } {
  const buf = readFileSync(join(process.cwd(), 'public', 'models', modelName));
  const jsonLen = buf.readUInt32LE(12);
  const gltf = JSON.parse(buf.subarray(20, 20 + jsonLen).toString('utf8'));
  const accessors = gltf.accessors ?? [];
  let minX = Infinity, maxX = -Infinity;
  let minY = Infinity, maxY = -Infinity;
  let minZ = Infinity, maxZ = -Infinity;
  for (const mesh of gltf.meshes ?? []) {
    for (const prim of mesh.primitives ?? []) {
      const idx = prim.attributes?.POSITION;
      if (typeof idx !== 'number') continue;
      const acc = accessors[idx];
      if (!acc?.min || !acc?.max) continue;
      minX = Math.min(minX, acc.min[0]); maxX = Math.max(maxX, acc.max[0]);
      minY = Math.min(minY, acc.min[1]); maxY = Math.max(maxY, acc.max[1]);
      minZ = Math.min(minZ, acc.min[2]); maxZ = Math.max(maxZ, acc.max[2]);
    }
  }
  return { w: maxX - minX, h: maxY - minY, d: maxZ - minZ };
}

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

  it('places elevated tabletop stains and clutter cleanly on top of real GLB furniture heights without clipping', () => {
    const surfaceProps = new Set([
      'desk.glb',
      'bookcaseOpenLow.glb',
      'tableCoffeeSquare.glb',
      'cabinetTelevision.glb',
      'tableRound.glb',
      'kitchenCabinet.glb',
      'tableCoffeeGlass.glb',
      'tableCrossCloth.glb',
      'bookcaseClosedWide.glb',
    ]);

    for (const job of JOBS) {
      const surfaces = (job.furnitureLayout ?? [])
        .filter((f) => surfaceProps.has(f.modelName))
        .map((f) => {
          const b = readGlbBounds(f.modelName);
          const sc = f.scale3D ?? 1;
          return {
            modelName: f.modelName,
            x: f.pos3D[0],
            z: f.pos3D[2],
            topY: b.h * sc,
            radius: Math.max(b.w, b.d) * sc * 0.55,
          };
        });

      const checkElevated = (label: string, pos: [number, number, number]) => {
        if (pos[1] <= 0.15) return;
        const match = surfaces.find(
          (s) => Math.hypot(pos[0] - s.x, pos[2] - s.z) <= s.radius,
        );
        if (!match) return;
        expect(pos[1], `${job.id} ${label} clips inside ${match.modelName}`).toBeGreaterThanOrEqual(
          match.topY - 0.015,
        );
        expect(pos[1], `${job.id} ${label} floats above ${match.modelName}`).toBeLessThanOrEqual(
          match.topY + 0.06,
        );
      };

      for (const st of job.stains) {
        if (st.pos3D) checkElevated(`stain:${st.id}`, st.pos3D);
      }
      for (const cl of job.clutter) {
        if (cl.targetPos3D) checkElevated(`clutter:${cl.id}`, cl.targetPos3D);
      }
    }
  });

  it('frames every stain and clutter start/target inside the 450x800 portrait playfield at default camera angle', () => {
    for (const job of JOBS) {
      for (const st of job.stains) {
        const pt = projectWorldToCanvas(st.pos3D!);
        expect(pt, `${job.id} stain:${st.id} in front of camera`).not.toBeNull();
        expect(pt!.x, `${job.id} stain:${st.id} x`).toBeGreaterThanOrEqual(16);
        expect(pt!.x, `${job.id} stain:${st.id} x`).toBeLessThanOrEqual(434);
        expect(pt!.y, `${job.id} stain:${st.id} y`).toBeGreaterThanOrEqual(106);
        expect(pt!.y, `${job.id} stain:${st.id} y`).toBeLessThanOrEqual(666);
      }
      for (const cl of job.clutter) {
        for (const [tag, p3] of [
          ['start', cl.pos3D!],
          ['target', cl.targetPos3D!],
        ] as const) {
          const pt = projectWorldToCanvas(p3);
          expect(pt, `${job.id} ${cl.id} ${tag}`).not.toBeNull();
          expect(pt!.x, `${job.id} ${cl.id} ${tag} x`).toBeGreaterThanOrEqual(16);
          expect(pt!.x, `${job.id} ${cl.id} ${tag} x`).toBeLessThanOrEqual(434);
          expect(pt!.y, `${job.id} ${cl.id} ${tag} y`).toBeGreaterThanOrEqual(106);
          expect(pt!.y, `${job.id} ${cl.id} ${tag} y`).toBeLessThanOrEqual(666);
        }
      }
    }
  });
});
