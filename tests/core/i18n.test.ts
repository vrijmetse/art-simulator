import { describe, it, expect } from 'vitest';
import { DICTIONARIES, t, formatMoney, formatBalance, pickText } from '../../src/core/i18n';

describe('i18n', () => {
  it('has exact key parity between id and en dictionaries', () => {
    const idKeys = Object.keys(DICTIONARIES.id).sort();
    const enKeys = Object.keys(DICTIONARIES.en).sort();
    expect(idKeys).toEqual(enKeys);
    expect(idKeys.length).toBeGreaterThan(20);
  });

  it('translates keys cleanly per locale with no empty values', () => {
    for (const key of Object.keys(DICTIONARIES.id) as Array<keyof typeof DICTIONARIES.id>) {
      expect(t('id', key).trim().length).toBeGreaterThan(0);
      expect(t('en', key).trim().length).toBeGreaterThan(0);
    }
    expect(t('id', 'appTitle')).toBe('ART Simulator');
    expect(t('en', 'appTitle')).toBe('Cozy Homekeeper');
  });

  it('formats zero as Gratis/Free instead of Rp 0 or $0', () => {
    expect(formatMoney(0, 'id')).toBe('Gratis');
    expect(formatMoney(0, 'en')).toBe('Free');
  });

  it('formats wallet balances cleanly with Rp 0 / $0 rather than Gratis', () => {
    expect(formatBalance(0, 'id')).toBe('Rp 0');
    expect(formatBalance(0, 'en')).toBe('$0');
    expect(formatBalance(35000, 'id')).toBe('Rp 35.000');
    expect(formatBalance(35000, 'en')).toBe('$35');
  });

  it('formats canonical Rp amounts cleanly in id and converts display to USD in en', () => {
    expect(formatMoney(25000, 'id')).toBe('Rp 25.000');
    expect(formatMoney(150000, 'id')).toBe('Rp 150.000');
    expect(formatMoney(25000, 'en')).toBe('$25');
    expect(formatMoney(1500, 'en')).toBe('$2');
  });

  it('picks localized text cleanly', () => {
    expect(pickText({ id: 'Halo', en: 'Hello' }, 'id')).toBe('Halo');
    expect(pickText({ id: 'Halo', en: 'Hello' }, 'en')).toBe('Hello');
  });
});
