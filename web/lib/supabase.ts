import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '';

export function isConfigured(): boolean {
  return url !== '' && key !== '';
}

/** Server-side reads as an anonymous visitor: RLS shows only what is published. */
export function serverClient(): SupabaseClient {
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

let browser: SupabaseClient | null = null;

/**
 * Browser client that keeps the visitor's session (magic-link sign-in).
 * Implicit flow: the link carries the session itself, so it works even when the
 * mail app opens it in another browser (PKCE needs the browser that asked).
 */
export function browserClient(): SupabaseClient {
  browser ??= createClient(url, key, { auth: { persistSession: true, detectSessionInUrl: true, flowType: 'implicit' } });
  return browser;
}

export function imageUrl(path: string): string {
  return `${url}/storage/v1/object/public/artworks/${path.split('/').map(encodeURIComponent).join('/')}`;
}
