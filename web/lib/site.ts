import { headers } from 'next/headers';

const fallback = (process.env.NEXT_PUBLIC_SITE_URL ?? 'https://smallgallery.app').replace(/\/$/, '');

/** "https://host" from the request's forwarded headers; the fallback when they are missing. */
export function originFrom(host: string | null, proto: string | null, fallbackOrigin = fallback): string {
  const h = host?.split(',')[0].trim();
  if (!h) return fallbackOrigin;
  const p = proto?.split(',')[0].trim() || (h.startsWith('localhost') || h.startsWith('127.') ? 'http' : 'https');
  return `${p}://${h}`;
}

/**
 * The address this page was requested on, so share links and link previews
 * always match the site the visitor is on (Vercel URL, custom domain, …)
 * without any setting.
 */
export async function siteOrigin(): Promise<string> {
  const h = await headers();
  return originFrom(h.get('x-forwarded-host') ?? h.get('host'), h.get('x-forwarded-proto'));
}
