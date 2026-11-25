export type Locale = 'id' | 'en';

export type UpgradeId =
  | 'wide_sponge'
  | 'citrus_cleaner'
  | 'quick_gloves'
  | 'neat_uniform'
  | 'sparkle_radar';

export type DecorId =
  | 'plant_monstera'
  | 'table_lamp'
  | 'cozy_rug'
  | 'plush_bear'
  | 'lounge_chair'
  | 'retro_tv'
  | 'vintage_radio'
  | 'book_shelf';

export type ToolMode = 'lap' | 'pel';

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
  x: number;
  y: number;
  width: number;
  height: number;
  pos3D?: [number, number, number];
  size3D?: [number, number];
}

export interface ClutterItemSpec {
  id: string;
  kind: ClutterKind;
  label: LocalizedText;
  startX: number;
  startY: number;
  targetX: number;
  targetY: number;
  size: number;
  modelName?: string;
  pos3D?: [number, number, number];
  targetPos3D?: [number, number, number];
  rotY3D?: number;
  scale3D?: number;
  note: LocalizedText;
}

export interface FurniturePropSpec {
  modelName: string;
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
  isDaily?: boolean;
  dailyDateKey?: string;
}

export interface UpgradeSpec {
  id: UpgradeId;
  costRp: number;
  name: LocalizedText;
  description: LocalizedText;
}

export interface DecorSpec {
  id: DecorId;
  costRp: number;
  name: LocalizedText;
  description: LocalizedText;
  modelName: string;
  pos3D: [number, number, number];
  rotY3D?: number;
  scale3D?: number;
}

export interface CareerRank {
  id: string;
  minXp: number;
  title: LocalizedText;
  wageBonusPct: number;
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
  jobOverride?: JobSpec;
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
  xp: number;
  dailyCompletedDates: string[];
  dailyStreak: number;
  lastAttendanceDate: string | null;
  attendanceDay: number;
  ownedDecor: DecorId[];
  placedDecor: DecorId[];
  adFree: boolean;
}
