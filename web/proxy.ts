import { NextResponse, type NextRequest } from 'next/server';

import { isLocale } from './lib/i18n';
import { LOCALE_COOKIE, localeRedirect } from './lib/locale-routing';

export function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  const target = localeRedirect(pathname, request.headers.get('accept-language'), request.cookies.get(LOCALE_COOKIE)?.value);

  if (target) {
    const url = request.nextUrl.clone();
    url.pathname = target;
    url.search = search;
    return NextResponse.redirect(url);
  }

  // Remember the language a visitor chose, for their next shared link.
  const response = NextResponse.next();
  const locale = pathname.split('/')[1];
  if (isLocale(locale) && request.cookies.get(LOCALE_COOKIE)?.value !== locale) {
    response.cookies.set(LOCALE_COOKIE, locale, { path: '/', maxAge: 60 * 60 * 24 * 365, sameSite: 'lax' });
  }
  return response;
}

export const config = {
  // Everything except Next internals and files with an extension (robots.txt, favicon.ico, …).
  matcher: ['/((?!_next/|api/|.*\\..*).*)'],
};
