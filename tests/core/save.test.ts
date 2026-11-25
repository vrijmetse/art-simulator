import { describe, it, expect } from 'vitest';
import { SAVE_KEY, SAVE_VERSION, loadState, saveState, migrateSave, resetState, type StorageLike } from '../../src/core/save';
import { createInitialState } from '../../src/core/economy';

function createMemoryStorage(): StorageLike {
  const map = new Map<string, string>();
  return {
    getItem: (k) => map.get(k) ?? null,
    setItem: (k, v) => {
      map.set(k, v);
    },
    removeItem: (k) => {
      map.delete(k);
    },
  };
}

describe('save persistence', () => {
  it('saves and loads state cleanly via storage adapter', () => {
    const storage = createMemoryStorage();
    const state = {
      ...createInitialState(),
      locale: 'en' as const,
      balanceRp: 90000,
      unlockedLevel: 3,
      upgrades: ['wide_sponge' as const],
    };
    saveState(state, storage);

    const loaded = loadState(storage);
    expect(loaded.locale).toBe('en');
    expect(loaded.balanceRp).toBe(90000);
    expect(loaded.unlockedLevel).toBe(3);
    expect(loaded.upgrades).toEqual(['wide_sponge']);
    expect(loaded.version).toBe(SAVE_VERSION);
  });

  it('recovers cleanly from corrupt JSON without crashing', () => {
    const storage = createMemoryStorage();
    storage.setItem(SAVE_KEY, '{corrupt json!!!');
    const loaded = loadState(storage);
    expect(loaded.balanceRp).toBe(0);
    expect(loaded.unlockedLevel).toBe(1);
    expect(loaded.locale).toBe('id');
  });

  it('migrates legacy v0 or partial save payloads and drops invalid upgrades', () => {
    const migrated = migrateSave({
      version: 0,
      locale: 'en',
      balanceRp: -500, // negative sanitized to 0
      unlockedLevel: 99, // clamped to max 5
      upgrades: ['wide_sponge', 'hacked_tool'],
      bestStars: { 'kos-rina': 3, bogus: 99 },
    });

    expect(migrated.version).toBe(SAVE_VERSION);
    expect(migrated.locale).toBe('en');
    expect(migrated.balanceRp).toBe(0);
    expect(migrated.unlockedLevel).toBe(5);
    expect(migrated.upgrades).toEqual(['wide_sponge']);
    expect(migrated.bestStars).toEqual({ 'kos-rina': 3 });
  });

  it('resets state and clears storage cleanly', () => {
    const storage = createMemoryStorage();
    saveState({ ...createInitialState(), balanceRp: 50000 }, storage);
    const fresh = resetState(storage);
    expect(fresh.balanceRp).toBe(0);
    expect(loadState(storage).balanceRp).toBe(0);
  });
});
