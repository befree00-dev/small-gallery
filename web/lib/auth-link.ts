/** Reads what a sign-in link left in the address: tokens, an old PKCE code, or an error. */
export function linkOutcome(hash: string, search: string): 'tokens' | 'code' | 'expired' | null {
  const h = new URLSearchParams(hash.replace(/^#/, ''));
  const q = new URLSearchParams(search);
  if (h.get('error') || q.get('error') || h.get('error_code') || q.get('error_code')) return 'expired';
  if (h.get('access_token')) return 'tokens';
  if (q.get('code')) return 'code';
  return null;
}

export type SignInProblem = 'rateLimit' | 'notAuthorized' | 'signupOff' | 'badEmail' | 'error';

/** Why Supabase refused to send a sign-in email, from its error code and HTTP status. */
export function signInProblem(code: string | undefined, status: number | undefined): SignInProblem {
  switch (code) {
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'rateLimit';
    case 'email_address_not_authorized':
      return 'notAuthorized';
    case 'signup_disabled':
    case 'otp_disabled':
    case 'email_provider_disabled':
      return 'signupOff';
    case 'email_address_invalid':
    case 'validation_failed':
      return 'badEmail';
  }
  return status === 429 ? 'rateLimit' : 'error';
}
