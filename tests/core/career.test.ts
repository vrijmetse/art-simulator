import { describe, it, expect } from 'vitest';
import { getCareerRank, getCareerWageMultiplier, getNextCareerRank } from '../../src/core/career';

describe('career rank progression', () => {
  it('starts at Magang with 0 XP and scales through 5 ranks', () => {
    expect(getCareerRank(0).id).toBe('magang');
    expect(getCareerWageMultiplier(0)).toBe(1.0);

    expect(getCareerRank(150).id).toBe('terampil');
    expect(getCareerWageMultiplier(150)).toBeCloseTo(1.05);

    expect(getCareerRank(400).id).toBe('andalan');
    expect(getCareerWageMultiplier(400)).toBeCloseTo(1.1);

    expect(getCareerRank(800).id).toBe('manajer');
    expect(getCareerWageMultiplier(800)).toBeCloseTo(1.15);

    expect(getCareerRank(1400).id).toBe('kepala');
    expect(getCareerWageMultiplier(1400)).toBeCloseTo(1.25);
  });

  it('returns next rank until max rank reached', () => {
    expect(getNextCareerRank(0)?.id).toBe('terampil');
    expect(getNextCareerRank(1400)).toBeNull();
  });
});
