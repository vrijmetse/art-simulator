import type { GameState, LocalizedText } from './types';

export type NeighborKind = 'kid' | 'spouse' | 'pet';

export interface NeighborSpec {
  id: string;
  kind: NeighborKind;
  name: LocalizedText;
  role: LocalizedText;
  /** Relative path under /models/ */
  modelPath: string;
  scale3D: number;
  jobId: string;
  greeting: LocalizedText;
  tipRp: number;
  laneZ: number;
  startX: number;
  speed: number;
}

export interface NpcPatrolState {
  spec: NeighborSpec;
  x: number;
  z: number;
  dir: 1 | -1;
  rotY: number;
  talking: boolean;
}

export const NEIGHBORS: NeighborSpec[] = [
  {
    id: 'mochi_cat',
    kind: 'pet',
    name: { id: 'Mochi (Kucing)', en: 'Mochi (Cat)' },
    role: { id: 'Kucing Pemilik Kos', en: 'Owner’s Pet Cat' },
    modelPath: 'pets/animal-cat.glb',
    scale3D: 0.34,
    jobId: 'kos-rina',
    greeting: {
      id: 'Meong~! 🐾 Mochi paling betah kalau lantai kos bersih dan harum!',
      en: 'Meow~! 🐾 Mochi loves napping when the studio floor smells fresh!',
    },
    tipRp: 3500,
    laneZ: 0.7,
    startX: -1.7,
    speed: 0.62,
  },
  {
    id: 'adik_bima',
    kind: 'kid',
    name: { id: 'Adik Bima', en: 'Little Bima' },
    role: { id: 'Anak Pemilik Rumah', en: 'Homeowner’s Kid' },
    modelPath: 'characters/character-male-a.glb',
    scale3D: 0.88,
    jobId: 'rumah-pak-budi',
    greeting: {
      id: 'Kakak ART! Makasih udah rapihin mainanku ya! Ini tabungan koin buat Kakak!',
      en: 'Hi Helper! Thanks for finding my toys! Here is a small coin treat!',
    },
    tipRp: 4500,
    laneZ: 1.0,
    startX: 0.4,
    speed: 0.68,
  },
  {
    id: 'ibu_sari',
    kind: 'spouse',
    name: { id: 'Ibu Sari', en: 'Mrs. Sari' },
    role: { id: 'Istri / Pemilik Rumah', en: 'Wife / Homemaker' },
    modelPath: 'characters/character-female-b.glb',
    scale3D: 1.28,
    jobId: 'dapur-sari',
    greeting: {
      id: 'Alhamdulillah dapur dan ruang tamu selalu kinclong. Ini uang makan siang ya!',
      en: 'The kitchen and living room sparkle thanks to you! Take this lunch tip!',
    },
    tipRp: 5500,
    laneZ: 1.3,
    startX: 1.5,
    speed: 0.46,
  },
  {
    id: 'pak_budi',
    kind: 'spouse',
    name: { id: 'Pak Budi', en: 'Mr. Budi' },
    role: { id: 'Suami / Kepala Keluarga', en: 'Husband / Dad' },
    modelPath: 'characters/character-worker.glb',
    scale3D: 1.28,
    jobId: 'rumah-pak-budi',
    greeting: {
      id: 'Istriku senang sekali rumah rapi sebelum kami pulang kerja. Ini bonus kopi!',
      en: 'My wife loves coming home to a spotless house. Have a coffee bonus!',
    },
    tipRp: 6000,
    laneZ: 0.85,
    startX: -0.5,
    speed: 0.48,
  },
  {
    id: 'bruno_dog',
    kind: 'pet',
    name: { id: 'Bruno (Anjing)', en: 'Bruno (Dog)' },
    role: { id: 'Anjing Penjaga Villa', en: 'Villa Pet Dog' },
    modelPath: 'pets/animal-dog.glb',
    scale3D: 0.36,
    jobId: 'villa-senja',
    greeting: {
      id: 'Guk-guk! 🦴 Bruno senang diajak main di teras yang bersih!',
      en: 'Woof! 🦴 Bruno loves playing on a clean patio!',
    },
    tipRp: 7000,
    laneZ: 1.45,
    startX: -1.1,
    speed: 0.58,
  },
];

export function getNeighborForJob(jobId: string): NeighborSpec {
  return NEIGHBORS.find((n) => n.jobId === jobId) ?? NEIGHBORS[0];
}

export function createNpcPatrols(): NpcPatrolState[] {
  return NEIGHBORS.map((spec, idx) => {
    const dir: 1 | -1 = idx % 2 === 0 ? 1 : -1;
    return {
      spec,
      x: spec.startX,
      z: spec.laneZ,
      dir,
      rotY: dir > 0 ? Math.PI / 2 : -Math.PI / 2,
      talking: false,
    };
  });
}

export function stepNpcPatrol(npc: NpcPatrolState, dtSec: number): NpcPatrolState {
  if (npc.talking) return npc;
  const dt = Math.min(0.05, Math.max(0, dtSec));
  let x = npc.x + npc.dir * npc.spec.speed * dt;
  let dir = npc.dir;
  if (x >= 2.4) {
    x = 2.4;
    dir = -1;
  } else if (x <= -2.4) {
    x = -2.4;
    dir = 1;
  }
  return {
    ...npc,
    x,
    dir,
    rotY: dir > 0 ? Math.PI / 2 : -Math.PI / 2,
  };
}

export function canClaimNpcChat(state: GameState, npcId: string, dateKey: string): boolean {
  const npc = NEIGHBORS.find((n) => n.id === npcId);
  if (!npc) return false;
  return state.npcChattedDates[npcId] !== dateKey;
}

export function claimNpcChatReward(
  state: GameState,
  npcId: string,
  dateKey: string,
): { claimed: boolean; tipRp: number; state: GameState } {
  const npc = NEIGHBORS.find((n) => n.id === npcId);
  if (!npc || state.npcChattedDates[npcId] === dateKey) {
    return { claimed: false, tipRp: 0, state };
  }
  return {
    claimed: true,
    tipRp: npc.tipRp,
    state: {
      ...state,
      balanceRp: state.balanceRp + npc.tipRp,
      xp: state.xp + 10,
      npcChattedDates: {
        ...state.npcChattedDates,
        [npcId]: dateKey,
      },
    },
  };
}
