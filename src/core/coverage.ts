export class CoverageGrid {
  readonly width: number;
  readonly height: number;
  readonly cols: number;
  readonly rows: number;
  readonly threshold: number;
  private readonly cells: Uint8Array;
  private clearedCount = 0;
  private forcedComplete = false;

  constructor(width: number, height: number, cols = 12, threshold = 0.85) {
    this.width = Math.max(1, width);
    this.height = Math.max(1, height);
    this.cols = Math.max(2, cols);
    this.rows = Math.max(2, Math.round((this.cols * this.height) / this.width));
    this.threshold = threshold;
    this.cells = new Uint8Array(this.cols * this.rows);
  }

  get totalCells(): number {
    return this.cells.length;
  }

  get ratio(): number {
    if (this.forcedComplete) return 1;
    return this.clearedCount / this.cells.length;
  }

  get isComplete(): boolean {
    return this.forcedComplete || this.ratio >= this.threshold;
  }

  markComplete(): void {
    this.forcedComplete = true;
    this.cells.fill(1);
    this.clearedCount = this.cells.length;
  }

  scrubCircle(localX: number, localY: number, radius: number): void {
    if (this.forcedComplete) return;
    const cellW = this.width / this.cols;
    const cellH = this.height / this.rows;
    const r = Math.max(4, radius);
    const minC = Math.max(0, Math.floor((localX - r) / cellW));
    const maxC = Math.min(this.cols - 1, Math.floor((localX + r) / cellW));
    const minR = Math.max(0, Math.floor((localY - r) / cellH));
    const maxR = Math.min(this.rows - 1, Math.floor((localY + r) / cellH));
    const rSq = r * r;

    for (let row = minR; row <= maxR; row++) {
      const cy = (row + 0.5) * cellH;
      for (let col = minC; col <= maxC; col++) {
        const cx = (col + 0.5) * cellW;
        const dx = cx - localX;
        const dy = cy - localY;
        if (dx * dx + dy * dy <= rSq) {
          const idx = row * this.cols + col;
          if (this.cells[idx] === 0) {
            this.cells[idx] = 1;
            this.clearedCount++;
          }
        }
      }
    }
  }

  scrubSegment(prevX: number, prevY: number, currX: number, currY: number, radius: number): void {
    if (this.forcedComplete) return;
    const dist = Math.hypot(currX - prevX, currY - prevY);
    const step = Math.max(4, radius * 0.4);
    const steps = Math.max(1, Math.ceil(dist / step));
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      this.scrubCircle(prevX + (currX - prevX) * t, prevY + (currY - prevY) * t, radius);
    }
  }

  getUnclearedCenters(): Array<{ x: number; y: number }> {
    const out: Array<{ x: number; y: number }> = [];
    const cellW = this.width / this.cols;
    const cellH = this.height / this.rows;
    for (let row = 0; row < this.rows; row++) {
      for (let col = 0; col < this.cols; col++) {
        if (this.cells[row * this.cols + col] === 0) {
          out.push({ x: (col + 0.5) * cellW, y: (row + 0.5) * cellH });
        }
      }
    }
    return out;
  }
}
