import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { createInitialState } from '../../src/core/economy';
import {
  NEIGHBORS,
  claimNpcChatReward,
  createNpcPatrols,
  getNeighborForJob,
  stepNpcPatrol,
} from '../../src/core/neighborhood';

describe('neighborhood & family/pet NPCs (TDD)', () => {
  it('includes kids, spouses, and pets with smooth CC0 GLBs on disk, portrait palette, and job links', () => {
    const kinds = new Set(NEIGHBORS.map((n) => n.kind));
    expect(kinds.has('kid')).toBe(true);
    expect(kinds.has('spouse')).toBe(true);
    expect(kinds.has('pet')).toBe(true);
    for (const n of NEIGHBORS) {
      expect(n.modelPath.endsWith('.glb')).toBe(true);
      expect(n.modelPath.includes('character-')).toBe(false);
      expect(n.modelPath.includes('animal-dog')).toBe(false);
      expect(n.portrait.skin).toMatch(/^#[0-9a-fA-F]{6}$/);
      expect(n.portrait.accent).toMatch(/^#[0-9a-fA-F]{6}$/);
      const fullPath = path.resolve(__dirname, '../../public/models', n.modelPath);
      expect(fs.existsSync(fullPath)).toBe(true);
    }
    const kid = NEIGHBORS.find((n) => n.kind === 'kid')!;
    const spouse = NEIGHBORS.find((n) => n.kind === 'spouse')!;
    expect(kid.scale3D).toBeLessThan(spouse.scale3D);
    expect(getNeighborForJob('kos-rina').kind).toBe('pet');
    expect(getNeighborForJob('dapur-sari').kind).toBe('spouse');
  });

  it('awards daily NPC chat tip once per NPC per dateKey and blocks unknown NPCs', () => {
    const state = createInitialState();
    const npc = NEIGHBORS[0];
    const r1 = claimNpcChatReward(state, npc.id, '2026-11-25');
    expect(r1.claimed).toBe(true);
    expect(r1.tipRp).toBe(npc.tipRp);
    expect(r1.state.balanceRp).toBe(state.balanceRp + npc.tipRp);
    expect(r1.state.xp).toBe(state.xp + 10);
    expect(r1.state.npcChattedDates[npc.id]).toBe('2026-11-25');

    const r2 = claimNpcChatReward(r1.state, npc.id, '2026-11-25');
    expect(r2.claimed).toBe(false);
    expect(r2.tipRp).toBe(0);

    const r3 = claimNpcChatReward(r1.state, npc.id, '2026-11-26');
    expect(r3.claimed).toBe(true);

    const bad = claimNpcChatReward(state, 'ghost-npc', '2026-11-25');
    expect(bad.claimed).toBe(false);
  });

  it('patrols NPCs deterministically along sidewalk without spawning clumped together', () => {
    const patrols = createNpcPatrols();
    expect(patrols.length).toBe(5);
    const sortedX = patrols.map((n) => n.x).sort((a, b) => a - b);
    for (let i = 1; i < sortedX.length; i++) {
      expect(sortedX[i] - sortedX[i - 1]).toBeGreaterThanOrEqual(0.8);
    }
    let p = patrols[0];
    const startX = p.x;
    for (let i = 0; i < 40; i++) {
      p = stepNpcPatrol(p, 0.05);
      expect(p.x).toBeGreaterThanOrEqual(-2.5);
      expect(p.x).toBeLessThanOrEqual(2.5);
    }
    expect(p.x).not.toBe(startX);

    const talking = { ...p, talking: true };
    expect(stepNpcPatrol(talking, 0.05).x).toBe(talking.x);
  });
});
