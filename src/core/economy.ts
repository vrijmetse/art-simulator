import type {
  CashbookEntry,
  GameState,
  JobCompletionInput,
  JobSpec,
  StainKind,
  ToolMode,
  ToolStats,
  UpgradeId,
  UpgradeSpec,
} from './types';
import { getJobById, JOBS } from './jobs';
import { getCareerWageMultiplier } from './career';

export const UPGRADES: UpgradeSpec[] = [
  {
    id: 'wide_sponge',
    costRp: 25000,
    name: { id: 'Spons Lebar', en: 'Wide Sponge' },
    description: {
      id: 'Jangkauan gosok lebih luas 50%',
      en: '50% wider scrub radius per swipe',
    },
  },
  {
    id: 'citrus_cleaner',
    costRp: 40000,
    name: { id: 'Cairan Jeruk Wangi', en: 'Citrus Cleaner' },
    description: {
      id: 'Daya hapus noda membandel lebih cepat',
      en: 'Cuts through tough stains faster',
    },
  },
  {
    id: 'quick_gloves',
    costRp: 55000,
    name: { id: 'Sarung Tangan Gesit', en: 'Quick-Grip Gloves' },
    description: {
      id: 'Area pasang barang lebih mudah & nyaman',
      en: 'Wider magnetic snap zone when tidying',
    },
  },
  {
    id: 'neat_uniform',
    costRp: 75000,
    name: { id: 'Seragam Rapi', en: 'Neat Uniform' },
    description: {
      id: 'Tambah tip tuan rumah +25%',
      en: 'Increases host tip bonus by +25%',
    },
  },
  {
    id: 'sparkle_radar',
    costRp: 95000,
    name: { id: 'Radar Debu', en: 'Dust Radar' },
    description: {
      id: 'Menandai sisa noda & barang yang belum rapi',
      en: 'Highlights tiny remaining spots & items',
    },
  },
];

export function createInitialState(): GameState {
  return {
    version: 2,
    locale: 'id',
    muted: false,
    day: 1,
    balanceRp: 0,
    unlockedLevel: 1,
    bestStars: {},
    upgrades: [],
    cashbook: [],
    xp: 0,
    dailyCompletedDates: [],
    dailyStreak: 0,
    lastAttendanceDate: null,
    attendanceDay: 0,
    ownedDecor: [],
    placedDecor: [],
    avatarId: 'sari',
    npcChattedDates: {},
    adFree: false,
  };
}

export function getToolStats(upgrades: readonly UpgradeId[]): ToolStats {
  const hasWide = upgrades.includes('wide_sponge');
  const hasCitrus = upgrades.includes('citrus_cleaner');
  const hasGloves = upgrades.includes('quick_gloves');
  const hasUniform = upgrades.includes('neat_uniform');
  const hasRadar = upgrades.includes('sparkle_radar');

  return {
    brushRadius: (hasWide ? 36 : 24) + (hasCitrus ? 6 : 0),
    brushRadius3D: (hasWide ? 34 : 24) + (hasCitrus ? 6 : 0),
    scrubPower: hasCitrus ? 1.35 : 1.0,
    snapRadius: hasGloves ? 64 : 42,
    snapRadius3D: hasGloves ? 0.85 : 0.55,
    tipMultiplier: hasUniform ? 1.25 : 1.0,
    hasRadar,
  };
}

export function getToolMatchMultiplier(toolMode: ToolMode, stainKind: StainKind): number {
  if (toolMode === 'lap' && (stainKind === 'dust' || stainKind === 'crayon')) return 1.5;
  if (toolMode === 'pel' && (stainKind === 'spill' || stainKind === 'mud' || stainKind === 'grease')) {
    return 1.5;
  }
  return 1.0;
}

