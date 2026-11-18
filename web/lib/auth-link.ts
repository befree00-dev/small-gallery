/** Reads what a sign-in link left in the address: tokens, an old PKCE code, or an error. */
export function linkOutcome(hash: string, search: string): 'tokens' | 'code' | 'expired' | null {
  const h = new URLSearchParams(hash.replace(/^#/, ''));
  const q = new URLSearchParams(search);
  if (h.get('error') || q.get('error') || h.get('error_code') || q.get('error_code')) return 'expired';
  if (h.get('access_token')) return 'tokens';
  if (q.get('code')) return 'code';
  return null;
}
