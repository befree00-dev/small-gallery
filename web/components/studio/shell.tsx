'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { createContext, useCallback, useContext, useEffect, useState, type FormEvent, type ReactNode } from 'react';

import { useSession } from '@/components/client';
import type { Locale } from '@/lib/i18n';
import * as api from '@/lib/studio/api';
import { isValidHandle, normalizeHandle } from '@/lib/studio/image-utils';
import { studioMessages, type StudioStrings } from '@/lib/studio/messages';
import { browserClient } from '@/lib/supabase';

interface Studio {
  locale: Locale;
  t: StudioStrings;
  userId: string;
  gallery: api.StudioGallery;
  setGallery: (g: api.StudioGallery) => void;
}

const StudioContext = createContext<Studio | null>(null);

export function useStudio(): Studio {
  const s = useContext(StudioContext);
  if (!s) throw new Error('useStudio outside StudioShell');
  return s;
}

/** Signs the artist in, opens their gallery (or creates one), then shows the studio. */
export function StudioShell({ locale, children }: { locale: Locale; children: ReactNode }) {
  const t = studioMessages(locale);
  const session = useSession();
  const [gallery, setGallery] = useState<api.StudioGallery | null | undefined>(undefined);
  const [error, setError] = useState(false);
  const userId = session?.user.id;

  const load = useCallback(async () => {
    if (!userId) return;
    setError(false);
    setGallery(undefined);
    try {
      setGallery(await api.myGallery(userId));
    } catch {
      setError(true);
    }
  }, [userId]);

  useEffect(() => {
    load();
  }, [load]);

  let body: ReactNode;
  if (session === undefined || (session && gallery === undefined && !error)) {
    body = <p className="notice studio-center">{t.loading}</p>;
  } else if (session === null) {
    body = <AuthForm locale={locale} t={t} />;
  } else if (error) {
    body = (
      <div className="studio-center">
        <p role="alert">{t.error}</p>
        <div className="row">
          <button className="btn" onClick={load}>{t.retry}</button>
          <button className="btn btn-quiet" onClick={() => browserClient().auth.signOut()}>{t.signOut}</button>
        </div>
      </div>
    );
  } else if (gallery === null) {
    body = <CreateGallery userId={session.user.id} locale={locale} t={t} onCreated={setGallery} />;
  } else {
    return (
      <StudioContext.Provider value={{ locale, t, userId: session.user.id, gallery: gallery!, setGallery }}>
        <div className="studio">
          <StudioNav />
          <main className="studio-main">{children}</main>
        </div>
      </StudioContext.Provider>
    );
  }

  return (
    <main className="page">
      <div className="wrap">
        <header className="topbar">
          <Link className="address" href={`/${locale}`}>Small Gallery</Link>
          <a className="btn btn-quiet" href={locale === 'ko' ? '/en/studio' : '/ko/studio'}>{locale === 'ko' ? 'English' : '한국어'}</a>
        </header>
        {body}
      </div>
    </main>
  );
}

function StudioNav() {
  const { t, locale, gallery } = useStudio();
  const path = usePathname();
  const base = `/${locale}/studio`;
  const items = [
    { href: base, label: t.navGallery, active: path === base || path.startsWith(`${base}/rooms`) },
    { href: `${base}/upload`, label: t.navUpload, active: path.startsWith(`${base}/upload`) },
    { href: `${base}/reactions`, label: t.navReactions, active: path.startsWith(`${base}/reactions`) },
    { href: `${base}/settings`, label: t.navSettings, active: path.startsWith(`${base}/settings`) },
  ];
  return (
    <aside className="studio-nav">
      <div className="studio-brand">
        <span className="meta">Small Gallery · {t.studio}</span>
        <strong>{gallery.title}</strong>
      </div>
      <nav aria-label={t.studio}>
        {items.map((i) => (
          <Link key={i.href} href={i.href} aria-current={i.active ? 'page' : undefined} className="studio-link">
            {i.label}
          </Link>
        ))}
      </nav>
      <a className="studio-link" href={`/${locale}/@${gallery.handle}`} target="_blank" rel="noreferrer">
        {t.viewAsVisitor} ↗
      </a>
    </aside>
  );
}

