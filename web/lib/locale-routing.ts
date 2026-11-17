import { detectLocale, isLocale, type Locale } from './i18n';

/**
 * Where a request without a language prefix should go. Shared links look like
 * smallgallery.app/@jisu; this sends them to /ko/@jisu or /en/@jisu.
 * Returns null when the path already starts with a locale.
 */
export function localeRedirect(
  pathname: string,
  acceptLanguage: string | null,
  savedLocale: string | undefined,
): string | null {
  const first = pathname.split('/')[1];
  if (isLocale(first)) return null;
  const locale: Locale = isLocale(savedLocale) ? savedLocale : detectLocale(acceptLanguage);
  return pathname === '/' ? `/${locale}` : `/${locale}${pathname}`;
}

export const LOCALE_COOKIE = 'sg_locale';
