import { beforeEach, describe, expect, it } from 'vitest';

import {
  applyLtrIsolation,
  applySamtDocumentDirection,
  createLtrIsolate,
  normalizeSamtLanguage,
} from '../../src/utils/samt-rtl';

describe('SAMT RTL foundation', () => {
  beforeEach(() => {
    document.documentElement.removeAttribute('lang');
    document.documentElement.removeAttribute('dir');
    delete document.documentElement.dataset.samtLocale;
    delete document.documentElement.dataset.samtDirection;
  });

  it('normalizes Arabic regional codes', () => {
    expect(normalizeSamtLanguage('ar-AE')).toBe('ar');
  });

  it('applies Arabic UAE language and RTL direction', () => {
    const language = applySamtDocumentDirection('ar');

    expect(language).toBe('ar');
    expect(document.documentElement.lang).toBe('ar-AE');
    expect(document.documentElement.dir).toBe('rtl');
    expect(document.documentElement.dataset.samtDirection).toBe('rtl');
  });

  it('removes RTL direction for English', () => {
    applySamtDocumentDirection('ar');
    applySamtDocumentDirection('en');

    expect(document.documentElement.lang).toBe('en');
    expect(document.documentElement.hasAttribute('dir')).toBe(false);
    expect(document.documentElement.dataset.samtDirection).toBe('ltr');
  });

  it('isolates technical identifiers as LTR', () => {
    const element = applyLtrIsolation(document.createElement('span'));

    expect(element.dir).toBe('ltr');
    expect(element.dataset.bidi).toBe('ltr');
    expect(element.classList.contains('wm-bidi-ltr')).toBe(true);
  });

  it('preserves an identifier without translation or reordering', () => {
    const value = 'A6-EWB / 25.2048, 55.2708';
    const element = createLtrIsolate(value, 'code');

    expect(element.tagName).toBe('CODE');
    expect(element.textContent).toBe(value);
    expect(element.dir).toBe('ltr');
  });
});
