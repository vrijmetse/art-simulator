import { describe, it, expect, vi } from 'vitest';
import { AsmrSynth } from '../../src/audio/asmrSynth';

describe('AsmrSynth', () => {
  it('never throws in headless/Node environments without Web Audio API', () => {
    const synth = new AsmrSynth();
    expect(synth.muted).toBe(false);
    expect(() => synth.unlock()).not.toThrow();
    expect(() => synth.playScrub()).not.toThrow();
    expect(() => synth.playPop()).not.toThrow();
    expect(() => synth.playSnap()).not.toThrow();
    expect(() => synth.playCash()).not.toThrow();
  });

  it('calls ctx.resume() synchronously on unlock when AudioContext is suspended and skips audio when muted', () => {
    const resume = vi.fn().mockResolvedValue(undefined);
    const fakeCtx = {
      state: 'suspended',
      currentTime: 0,
      sampleRate: 44100,
      destination: {},
      resume,
      createOscillator: vi.fn(),
      createGain: vi.fn(),
      createBuffer: vi.fn(),
      createBufferSource: vi.fn(),
      createBiquadFilter: vi.fn(),
    };

    const synth = new AsmrSynth(() => fakeCtx as unknown as AudioContext);
    synth.unlock();
    expect(resume).toHaveBeenCalledTimes(1);

    synth.setMuted(true);
    expect(synth.muted).toBe(true);
    synth.playPop();
    expect(fakeCtx.createOscillator).not.toHaveBeenCalled();
  });
});
