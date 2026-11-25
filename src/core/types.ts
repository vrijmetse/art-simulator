export type Locale = 'id' | 'en';

export type UpgradeId =
  | 'wide_sponge'
  | 'citrus_cleaner'
  | 'quick_gloves'
  | 'neat_uniform'
  | 'sparkle_radar';

export type StainKind = 'dust' | 'spill' | 'grease' | 'crayon' | 'mud';

export type ClutterKind =
  | 'book'
  | 'headphones'
  | 'slippers'
  | 'remote'
  | 'teacup'
  | 'photo'
  | 'pan'
  | 'spice'
  | 'ladle'
  | 'backpack'
  | 'toy'
  | 'trophy'
  | 'suitcase'
  | 'sunglasses'
  | 'towel'
  | 'chalice'
  | 'scroll'
  | 'crown';

export interface LocalizedText {
  id: string;
  en: string;
}

export interface StainSpotSpec {
  id: string;
  kind: StainKind;
  x: number; // Top-left X in 450x800 playfield
  y: number; // Top-left Y in 450x800 playfield
  width: number;
  height: number;
  pos3D?: [number, number, number];
  size3D?: [number, number];
}

export interface ClutterItemSpec {
  id: string;
  kind: ClutterKind;
  label: LocalizedText;
  startX: number; // Center X in 450x800
  startY: number; // Center Y in 450x800
  targetX: number; // Target center X
  targetY: number; // Target center Y
  size: number; // Visual bounding box size (px)
  modelName?: string; // CC0 GLB filename under /models/
  pos3D?: [number, number, number];
  targetPos3D?: [number, number, number];
  rotY3D?: number;
  scale3D?: number;
  note: LocalizedText;
}

export interface FurniturePropSpec {
  modelName: string; // CC0 GLB filename under /models/
  pos3D: [number, number, number];
  rotY3D?: number;
  scale3D?: number;
}

export interface RoomPalette {
  wall: string;
  floor: string;
  accent: string;
  trim: string;
}

export interface JobSpec {
  id: string;
  level: number;
  title: LocalizedText;
  clientName: string;
  briefing: LocalizedText;
  storyNote: LocalizedText;
  baseWageRp: number;
  parTimeSec: number;
  palette: RoomPalette;
  furnitureLayout?: FurniturePropSpec[];
  stains: StainSpotSpec[];
  clutter: ClutterItemSpec[];
}

export interface UpgradeSpec {
  id: UpgradeId;
  costRp: number;
  name: LocalizedText;
  description: LocalizedText;
}

export interface ToolStats {
  brushRadius: number;
  brushRadius3D: number;
  scrubPower: number;
  snapRadius: number;
  snapRadius3D: number;
  tipMultiplier: number;
  hasRadar: boolean;
}

export interface CashbookEntry {
  jobId: string;
  day: number;
  stars: 1 | 2 | 3;
  baseWageRp: number;
  speedBonusRp: number;
  tipRp: number;
  totalRp: number;
  elapsedSec: number;
}

export interface JobCompletionInput {
  jobId: string;
  elapsedSec: number;
}

export interface GameState {
  version: number;
  locale: Locale;
  muted: boolean;
  day: number;
  balanceRp: number;
  unlockedLevel: number;
  bestStars: Record<string, 1 | 2 | 3>;
  upgrades: UpgradeId[];
  cashbook: CashbookEntry[];
}
