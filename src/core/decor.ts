import type { DecorId, DecorSpec, FurniturePropSpec, GameState } from './types';

export const DECOR_ITEMS: DecorSpec[] = [
  {
    id: 'plant_monstera',
    costRp: 30000,
    name: { id: 'Tanaman Pojok Segar', en: 'Corner Potted Plant' },
    description: { id: 'Bikin kamar kos terasa sejuk & hidup', en: 'Brings fresh green calm to your room' },
    modelName: 'pottedPlant.glb',
    pos3D: [-1.75, 0, -1.75],
    rotY3D: 0,
    scale3D: 1.65,
  },
  {
    id: 'cozy_rug',
    costRp: 45000,
    name: { id: 'Karpet Hangat', en: 'Cozy Woven Rug' },
    description: { id: 'Karpet empuk di tengah kamar kos', en: 'Warm woven rug at the center of your room' },
    modelName: 'rugRounded.glb',
    pos3D: [0.1, 0.002, 0.35],
    rotY3D: 0,
    scale3D: 1.45,
  },
  {
    id: 'table_lamp',
    costRp: 50000,
    name: { id: 'Lampu Meja Temaram', en: 'Warm Desk Lamp' },
    description: { id: 'Cahaya kuning lembut saat istirahat malam', en: 'Soft golden light for cozy evenings' },
    modelName: 'lampRoundTable.glb',
    pos3D: [1.35, 0.60, -1.55],
    rotY3D: 0,
    scale3D: 1.25,
  },
  {
    id: 'plush_bear',
    costRp: 60000,
    name: { id: 'Boneka Kenangan', en: 'Keepsake Plush Bear' },
    description: { id: 'Hadiah manis di atas ranjang kosmu', en: 'Sweet plush friend sitting on your bed' },
    modelName: 'bear.glb',
    pos3D: [-1.2, 0.34, -0.85],
    rotY3D: 0.3,
    scale3D: 1.45,
  },
  {
    id: 'vintage_radio',
    costRp: 85000,
    name: { id: 'Radio Pagi Syahdu', en: 'Morning Lo-Fi Radio' },
    description: { id: 'Menemani sarapan sebelum shift pagi', en: 'Plays warm tunes before morning shifts' },
    modelName: 'radio.glb',
    pos3D: [0.9, 0.60, -1.45],
    rotY3D: 0,
    scale3D: 1.1,
  },
  {
    id: 'book_shelf',
    costRp: 110000,
    name: { id: 'Rak Buku Kayu', en: 'Wooden Bookcase' },
    description: { id: 'Tempat menyimpan piagam & buku favorit', en: 'Displays your certificates & favorite reads' },
    modelName: 'bookcaseOpenLow.glb',
    pos3D: [-1.72, 0, 1.0],
    rotY3D: Math.PI / 2,
    scale3D: 1.4,
  },
  {
    id: 'lounge_chair',
    costRp: 150000,
    name: { id: 'Kursi Santai Empuk', en: 'Lounge Armchair' },
    description: { id: 'Kursi baca nyaman sepulang kerja', en: 'Plush reading chair after a busy day' },
    modelName: 'loungeChair.glb',
    pos3D: [1.35, 0, 1.05],
    rotY3D: -Math.PI * 0.75,
    scale3D: 1.45,
  },
  {
    id: 'retro_tv',
    costRp: 220000,
    name: { id: 'TV Retro Ruang Kos', en: 'Retro Room TV' },
    description: { id: 'Nonton sore santai di akhir pekan', en: 'Cozy evening entertainment in your kos' },
    modelName: 'televisionVintage.glb',
    pos3D: [-1.72, 0.565, 1.0],
    rotY3D: Math.PI / 2,
    scale3D: 1.25,
  },
];

export const BASE_KOS_FURNITURE: FurniturePropSpec[] = [
  { modelName: 'bedSingle.glb', pos3D: [-1.2, 0, -1.0], rotY3D: 0, scale3D: 1.0 },
  { modelName: 'desk.glb', pos3D: [1.05, 0, -1.5], rotY3D: 0, scale3D: 1.55 },
  { modelName: 'chairDesk.glb', pos3D: [1.05, 0, -0.78], rotY3D: Math.PI, scale3D: 1.45 },
];

export function purchaseDecor(
  state: GameState,
  decorId: DecorId,
): { purchased: boolean; state: GameState } {
  const spec = DECOR_ITEMS.find((d) => d.id === decorId);
  if (!spec) return { purchased: false, state };
  if (state.ownedDecor.includes(decorId)) return { purchased: false, state };
  if (state.balanceRp < spec.costRp) return { purchased: false, state };

  return {
    purchased: true,
    state: {
      ...state,
      balanceRp: state.balanceRp - spec.costRp,
      ownedDecor: [...state.ownedDecor, decorId],
      placedDecor: state.placedDecor.includes(decorId)
        ? state.placedDecor
        : [...state.placedDecor, decorId],
    },
  };
}

export function toggleDecorPlacement(state: GameState, decorId: DecorId): GameState {
  if (!state.ownedDecor.includes(decorId)) return state;
  const exists = state.placedDecor.includes(decorId);
  return {
    ...state,
    placedDecor: exists
      ? state.placedDecor.filter((id) => id !== decorId)
      : [...state.placedDecor, decorId],
  };
}

export function buildPersonalKosFurniture(placedDecor: readonly DecorId[]): FurniturePropSpec[] {
  const extras: FurniturePropSpec[] = [];
  for (const id of placedDecor) {
    const spec = DECOR_ITEMS.find((d) => d.id === id);
    if (!spec) continue;
    // Retro TV rests on floor/table if bookcase isn't placed yet
    const y = spec.id === 'retro_tv' && !placedDecor.includes('book_shelf') ? 0 : spec.pos3D[1];
    extras.push({
      modelName: spec.modelName,
      pos3D: [spec.pos3D[0], y, spec.pos3D[2]],
      rotY3D: spec.rotY3D,
      scale3D: spec.scale3D,
    });
  }
  return [...BASE_KOS_FURNITURE, ...extras];
}
