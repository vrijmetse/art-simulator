export type ContextFactory = () => AudioContext | null;

function defaultContextFactory(): AudioContext | null {
  try {
    const g = globalThis as unknown as {
      AudioContext?: new () => AudioContext;
      webkitAudioContext?: new () => AudioContext;
    };
    const Ctor = g.AudioContext || g.webkitAudioContext;
    return Ctor ? new Ctor() : null;
  } catch {
    return null;
  }
}

export class AsmrSynth {
  private ctx: AudioContext | null = null;
  private readonly factory: ContextFactory;
  private _muted = false;
  private lastScrubAt = 0;

  constructor(factory: ContextFactory = defaultContextFactory) {
    this.factory = factory;
  }

  get muted(): boolean {
    return this._muted;
  }

  setMuted(muted: boolean): void {
    this._muted = muted;
  }

  private ensureContext(): AudioContext | null {
    if (!this.ctx) {
      this.ctx = this.factory();
    }
    return this.ctx;
  }

  /**
   * Must be called synchronously inside a pointerdown/user gesture handler
   * so iOS Safari and mobile Chrome unlock & resume audio cleanly.
   */
  unlock(): void {
    const ctx = this.ensureContext();
    if (!ctx) return;
    if (ctx.state !== 'running' && typeof ctx.resume === 'function') {
      void ctx.resume().catch(() => {});
    }
  }

  playScrub(): void {
    if (this._muted) return;
    const nowMs = Date.now();
    if (nowMs - this.lastScrubAt < 75) return;
    this.lastScrubAt = nowMs;

    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const dur = 0.055;
      const sampleCount = Math.floor(ctx.sampleRate * dur);
      const buffer = ctx.createBuffer(1, sampleCount, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < sampleCount; i++) {
        data[i] = (Math.random() * 2 - 1) * (1 - i / sampleCount) * 0.35;
      }

      const src = ctx.createBufferSource();
      src.buffer = buffer;

      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.value = 1600 + Math.random() * 600;
      filter.Q.value = 1.4;

      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.08, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + dur);

      src.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
      src.start();
    } catch {
      // Ignore Web Audio errors on suspended/unsupported browsers
    }
  }

  playPop(): void {
    this.playTone(540, 880, 0.09, 0.12, 'sine');
  }

  playSnap(): void {
    this.playTone(440, 660, 0.11, 0.14, 'triangle');
  }

  playCash(): void {
    this.playTone(784, 1175, 0.18, 0.14, 'sine');
    setTimeout(() => this.playTone(1046, 1568, 0.22, 0.12, 'sine'), 90);
  }

  private playTone(
    freqStart: number,
    freqEnd: number,
    durationSec: number,
    volume: number,
    type: OscillatorType,
  ): void {
    if (this._muted) return;
    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freqStart, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(freqEnd, ctx.currentTime + durationSec);

      gain.gain.setValueAtTime(volume, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationSec);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + durationSec + 0.01);
    } catch {
      // Ignore Web Audio errors
    }
  }
}

export const asmrSynth = new AsmrSynth();
