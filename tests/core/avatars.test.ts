import { describe, expect, it } from 'vitest';
import { AVATARS, getAvatarSpec, isValidAvatarId } from '../../src/core/avatars';

describe('avatars catalog (TDD)', () => {
  it('provides 4 selectable CC0 avatars with valid GLB paths', () => {
    expect(AVATARS.length).toBe(4);
    for (const a of AVATARS) {
      expect(a.modelName.endsWith('.glb')).toBe(true);
      expect(isValidAvatarId(a.id)).toBe(true);
    }
    expect(isValidAvatarId('invalid-avatar')).toBe(false);
    expect(getAvatarSpec('budi').modelName).toBe('character-male-a.glb');
    expect(getAvatarSpec('unknown' as never).id).toBe('sari');
  });
});
