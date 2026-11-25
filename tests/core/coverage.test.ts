import { describe, it, expect } from 'vitest';
import { CoverageGrid } from '../../src/core/coverage';

describe('CoverageGrid', () => {
  it('starts at 0% coverage and not complete', () => {
    const grid = new CoverageGrid(120, 120, 12);
    expect(grid.ratio).toBe(0);
    expect(grid.isComplete).toBe(false);
  });

  it('interpolates fast swipes between prev and current coordinates without gaps', () => {
    const grid = new CoverageGrid(120, 40, 12);
    // Swipe all the way across horizontally in one pointer jump
    grid.scrubSegment(10, 20, 110, 20, 18);
    expect(grid.ratio).toBeGreaterThan(0.7);
  });

  it('auto-completes once threshold (>= 85%) is reached', () => {
    const grid = new CoverageGrid(100, 100, 10);
    for (let y = 10; y <= 90; y += 20) {
      grid.scrubSegment(10, y, 90, y, 16);
    }
    expect(grid.ratio).toBeGreaterThanOrEqual(0.85);
    expect(grid.isComplete).toBe(true);
  });

  it('handles out-of-bounds coordinates safely without throwing', () => {
    const grid = new CoverageGrid(100, 100, 10);
    expect(() => grid.scrubSegment(-200, -200, 300, 300, 10)).not.toThrow();
    expect(grid.ratio).toBeGreaterThan(0);
    expect(grid.ratio).toBeLessThanOrEqual(1);
  });

  it('markComplete forces 100% coverage cleanly', () => {
    const grid = new CoverageGrid(100, 100, 10);
    grid.markComplete();
    expect(grid.ratio).toBe(1);
    expect(grid.isComplete).toBe(true);
  });
});
