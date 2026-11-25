import type { CashbookEntry, GameState, UpgradeId } from './types';
import { createInitialState, UPGRADES } from './economy';
import { JOBS } from './jobs';

export const SAVE_KEY = 'art_simulator_save_v1';
export const SAVE_VERSION = 1;

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

const VALID_UPGRADE_IDS = new Set<string>(UPGRADES.map((u) => u.id));
const VALID_JOB_IDS = new Set<string>(JOBS.map((j) => j.id));

function getDefaultStorage(): StorageLike | null {
  try {
    if (typeof globalThis !== 'undefined' && 'localStorage' in globalThis && globalThis.localStorage) {
      return globalThis.localStorage;
    }
  } catch {
    // Private browsing or disabled storage
  }
  return null;
}

export function migrateSave(raw: unknown): GameState {
  const base = createInitialState();
  if (!raw || typeof raw !== 'object') return base;
  const obj = raw as Record<string, unknown>;

  const locale = obj.locale === 'en' ? 'en' : 'id';
  const muted = obj.muted === true;
  const day = typeof obj.day === 'number' && Number.isFinite(obj.day) && obj.day >= 1
    ? Math.floor(obj.day)
    : 1;
  const balanceRp = typeof obj.balanceRp === 'number' && Number.isFinite(obj.balanceRp) && obj.balanceRp >= 0
    ? Math.round(obj.balanceRp)
    : 0;
  const unlockedLevel = typeof obj.unlockedLevel === 'number' && Number.isFinite(obj.unlockedLevel)
    ? Math.min(JOBS.length, Math.max(1, Math.floor(obj.unlockedLevel)))
    : 1;

  const upgrades: UpgradeId[] = [];
  if (Array.isArray(obj.upgrades)) {
    for (const u of obj.upgrades) {
      if (typeof u === 'string' && VALID_UPGRADE_IDS.has(u) && !upgrades.includes(u as UpgradeId)) {
        upgrades.push(u as UpgradeId);
      }
    }
  }

  const bestStars: Record<string, 1 | 2 | 3> = {};
  if (obj.bestStars && typeof obj.bestStars === 'object') {
    for (const [jobId, stars] of Object.entries(obj.bestStars as Record<string, unknown>)) {
      if (VALID_JOB_IDS.has(jobId) && (stars === 1 || stars === 2 || stars === 3)) {
        bestStars[jobId] = stars;
      }
    }
  }

  const cashbook: CashbookEntry[] = [];
  if (Array.isArray(obj.cashbook)) {
    for (const item of obj.cashbook) {
      if (
        item &&
        typeof item === 'object' &&
        typeof (item as CashbookEntry).jobId === 'string' &&
        VALID_JOB_IDS.has((item as CashbookEntry).jobId) &&
        typeof (item as CashbookEntry).totalRp === 'number' &&
        (item as CashbookEntry).totalRp >= 0
      ) {
        const e = item as CashbookEntry;
        cashbook.push({
          jobId: e.jobId,
          day: typeof e.day === 'number' && e.day >= 1 ? Math.floor(e.day) : 1,
          stars: e.stars === 1 || e.stars === 2 || e.stars === 3 ? e.stars : 1,
          baseWageRp: Math.max(0, Math.round(Number(e.baseWageRp) || 0)),
          speedBonusRp: Math.max(0, Math.round(Number(e.speedBonusRp) || 0)),
          tipRp: Math.max(0, Math.round(Number(e.tipRp) || 0)),
          totalRp: Math.max(0, Math.round(Number(e.totalRp) || 0)),
          elapsedSec: Math.max(1, Math.round(Number(e.elapsedSec) || 1)),
        });
      }
    }
  }

  return {
    version: SAVE_VERSION,
    locale,
    muted,
    day,
    balanceRp,
    unlockedLevel,
    bestStars,
    upgrades,
    cashbook: cashbook.slice(0, 50),
  };
}

export function loadState(storage: StorageLike | null = getDefaultStorage()): GameState {
  if (!storage) return createInitialState();
  try {
    const raw = storage.getItem(SAVE_KEY);
    if (!raw) return createInitialState();
    return migrateSave(JSON.parse(raw));
  } catch {
    return createInitialState();
  }
}

export function saveState(state: GameState, storage: StorageLike | null = getDefaultStorage()): void {
  if (!storage) return;
  try {
    storage.setItem(SAVE_KEY, JSON.stringify({ ...state, version: SAVE_VERSION }));
  } catch {
    // Quota exceeded or disabled storage — ignore safely
  }
}

export function resetState(storage: StorageLike | null = getDefaultStorage()): GameState {
  if (storage) {
    try {
      storage.removeItem(SAVE_KEY);
    } catch {
      // ignore
    }
  }
  return createInitialState();
}
