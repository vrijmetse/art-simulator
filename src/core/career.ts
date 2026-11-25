import type { CareerRank } from './types';

export const CAREER_RANKS: CareerRank[] = [
  {
    id: 'magang',
    minXp: 0,
    title: { id: 'ART Magang', en: 'Trainee Keeper' },
    wageBonusPct: 0,
  },
  {
    id: 'terampil',
    minXp: 150,
    title: { id: 'ART Terampil', en: 'Skilled Keeper' },
    wageBonusPct: 5,
  },
  {
    id: 'andalan',
    minXp: 400,
    title: { id: 'ART Andalan', en: 'Trusted Keeper' },
    wageBonusPct: 10,
  },
  {
    id: 'manajer',
    minXp: 800,
    title: { id: 'Manajer Rumah', en: 'Estate Steward' },
    wageBonusPct: 15,
  },
  {
    id: 'kepala',
    minXp: 1400,
    title: { id: 'Kepala Tata Graha', en: 'Grand Steward' },
    wageBonusPct: 25,
  },
];

export function getCareerRank(xp: number): CareerRank {
  const safeXp = Math.max(0, xp);
  let active = CAREER_RANKS[0];
  for (const r of CAREER_RANKS) {
    if (safeXp >= r.minXp) active = r;
  }
  return active;
}

export function getNextCareerRank(xp: number): CareerRank | null {
  const safeXp = Math.max(0, xp);
  return CAREER_RANKS.find((r) => r.minXp > safeXp) ?? null;
}

export function getCareerWageMultiplier(xp: number): number {
  return 1 + getCareerRank(xp).wageBonusPct / 100;
}
