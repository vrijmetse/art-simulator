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
  note: LocalizedText;
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
  scrubPower: number;
  snapRadius: number;
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
