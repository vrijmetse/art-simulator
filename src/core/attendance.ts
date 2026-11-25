import type { GameState } from './types';

export function getTodayDateKey(now = new Date()): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function getAttendanceRewardRp(dayNum: number): number {
  const safe = ((Math.max(1, Math.floor(dayNum)) - 1) % 30) + 1;
  if (safe === 30) return 100000;
  if (safe % 5 === 0) return 40000 + Math.floor(safe / 5) * 5000;
  return 10000 + Math.floor((safe - 1) / 5) * 2000;
}

export function canClaimAttendance(state: GameState, dateKey = getTodayDateKey()): boolean {
  return state.lastAttendanceDate !== dateKey;
}

export function claimAttendance(
  state: GameState,
  dateKey = getTodayDateKey(),
): { claimed: boolean; rewardRp: number; state: GameState } {
  if (!canClaimAttendance(state, dateKey)) {
    return { claimed: false, rewardRp: 0, state };
  }

  const nextDay = (state.attendanceDay % 30) + 1;
  const rewardRp = getAttendanceRewardRp(nextDay);
  return {
    claimed: true,
    rewardRp,
    state: {
      ...state,
      balanceRp: state.balanceRp + rewardRp,
      attendanceDay: nextDay,
      lastAttendanceDate: dateKey,
    },
  };
}
