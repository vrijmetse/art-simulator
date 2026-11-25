import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { DECOR_ITEMS, purchaseDecor, toggleDecorPlacement } from '../../src/core/decor';
import { createInitialState } from '../../src/core/economy';

describe('personal kos decor catalog', () => {
  it('references valid CC0 GLB assets for every decor item', () => {
    const modelsDir = join(process.cwd(), 'public', 'models');
    expect(DECOR_ITEMS.length).toBeGreaterThanOrEqual(6);
    for (const item of DECOR_ITEMS) {
      expect(existsSync(join(modelsDir, item.modelName))).toBe(true);
      expect(item.costRp).toBeGreaterThan(0);
    }
  });

  it('purchases decor safely, auto-places it, and allows toggling placement', () => {
    const rich = { ...createInitialState(), balanceRp: 100000 };
    const buy = purchaseDecor(rich, 'plant_monstera');
    expect(buy.purchased).toBe(true);
    expect(buy.state.ownedDecor).toContain('plant_monstera');
    expect(buy.state.placedDecor).toContain('plant_monstera');
    expect(buy.state.balanceRp).toBeLessThan(100000);

    // Toggle off and back on
    const off = toggleDecorPlacement(buy.state, 'plant_monstera');
    expect(off.placedDecor).not.toContain('plant_monstera');
    const on = toggleDecorPlacement(off, 'plant_monstera');
    expect(on.placedDecor).toContain('plant_monstera');

    // Cannot toggle unowned decor
    const unowned = toggleDecorPlacement(createInitialState(), 'retro_tv');
    expect(unowned.placedDecor).not.toContain('retro_tv');
  });
});
