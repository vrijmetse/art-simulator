import { describe, it, expect } from 'vitest';
import {
  UPGRADES,
  createInitialState,
  getToolStats,
  calculateJobPayout,
  purchaseUpgrade,
  applyJobResult,
} from '../../src/core/economy';
import { JOBS } from '../../src/core/jobs';
import { formatMoney } from '../../src/core/i18n';

describe('economy & progression', () => {
  it('computes base wage, speed stars, and neat_uniform tip bonus in canonical Rp', () => {
    const job = JOBS[0]; // baseWageRp: 35000, parTimeSec: 45
    const baseState = createInitialState();

    const fast = calculateJobPayout(job, 35, baseState.upgrades);
    expect(fast.stars).toBe(3);
    expect(fast.speedBonusRp).toBeGreaterThan(0);
    expect(fast.totalRp).toBe(fast.baseWageRp + fast.speedBonusRp + fast.tipRp);

    const medium = calculateJobPayout(job, 60, baseState.upgrades);
    expect(medium.stars).toBe(2);
    expect(medium.speedBonusRp).toBeGreaterThan(0);
    expect(medium.speedBonusRp).toBeLessThan(fast.speedBonusRp);

    const slow = calculateJobPayout(job, 120, baseState.upgrades);
    expect(slow.stars).toBe(1);
    expect(slow.speedBonusRp).toBe(0);

    const tipped = calculateJobPayout(job, 35, ['neat_uniform']);
    expect(tipped.tipRp).toBeGreaterThan(fast.tipRp);
  });

  it('prevents purchase if insufficient funds or already owned and never drops balance below 0', () => {
    const state = createInitialState();
    const poorRes = purchaseUpgrade(state, 'wide_sponge');
    expect(poorRes.purchased).toBe(false);
    expect(poorRes.state.balanceRp).toBe(0);
    expect(poorRes.state.upgrades).toEqual([]);

    const rich = { ...state, balanceRp: 100000 };
    const bought = purchaseUpgrade(rich, 'wide_sponge');
    expect(bought.purchased).toBe(true);
    expect(bought.state.upgrades).toContain('wide_sponge');
    expect(bought.state.balanceRp).toBe(100000 - UPGRADES.find((u) => u.id === 'wide_sponge')!.costRp);

    const dup = purchaseUpgrade(bought.state, 'wide_sponge');
    expect(dup.purchased).toBe(false);
    expect(dup.state.balanceRp).toBe(bought.state.balanceRp);
  });

  it('preserves canonical balanceRp and upgrade affordability across mid-save ID <-> EN locale switches', () => {
    let state: ReturnType<typeof createInitialState> = {
      ...createInitialState(),
      locale: 'id',
      balanceRp: 45000,
    };
    expect(formatMoney(state.balanceRp, state.locale)).toBe('Rp 45.000');

    // Switch to EN mid-save
    state = { ...state, locale: 'en' };
    expect(state.balanceRp).toBe(45000);
    expect(formatMoney(state.balanceRp, state.locale)).toBe('$45');

    const res = purchaseUpgrade(state, 'wide_sponge');
    expect(res.purchased).toBe(true);
    // Switch back to ID — balance stays canonical
    const backToId = { ...res.state, locale: 'id' as const };
    expect(backToId.balanceRp).toBe(res.state.balanceRp);
  });

  it('allows full 5-house playthrough with positive progression and tool stat scaling', () => {
    let state = createInitialState();
    expect(getToolStats(state.upgrades).hasRadar).toBe(false);

    for (const job of JOBS) {
      expect(job.level).toBeLessThanOrEqual(state.unlockedLevel);
      const result = applyJobResult(state, { jobId: job.id, elapsedSec: job.parTimeSec });
      state = result.state;
    }

    expect(state.unlockedLevel).toBe(5);
    expect(state.cashbook.length).toBe(5);
    expect(state.balanceRp).toBeGreaterThan(UPGRADES.reduce((acc, u) => acc + u.costRp, 0));

    for (const up of UPGRADES) {
      const res = purchaseUpgrade(state, up.id);
      expect(res.purchased).toBe(true);
      state = res.state;
    }

    const stats = getToolStats(state.upgrades);
    expect(stats.brushRadius).toBeGreaterThan(24);
    expect(stats.brushRadius3D).toBeGreaterThan(17);
    expect(stats.snapRadius).toBeGreaterThan(42);
    expect(stats.snapRadius3D).toBeGreaterThan(0.55);
    expect(stats.hasRadar).toBe(true);
  });
});
