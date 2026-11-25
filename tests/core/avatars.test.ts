import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { AVATARS, getAvatarSpec, isValidAvatarId } from '../../src/core/avatars';

describe('avatars catalog (TDD)', () => {
  it('provides 4 selectable human-proportion CC0 avatars with valid GLB files on disk', () => {
    expect(AVATARS.length).toBe(4);
    for (const a of AVATARS) {
      expect(a.modelName.endsWith('.glb')).toBe(true);
      expect(a.modelName.startsWith('casual-')).toBe(true);
      expect(a.scale3D).toBeGreaterThanOrEqual(0.45);
      expect(a.scale3D).toBeLessThanOrEqual(0.75);
      expect(isValidAvatarId(a.id)).toBe(true);
      const glbPath = path.resolve(__dirname, '../../public/models/characters', a.modelName);
      expect(fs.existsSync(glbPath)).toBe(true);
    }
    expect(isValidAvatarId('invalid-avatar')).toBe(false);
    expect(getAvatarSpec('budi').modelName).toBe('casual-male.glb');
    expect(getAvatarSpec('unknown' as never).id).toBe('sari');
  });
});
