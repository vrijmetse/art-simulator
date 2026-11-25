import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { STREET_SCENERY_FILES } from '../../src/core/streetAssets';

describe('street CC0 scenery assets (TDD)', () => {
  it('verifies every house, tree, bush, fence, and car GLB exists on disk under 1 MB', () => {
    expect(STREET_SCENERY_FILES.length).toBeGreaterThanOrEqual(10);
    for (const rel of STREET_SCENERY_FILES) {
      const full = path.resolve(__dirname, '../../public/models', rel);
      expect(fs.existsSync(full)).toBe(true);
      const stat = fs.statSync(full);
      expect(stat.size).toBeGreaterThan(2000);
      expect(stat.size).toBeLessThan(1024 * 1024);
    }
  });
});
