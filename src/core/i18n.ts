import type { Locale, LocalizedText } from './types';

export const DICTIONARIES = {
  id: {
    appTitle: 'ART Simulator',
    appSubtitle: 'Rapikan Rumah & Temukan Cerita Warga',
    playBtn: 'Mulai Kerja',
    shopTab: 'Toko Alat',
    cashbookTab: 'Buku Kas',
    mapTab: 'Daftar Rumah',
    dayLabel: 'Hari',
    balanceLabel: 'Saldo',
    starsLabel: 'Bintang',
    lockedLabel: 'Terkunci',
    startJob: 'Bersihkan',
    replayJob: 'Ulangi',
    backBtn: 'Kembali',
    tidyProgress: 'Kerapian',
    scrubHint: 'Gosok noda & geser barang ke tempatnya',
    toolScrub: 'Spons & Kemoceng',
    toolDrag: 'Rapikan Barang',
    radarBtn: 'Radar Debu',
    completeTitle: 'Rumah Kinclong!',
    baseWage: 'Upah Pokok',
    speedBonus: 'Bonus Cepat',
    tipBonus: 'Tip Tuan Rumah',
    totalEarned: 'Total Diterima',
    nextHouse: 'Rumah Berikutnya',
    backToMap: 'Kembali ke Daftar',
    ownedLabel: 'Sudah Dimiliki',
    buyBtn: 'Beli',
    notEnoughFunds: 'Saldo belum cukup',
    cashbookEmpty: 'Belum ada catatan pemasukan. Selesaikan rumah pertamamu!',
    resetBtn: 'Reset Progres',
    resetConfirm: 'Tekan lagi untuk reset',
    soundOn: 'Suara: Nyala',
    soundOff: 'Suara: Mati',
    langSwitch: 'EN',
    storyHeader: 'Catatan Tuan Rumah',
    rotateBtn: 'Putar 3D',
  },
  en: {
    appTitle: 'Cozy Homekeeper',
    appSubtitle: 'Tidy Rooms & Uncover Heartwarming Stories',
    playBtn: 'Start Shift',
    shopTab: 'Tool Shop',
    cashbookTab: 'Cashbook',
    mapTab: 'Houses',
    dayLabel: 'Day',
    balanceLabel: 'Balance',
    starsLabel: 'Stars',
    lockedLabel: 'Locked',
    startJob: 'Clean Room',
    replayJob: 'Replay',
    backBtn: 'Back',
    tidyProgress: 'Tidiness',
    scrubHint: 'Scrub stains & drag items to glowing spots',
    toolScrub: 'Sponge & Duster',
    toolDrag: 'Tidy Items',
    radarBtn: 'Dust Radar',
    completeTitle: 'Spotless Room!',
    baseWage: 'Base Wage',
    speedBonus: 'Speed Bonus',
    tipBonus: 'Host Tip',
    totalEarned: 'Total Earned',
    nextHouse: 'Next House',
    backToMap: 'Back to Houses',
    ownedLabel: 'Owned',
    buyBtn: 'Buy',
    notEnoughFunds: 'Not enough funds',
    cashbookEmpty: 'No income records yet. Finish your first house!',
    resetBtn: 'Reset Progress',
    resetConfirm: 'Tap again to reset',
    soundOn: 'Sound: On',
    soundOff: 'Sound: Off',
    langSwitch: 'ID',
    storyHeader: 'Homeowner Note',
    rotateBtn: 'Rotate 3D',
  },
} as const;

export type I18nKey = keyof typeof DICTIONARIES.id;

export function t(locale: Locale, key: I18nKey): string {
  return DICTIONARIES[locale][key];
}

export function pickText(text: LocalizedText, locale: Locale): string {
  return text[locale];
}

/**
 * Formats canonical Indonesian Rupiah amounts for display.
 * Free items (<= 0) always render as "Gratis" / "Free".
 * English locale converts canonical Rp into clean whole USD ($1 = Rp 1.000).
 */
export function formatMoney(amountRp: number, locale: Locale): string {
  const safe = Math.max(0, Math.round(amountRp));
  if (safe === 0) {
    return locale === 'id' ? 'Gratis' : 'Free';
  }
  if (locale === 'id') {
    const formatted = safe.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    return `Rp ${formatted}`;
  }
  const usd = Math.max(1, Math.round(safe / 1000));
  return `$${usd.toLocaleString('en-US')}`;
}
