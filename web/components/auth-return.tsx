'use client';

import { useEffect, useState } from 'react';

import { messages, type Locale } from '@/lib/i18n';
import { linkOutcome } from '@/lib/auth-link';
import { browserClient, isConfigured } from '@/lib/supabase';

const RETURN_KEY = 'sg_return_to';

/** Where a visitor asked for a sign-in link, so the link brings them back there. */
export function rememberReturn(path: string, method: 'email' | 'oauth' = 'email') {
  try {
    localStorage.setItem(RETURN_KEY, JSON.stringify({ path, method, at: Date.now() }));
  } catch {
    // Private mode: the link still signs them in on whatever page it opens.
  }
}

function takeReturn(): string | null {
  try {
    const raw = localStorage.getItem(RETURN_KEY);
    localStorage.removeItem(RETURN_KEY);
    if (!raw) return null;
    const { path, at } = JSON.parse(raw) as { path: string; at: number };
    // Only same-site paths, and only for a recent request.
    return path.startsWith('/') && !path.startsWith('//') && Date.now() - at < 24 * 3600_000 ? path : null;
  } catch {
    return null;
  }
}

export type AuthOutcome = 'signedIn' | 'expired' | 'otherBrowser' | 'oauthFailed' | null;

/** How the pending sign-in was started, without consuming it. */
function pendingMethod(): 'email' | 'oauth' | null {
  try {
    const raw = localStorage.getItem(RETURN_KEY);
    return raw ? ((JSON.parse(raw) as { method?: 'email' | 'oauth' }).method ?? 'email') : null;
  } catch {
    return null;
  }
}

/**
 * Finishes a magic-link sign-in on whichever page the link opens, says how it went,
 * and returns the visitor to the gallery they were looking at.
 */
export function AuthReturn({ locale }: { locale: Locale }) {
  const t = messages(locale);
  const [outcome, setOutcome] = useState<AuthOutcome>(null);

  useEffect(() => {
    if (!isConfigured()) return;
    const kind = linkOutcome(window.location.hash, window.location.search);
    if (!kind) return;
    let cancelled = false;
    (async () => {
      const auth = browserClient().auth;
      let ok = false;
      if (kind === 'tokens') {
        // The client reads the tokens from the address while it starts up.
        const { data } = await auth.getSession();
        ok = data.session != null;
      } else if (kind === 'code') {
        // A link sent before the switch to implicit flow: works only in the requesting browser.
        const code = new URLSearchParams(window.location.search).get('code')!;
        const { error } = await auth.exchangeCodeForSession(code);
        ok = !error;
        if (!ok) {
          const { data } = await auth.getSession();
          ok = data.session != null;
        }
      }
      if (cancelled) return;

      // Clean the address so a refresh or a shared link does not carry tokens or errors.
      const url = new URL(window.location.href);
      url.hash = '';
      for (const k of ['code', 'error', 'error_code', 'error_description']) url.searchParams.delete(k);
      window.history.replaceState(null, '', url.pathname + url.search);

      const viaOAuth = pendingMethod() === 'oauth';
      const result: AuthOutcome = ok
        ? 'signedIn'
        : viaOAuth
          ? 'oauthFailed'
          : kind === 'code'
            ? 'otherBrowser'
            : 'expired';
      if (!ok) takeReturn();
      const back = ok ? takeReturn() : null;
      if (back && back !== url.pathname + url.search) {
        try {
          sessionStorage.setItem('sg_auth_outcome', result);
        } catch {}
        window.location.replace(back);
        return;
      }
      setOutcome(result);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // A redirect above carries the outcome to the page it lands on.
  useEffect(() => {
    try {
      const carried = sessionStorage.getItem('sg_auth_outcome') as AuthOutcome;
      if (carried) {
        sessionStorage.removeItem('sg_auth_outcome');
        setOutcome(carried);
      }
    } catch {}
  }, []);

  useEffect(() => {
    if (outcome !== 'signedIn') return;
    const timer = setTimeout(() => setOutcome(null), 5000);
    return () => clearTimeout(timer);
  }, [outcome]);

  if (!outcome) return null;
  const text = {
    signedIn: t.signedIn,
    expired: t.linkExpired,
    otherBrowser: t.linkOtherBrowser,
    oauthFailed: t.oauthFailed,
  }[outcome];
  return (
    <div className="auth-banner" role={outcome === 'signedIn' ? 'status' : 'alert'} data-tone={outcome === 'signedIn' ? 'ok' : 'warn'}>
      <span>{text}</span>
      <button type="button" className="auth-banner-close" aria-label="×" onClick={() => setOutcome(null)}>
        ×
      </button>
    </div>
  );
}
