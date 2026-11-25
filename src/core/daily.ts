import type { ClutterItemSpec, JobSpec, StainKind, StainSpotSpec } from './types';
import { JOBS } from './jobs';
import { projectWorldToCanvas } from './math3d';

/** Half-extents [hx, hz] at scale 1.0 derived from CC0 GLB dimensions */
export const FURNITURE_FOOTPRINTS: Record<string, [number, number]> = {
  'bedSingle.glb': [0.82, 0.95],
  'bedDouble.glb': [0.82, 0.96],
  'desk.glb': [0.37, 0.28],
  'chairDesk.glb': [0.25, 0.25],
  'bookcaseOpenLow.glb': [0.22, 0.16],
  'bookcaseClosedWide.glb': [0.42, 0.16],
  'pottedPlant.glb': [0.22, 0.22],
  'plantSmall1.glb': [0.18, 0.18],
  'plantSmall2.glb': [0.18, 0.18],
  'loungeSofa.glb': [0.75, 0.40],
  'loungeChair.glb': [0.40, 0.40],
  'loungeChairRelax.glb': [0.40, 0.45],
  'tableCoffeeSquare.glb': [0.22, 0.22],
  'tableCoffeeGlass.glb': [0.34, 0.22],
  'cabinetTelevision.glb': [0.42, 0.16],
  'lampRoundFloor.glb': [0.20, 0.20],
  'kitchenCabinet.glb': [0.24, 0.26],
  'kitchenStove.glb': [0.24, 0.26],
  'kitchenSink.glb': [0.24, 0.26],
  'kitchenFridge.glb': [0.26, 0.28],
  'tableRound.glb': [0.36, 0.42],
  'chair.glb': [0.22, 0.22],
  'tableCrossCloth.glb': [1.02, 0.54],
  'chairCushion.glb': [0.22, 0.22],
  'benchCushion.glb': [0.22, 0.14],
};

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hashDateKey(dateKey: string): number {
  let h = 2166136261;
  for (let i = 0; i < dateKey.length; i++) {
    h ^= dateKey.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

const STAIN_KINDS: StainKind[] = ['dust', 'spill', 'mud', 'grease'];

function isClearOfFurniture(x: number, z: number, template: JobSpec): boolean {
  for (const prop of template.furnitureLayout ?? []) {
    if (prop.modelName.startsWith('rug') || prop.modelName.startsWith('lampWall')) continue;
    const fp = FURNITURE_FOOTPRINTS[prop.modelName];
    if (!fp) continue;
    const sc = prop.scale3D ?? 1;
    const hx = fp[0] * sc + 0.18;
    const hz = fp[1] * sc + 0.18;
    if (Math.abs(x - prop.pos3D[0]) < hx && Math.abs(z - prop.pos3D[2]) < hz) {
      return false;
    }
  }
  const pt = projectWorldToCanvas([x, 0.03, z]);
  if (!pt) return false;
  return pt.x >= 32 && pt.x <= 418 && pt.y >= 120 && pt.y <= 645;
}

export function generateDailyJob(dateKey: string, unlockedLevel: number): JobSpec {
  const rng = mulberry32(hashDateKey(dateKey));
  const pool = JOBS.filter((j) => j.level <= Math.max(1, Math.min(JOBS.length, unlockedLevel)));
  const template = pool[Math.floor(rng() * pool.length)] ?? JOBS[0];

  // Candidate clear floor spots sorted deterministically by RNG
  const candidates: Array<[number, number]> = [
    [-0.2, 0.95],
    [0.55, 0.85],
    [1.15, 0.45],
    [-0.95, 1.35],
    [0.25, 1.45],
    [1.25, 1.25],
    [-0.15, 0.25],
    [0.85, -0.35],
  ].filter(([cx, cz]) => isClearOfFurniture(cx, cz, template)) as Array<[number, number]>;

  // Fallback safe floor spot if a room is unusually packed
  const safeSpots = candidates.length >= 3 ? candidates : ([[0.2, 1.3], [1.1, 1.1], [-0.4, 1.4]] as Array<[number, number]>);

  const stains: StainSpotSpec[] = [];
  const usedIndices = new Set<number>();
  for (let i = 0; i < 3; i++) {
    let idx = Math.floor(rng() * safeSpots.length);
    while (usedIndices.has(idx) && usedIndices.size < safeSpots.length) {
      idx = (idx + 1) % safeSpots.length;
    }
    usedIndices.add(idx);
    const [sx, sz] = safeSpots[idx];
    const kind = STAIN_KINDS[Math.floor(rng() * STAIN_KINDS.length)];
    stains.push({
      id: `daily-stain-${i}`,
      kind,
      x: 40 + i * 120,
      y: 160 + (i % 2) * 140,
      width: 110,
      height: 85,
      pos3D: [sx, 0.03, sz],
      size3D: [0.9, 0.82],
    });
  }

  // Shuffle clutter start spots cleanly while keeping their calibrated target positions
  const startPool: Array<[number, number, number]> = [
    [-0.65, 0.0, 1.45],
    [0.25, 0.0, 1.55],
    [1.25, 0.0, 1.35],
  ];
  const clutter: ClutterItemSpec[] = template.clutter.map((c, idx) => {
    const start = startPool[(idx + Math.floor(rng() * startPool.length)) % startPool.length];
    return {
      ...c,
      id: `daily-${c.id}`,
      pos3D: start,
    };
  });

  return {
    ...template,
    id: `daily-${dateKey}`,
    isDaily: true,
    dailyDateKey: dateKey,
    title: {
      id: `Tugas Harian: ${template.title.id}`,
      en: `Daily Shift: ${template.title.en}`,
    },
    briefing: {
      id: 'Kontrak spesial hari ini — selesaikan untuk +50% bonus & streak!',
      en: 'Today’s special contract — finish for +50% bonus & streak!',
    },
    baseWageRp: Math.round(template.baseWageRp * 1.5),
    stains,
    clutter,
  };
}
