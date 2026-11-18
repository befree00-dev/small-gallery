'use client';

import { useEffect, useState } from 'react';

import { messages, type Locale } from '@/lib/i18n';
import { browserClient, enabledProviders, type Provider } from '@/lib/supabase';

import { rememberReturn } from './auth-return';

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9 3.5l6.7-6.7C35.6 2.4 30.2 0 24 0 14.6 0 6.6 5.4 2.7 13.3l7.8 6C12.4 13.7 17.7 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.1 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.4c-.5 2.9-2.2 5.3-4.6 6.9l7.5 5.8c4.4-4 6.8-10 6.8-17.2z" />
      <path fill="#FBBC05" d="M10.5 28.7c-.5-1.4-.8-3-.8-4.7s.3-3.2.8-4.7l-7.8-6C1 16.6 0 20.2 0 24s1 7.4 2.7 10.7l7.8-6z" />
      <path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.5-5.8c-2.1 1.4-4.8 2.3-8.4 2.3-6.3 0-11.6-4.2-13.5-9.9l-7.8 6C6.6 42.6 14.6 48 24 48z" />
    </svg>
  );
}

function AppleMark() {
  return (
    <svg width="16" height="18" viewBox="0 0 814 1000" aria-hidden="true" fill="currentColor">
      <path d="M788 341c-6 4-108 62-108 190 0 148 130 200 134 202-1 3-21 72-69 142-43 62-88 124-156 124s-86-40-165-40c-77 0-104 41-166 41s-106-57-156-127C44 791 0 671 0 557c0-183 119-280 236-280 62 0 114 41 153 41 37 0 95-43 166-43 27 0 124 2 188 66zM558 170c29-35 50-83 50-131 0-7-1-14-2-19-48 2-104 32-138 71-27 30-52 78-52 127 0 7 1 15 2 17 3 1 8 1 13 1 43 0 97-29 127-66z" />
    </svg>
  );
}

/**
 * "Continue with Google / Apple". Each button shows only once that provider is
 * switched on in Supabase, so nothing breaks before the setup is finished.
 */
export function OAuthButtons({ locale, returnTo }: { locale: Locale; returnTo: string }) {
  const t = messages(locale);
  const [providers, setProviders] = useState<Provider[]>([]);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    enabledProviders().then(setProviders);
  }, []);

  if (providers.length === 0) return null;

  async function go(provider: Provider) {
    setBusy(true);
    setFailed(false);
    rememberReturn(returnTo, 'oauth');
    const { error } = await browserClient().auth.signInWithOAuth({
      provider,
      options: { redirectTo: window.location.origin + returnTo },
    });
    // On success the browser is already leaving for Google or Apple.
    if (error) {
      setFailed(true);
      setBusy(false);
    }
  }

  return (
    <div className="oauth">
      <div className="oauth-or">
        <span>{t.or}</span>
      </div>
      {providers.includes('google') && (
        <button type="button" className="btn oauth-btn" disabled={busy} onClick={() => go('google')}>
          <GoogleMark />
          {t.continueWithGoogle}
        </button>
      )}
      {providers.includes('apple') && (
        <button type="button" className="btn oauth-btn oauth-apple" disabled={busy} onClick={() => go('apple')}>
          <AppleMark />
          {t.continueWithApple}
        </button>
      )}
      {failed && (
        <p className="notice" role="alert">
          {t.oauthFailed}
        </p>
      )}
    </div>
  );
}
