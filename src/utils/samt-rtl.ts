/**
 * SAMT Arabic-first and bidirectional helpers.
 *
 * URLs, source IDs, callsigns, registrations, tickers, airport codes,
 * coordinates, and technical designations must remain LTR.
 */

export const SAMT_DEFAULT_LANGUAGE = 'ar';

const RTL_LANGUAGES = new Set(['ar', 'fa']);

export function normalizeSamtLanguage(language: string | null | undefined): string {
  const normalized = (language || SAMT_DEFAULT_LANGUAGE)
    .trim()
    .split('-')[0]
    ?.toLowerCase();

  return normalized || SAMT_DEFAULT_LANGUAGE;
}

export function applySamtDocumentDirection(language: string): string {
  const normalized = normalizeSamtLanguage(language);
  const isRtl = RTL_LANGUAGES.has(normalized);

  document.documentElement.lang =
    normalized === 'ar' ? 'ar-AE' : normalized === 'zh' ? 'zh-CN' : normalized;

  if (isRtl) {
    document.documentElement.dir = 'rtl';
  } else {
    document.documentElement.removeAttribute('dir');
  }

  document.documentElement.dataset.samtLocale = normalized;
  document.documentElement.dataset.samtDirection = isRtl ? 'rtl' : 'ltr';

  return normalized;
}

export function applyLtrIsolation(element: HTMLElement): HTMLElement {
  element.dir = 'ltr';
  element.dataset.bidi = 'ltr';
  element.classList.add('wm-bidi-ltr');
  return element;
}

export function createLtrIsolate(
  text: string,
  tagName: keyof HTMLElementTagNameMap = 'span',
): HTMLElement {
  const element = document.createElement(tagName);
  element.textContent = text;
  return applyLtrIsolation(element);
}
