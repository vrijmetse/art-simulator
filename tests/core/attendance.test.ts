import { describe, it, expect } from 'vitest';
import { canClaimAttendance, claimAttendance, getAttendanceRewardRp } from '../../src/core/attendance';
import { createInitialState } from '../../src/core/economy';

describe('30-day attendance calendar', () => {
  it('allows one claim per calendar date and advances day counter 1..30', () => {
    const s0 = createInitialState();
    expect(canClaimAttendance(s0, '2026-11-25')).toBe(true);

    const res1 = claimAttendance(s0, '2026-11-25');
    expect(res1.claimed).toBe(true);
    expect(res1.rewardRp).toBe(getAttendanceRewardRp(1));
    expect(res1.state.balanceRp).toBe(res1.rewardRp);
    expect(res1.state.attendanceDay).toBe(1);
    expect(canClaimAttendance(res1.state, '2026-11-25')).toBe(false);

    // Same-day repeat is blocked
    const dup = claimAttendance(res1.state, '2026-11-25');
    expect(dup.claimed).toBe(false);
    expect(dup.rewardRp).toBe(0);

    // Next day grants day 2
    const res2 = claimAttendance(res1.state, '2026-11-26');
    expect(res2.claimed).toBe(true);
    expect(res2.state.attendanceDay).toBe(2);
  });

  it('grants larger milestone rewards every 5th day and wraps cleanly after day 30', () => {
    expect(getAttendanceRewardRp(5)).toBeGreaterThan(getAttendanceRewardRp(1));
    expect(getAttendanceRewardRp(30)).toBeGreaterThanOrEqual(getAttendanceRewardRp(5));

    const day30State = { ...createInitialState(), attendanceDay: 30, lastAttendanceDate: '2026-11-24' };
    const wrapped = claimAttendance(day30State, '2026-11-25');
    expect(wrapped.claimed).toBe(true);
    expect(wrapped.state.attendanceDay).toBe(1);
  });
});
