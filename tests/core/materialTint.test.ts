import { describe, expect, it } from 'vitest';
import { resolveActorMaterialColor } from '../../src/core/materialTint';

describe('character material warm tint (TDD)', () => {
  it('replaces near-black Skin and muted Shirt with warm Indonesian palette while keeping Pants/Belt', () => {
    expect(resolveActorMaterialColor('Skin', '#E07A5F', '#E6B494')).toBe('#E6B494');
    expect(resolveActorMaterialColor('Shirt', '#E07A5F', '#E6B494')).toBe('#E07A5F');
    expect(resolveActorMaterialColor('Hair', '#E07A5F', '#E6B494', '#3D2C2E')).toBe('#3D2C2E');
    expect(resolveActorMaterialColor('Pants', '#E07A5F', '#E6B494')).toBeNull();
    expect(resolveActorMaterialColor('Belt', '#E07A5F', '#E6B494')).toBeNull();
  });
});
