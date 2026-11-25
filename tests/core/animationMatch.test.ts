import { describe, expect, it } from 'vitest';
import { resolveClipName } from '../../src/core/animationMatch';

describe('animation clip matcher (TDD)', () => {
  it('matches Quaternius prefixed clip names and Kenney lowercase names cleanly', () => {
    const quaterniusClips = [
      'CharacterArmature|CharacterArmature|Defeat',
      'CharacterArmature|CharacterArmature|Idle',
      'CharacterArmature|CharacterArmature|PickUp',
      'CharacterArmature|CharacterArmature|Punch',
      'CharacterArmature|CharacterArmature|Victory',
      'CharacterArmature|CharacterArmature|Walk',
    ];
    expect(resolveClipName(quaterniusClips, ['Idle', 'idle'])).toBe(
      'CharacterArmature|CharacterArmature|Idle',
    );
    expect(resolveClipName(quaterniusClips, ['Walk', 'Run'])).toBe(
      'CharacterArmature|CharacterArmature|Walk',
    );
    expect(resolveClipName(quaterniusClips, ['Punch', 'Interact'])).toBe(
      'CharacterArmature|CharacterArmature|Punch',
    );
    expect(resolveClipName(quaterniusClips, ['Victory', 'EmoteYes'])).toBe(
      'CharacterArmature|CharacterArmature|Victory',
    );

    const petClips = ['Armature|Armature|Idle', 'Armature|Armature|Jump'];
    expect(resolveClipName(petClips, ['Walk', 'Jump', 'Idle'])).toBe('Armature|Armature|Jump');
    expect(resolveClipName(['idle', 'walk'], ['Idle', 'idle'])).toBe('idle');
    expect(resolveClipName([], ['Idle'])).toBeNull();
  });
});