function AuthForm({ locale, t }: { locale: Locale; t: StudioStrings }) {
  const [mode, setMode] = useState<'signIn' | 'signUp'>('signIn');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMessage(null);
    const auth = browserClient().auth;
    if (mode === 'signIn') {
      const { error } = await auth.signInWithPassword({ email, password });
      if (error) setMessage(t.authFailed);
    } else {
      const { data, error } = await auth.signUp({
        email,
        password,
        options: {
          data: { display_name: name.trim(), locale },
          emailRedirectTo: `${window.location.origin}/${locale}/studio`,
        },
      });
      if (error) setMessage(t.signUpFailed);
      else if (!data.session) setMessage(t.checkEmail);
    }
    setBusy(false);
  }

  return (
    <form className="studio-card" onSubmit={submit}>
      <h1 className="title" style={{ fontSize: 28 }}>{mode === 'signIn' ? t.signIn : t.signUp}</h1>
      <p className="meta">{t.sameAccount}</p>
      {mode === 'signUp' && (
        <div className="field">
          <label htmlFor="auth-name">{t.displayName}</label>
          <input id="auth-name" className="input" required maxLength={40} value={name} onChange={(e) => setName(e.target.value)} />
        </div>
      )}
      <div className="field">
        <label htmlFor="auth-email">{t.email}</label>
        <input id="auth-email" className="input" type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
      </div>
      <div className="field">
        <label htmlFor="auth-password">{t.password}</label>
        <input
          id="auth-password"
          className="input"
          type="password"
          required
          minLength={8}
          autoComplete={mode === 'signIn' ? 'current-password' : 'new-password'}
          aria-describedby="auth-password-rule"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <span id="auth-password-rule" className="meta">{t.passwordRule}</span>
      </div>
      {message && <p className="notice" role="status">{message}</p>}
      <button className="btn btn-primary" type="submit" disabled={busy}>{mode === 'signIn' ? t.signIn : t.signUp}</button>
      <button type="button" className="btn btn-quiet" onClick={() => { setMode(mode === 'signIn' ? 'signUp' : 'signIn'); setMessage(null); }}>
        {mode === 'signIn' ? t.needAccount : t.haveAccount}
      </button>
    </form>
  );
}

function CreateGallery({
  userId,
  locale,
  t,
  onCreated,
}: {
  userId: string;
  locale: Locale;
  t: StudioStrings;
  onCreated: (g: api.StudioGallery) => void;
}) {
  const [step, setStep] = useState(0);
  const [field, setField] = useState<api.Field>('painting');
  const [title, setTitle] = useState('');
  const [rawHandle, setRawHandle] = useState('');
  const [available, setAvailable] = useState<boolean | null>(null);
  const [theme, setTheme] = useState<api.Theme>('white');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const handle = normalizeHandle(rawHandle);
  const handleValid = isValidHandle(handle);

  useEffect(() => {
    setAvailable(null);
    if (!handleValid) return;
    const timer = setTimeout(async () => setAvailable(await api.isHandleAvailable(handle)), 400);
    return () => clearTimeout(timer);
  }, [handle, handleValid]);

  async function create() {
    setBusy(true);
    setError(null);
    try {
      onCreated(await api.createGallery({ ownerId: userId, handle, title: title.trim(), field, theme, firstRoomTitle: t.firstRoom }));
    } catch (e) {
      const code = e instanceof api.StudioError ? e.code : 'unknown';
      setError(code === 'handle_taken' || code === 'handle_reserved' ? t.handleTaken : t.error);
      setStep(1);
    } finally {
      setBusy(false);
    }
  }

  const canNext = step === 0 || step === 2 || (title.trim() !== '' && handleValid && available === true);
  const site = typeof window === 'undefined' ? '' : window.location.host;

  return (
    <section className="studio-card" aria-labelledby="create-title">
      <h1 id="create-title" className="title" style={{ fontSize: 28 }}>{t.createTitle}</h1>
      <progress max={3} value={step + 1} aria-label={`${step + 1} / 3`} className="steps" />

      {step === 0 && (
        <fieldset className="choices">
          <legend>{t.stepField}</legend>
          {(Object.keys(t.fields) as api.Field[]).map((f) => (
            <label key={f} className="choice">
              <input type="radio" name="field" checked={field === f} onChange={() => setField(f)} /> {t.fields[f]}
            </label>
          ))}
        </fieldset>
      )}

      {step === 1 && (
        <>
          <div className="field">
            <label htmlFor="g-title">{t.galleryTitle}</label>
            <input id="g-title" className="input" maxLength={60} value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="g-handle">{t.galleryAddress}</label>
            <div className="prefix-input">
              <span aria-hidden="true">{site}/@</span>
              <input
                id="g-handle"
                autoComplete="off"
                autoCapitalize="none"
                spellCheck={false}
                aria-describedby="g-handle-help"
                value={rawHandle}
                onChange={(e) => setRawHandle(e.target.value)}
              />
            </div>
            <span id="g-handle-help" className="meta" role="status">
              {rawHandle && !handleValid ? t.handleRule : available === false ? t.handleTaken : available ? `✓ ${t.handleOk}` : t.handleRule}
            </span>
          </div>
        </>
      )}

      {step === 2 && (
        <fieldset className="choices">
          <legend>{t.theme}</legend>
          <div className="themes">
            {(Object.keys(t.themes) as api.Theme[]).map((th) => (
              <label key={th} className={`theme-swatch theme-${th}`} data-selected={theme === th}>
                <input type="radio" name="theme" className="visually-hidden" checked={theme === th} onChange={() => setTheme(th)} />
                <span className="swatch-art" aria-hidden="true" />
                <span>{t.themes[th]}</span>
              </label>
            ))}
          </div>
        </fieldset>
      )}

      {error && <p className="notice" role="alert">{error}</p>}
      <div className="row">
        {step > 0 && <button className="btn" onClick={() => setStep(step - 1)}>{t.back}</button>}
        <button
          className="btn btn-primary"
          style={{ marginLeft: 'auto' }}
          disabled={!canNext || busy}
          onClick={() => (step < 2 ? setStep(step + 1) : create())}
        >
          {step < 2 ? t.next : t.create}
        </button>
      </div>
      <span className="meta" lang={locale}>{t.addressFixed}</span>
    </section>
  );
}