export function calculateJobPayout(
  job: JobSpec,
  elapsedSec: number,
  upgrades: readonly UpgradeId[],
  xp = 0,
): {
  stars: 1 | 2 | 3;
  baseWageRp: number;
  speedBonusRp: number;
  tipRp: number;
  totalRp: number;
} {
  const safeElapsed = Math.max(1, Math.round(elapsedSec));
  let stars: 1 | 2 | 3 = 1;
  if (safeElapsed <= job.parTimeSec) {
    stars = 3;
  } else if (safeElapsed <= Math.round(job.parTimeSec * 1.5)) {
    stars = 2;
  }

  const careerMult = getCareerWageMultiplier(xp);
  const baseWageRp = Math.round(job.baseWageRp * careerMult);
  const speedBonusRp =
    stars === 3
      ? Math.round(baseWageRp * 0.35)
      : stars === 2
        ? Math.round(baseWageRp * 0.15)
        : 0;

  const { tipMultiplier } = getToolStats(upgrades);
  const rawTip = Math.round(baseWageRp * (stars === 3 ? 0.2 : stars === 2 ? 0.1 : 0.05));
  const tipRp = Math.round(rawTip * tipMultiplier);
  const totalRp = baseWageRp + speedBonusRp + tipRp;

  return { stars, baseWageRp, speedBonusRp, tipRp, totalRp };
}

export function purchaseUpgrade(
  state: GameState,
  upgradeId: UpgradeId,
): { purchased: boolean; state: GameState } {
  const spec = UPGRADES.find((u) => u.id === upgradeId);
  if (!spec) return { purchased: false, state };
  if (state.upgrades.includes(upgradeId)) return { purchased: false, state };
  if (state.balanceRp < spec.costRp) return { purchased: false, state };

  return {
    purchased: true,
    state: {
      ...state,
      balanceRp: state.balanceRp - spec.costRp,
      upgrades: [...state.upgrades, upgradeId],
    },
  };
}

export function applyJobResult(
  state: GameState,
  input: JobCompletionInput,
): { entry: CashbookEntry; state: GameState; xpGained: number; streakBonusRp: number } {
  const job = input.jobOverride ?? getJobById(input.jobId);
  if (!job) {
    throw new Error(`Unknown job id: ${input.jobId}`);
  }

  const isDaily = Boolean(job.isDaily && job.dailyDateKey);
  const alreadyCompletedToday =
    isDaily && job.dailyDateKey ? state.dailyCompletedDates.includes(job.dailyDateKey) : false;

  const effectiveJob: JobSpec = alreadyCompletedToday
    ? { ...job, baseWageRp: Math.round(job.baseWageRp / 1.5) }
    : job;

  const payout = calculateJobPayout(effectiveJob, input.elapsedSec, state.upgrades, state.xp);
  let streakBonusRp = 0;
  let nextDailyDates = state.dailyCompletedDates;
  let nextStreak = state.dailyStreak;

  if (isDaily && job.dailyDateKey && !alreadyCompletedToday) {
    nextDailyDates = [...state.dailyCompletedDates, job.dailyDateKey].slice(-60);
    nextStreak = state.dailyStreak + 1;
    if (nextStreak % 7 === 0) {
      streakBonusRp = 50000;
    }
  }

  const totalWithStreak = payout.totalRp + streakBonusRp;
  const xpGained = 50 + payout.stars * 25 + (isDaily && !alreadyCompletedToday ? 40 : 0);

  const entry: CashbookEntry = {
    jobId: job.id,
    day: state.day,
    stars: payout.stars,
    baseWageRp: payout.baseWageRp,
    speedBonusRp: payout.speedBonusRp,
    tipRp: payout.tipRp + streakBonusRp,
    totalRp: totalWithStreak,
    elapsedSec: Math.max(1, Math.round(input.elapsedSec)),
  };

  const prevBest = state.bestStars[job.id] ?? 0;
  const nextBest = Math.max(prevBest, payout.stars) as 1 | 2 | 3;
  const maxLevel = JOBS.length;
  const nextUnlocked = isDaily
    ? state.unlockedLevel
    : Math.min(maxLevel, Math.max(state.unlockedLevel, job.level + 1));

  return {
    entry,
    xpGained,
    streakBonusRp,
    state: {
      ...state,
      day: state.day + 1,
      balanceRp: state.balanceRp + totalWithStreak,
      unlockedLevel: nextUnlocked,
      bestStars: isDaily
        ? state.bestStars
        : {
            ...state.bestStars,
            [job.id]: nextBest,
          },
      cashbook: [entry, ...state.cashbook].slice(0, 50),
      xp: state.xp + xpGained,
      dailyCompletedDates: nextDailyDates,
      dailyStreak: nextStreak,
    },
  };
}
