import { describe, expect, it } from 'vitest';

import { linkOutcome, signInProblem } from '../lib/auth-link';

describe('linkOutcome', () => {
  it('finds the session tokens an implicit-flow link leaves in the hash', () => {
    expect(linkOutcome('#access_token=abc&refresh_token=def&type=magiclink', '')).toBe('tokens');
  });
  it('recognises an older PKCE link by its code', () => {
    expect(linkOutcome('', '?code=123')).toBe('code');
  });
  it('treats an expired or used link as expired, whether the error is in the hash or the query', () => {
    expect(linkOutcome('#error=access_denied&error_code=otp_expired', '')).toBe('expired');
    expect(linkOutcome('', '?error=access_denied&error_code=otp_expired')).toBe('expired');
  });
  it('ignores ordinary addresses', () => {
    expect(linkOutcome('', '?room=abc')).toBeNull();
    expect(linkOutcome('#comments', '')).toBeNull();
  });
});

describe('signInProblem', () => {
  it('names the usual reasons Supabase refuses to send a sign-in email', () => {
    expect(signInProblem('over_email_send_rate_limit', 429)).toBe('rateLimit');
    expect(signInProblem(undefined, 429)).toBe('rateLimit');
    expect(signInProblem('email_address_not_authorized', 400)).toBe('notAuthorized');
    expect(signInProblem('signup_disabled', 422)).toBe('signupOff');
    expect(signInProblem('email_address_invalid', 400)).toBe('badEmail');
    expect(signInProblem('unexpected_failure', 500)).toBe('error');
  });
});
