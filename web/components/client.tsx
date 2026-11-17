'use client';

import type { Session } from '@supabase/supabase-js';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type FormEvent } from 'react';

import { messages, type Locale } from '@/lib/i18n';
import { browserClient } from '@/lib/supabase';
import { criteria, type Criterion, type Scores } from '@/lib/types';

// Visitor-side interactions. The server renders the page; these attach behavior.

export function useSession(): Session | null | undefined {
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  useEffect(() => {
    const auth = browserClient().auth;
    auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);
  return session;
}

const DEVICE_KEY = 'sg_device_key';

/** A random id this browser keeps so anonymous likes can be undone. */
function deviceKey(): string {
  try {
    let key = localStorage.getItem(DEVICE_KEY);
    if (!key) {
      key = crypto.randomUUID();
      localStorage.setItem(DEVICE_KEY, key);
    }
    return key;
  } catch {
    return crypto.randomUUID();
  }
}

export function ViewTracker({ galleryId, artworkId }: { galleryId: string; artworkId?: string }) {
  useEffect(() => {
    browserClient().rpc('record_view', { p_gallery_id: galleryId, p_artwork_id: artworkId ?? null }).then(() => {});
  }, [galleryId, artworkId]);
  return null;
}

/** Discourages casual saving: no context menu, no drag. Not a security boundary. */
export function ProtectedImage(props: { src: string; alt: string; width: number; height: number; className?: string; priority?: boolean }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={props.src}
      alt={props.alt}
      width={props.width}
      height={props.height}
      className={props.className}
      loading={props.priority ? 'eager' : 'lazy'}
      decoding="async"
      draggable={false}
      onContextMenu={(e) => e.preventDefault()}
    />
  );
}

export function CopyLink({ url, locale }: { url: string; locale: Locale }) {
  const t = messages(locale);
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="btn btn-quiet"
      onClick={async () => {
        await navigator.clipboard.writeText(url);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }}
    >
      <span aria-live="polite">{copied ? t.copied : t.share}</span>
    </button>
  );
}

export function LikeButton({ artworkId, initialCount, locale }: { artworkId: string; initialCount: number; locale: Locale }) {
  const t = messages(locale);
  const [liked, setLiked] = useState(false);
  const [count, setCount] = useState(initialCount);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    browserClient()
      .rpc('has_liked', { p_artwork_id: artworkId, p_device_key: deviceKey() })
      .then(({ data }) => setLiked(data === true));
  }, [artworkId]);

  async function toggle() {
    setBusy(true);
    setLiked(!liked);
    setCount(count + (liked ? -1 : 1));
    const { data, error } = await browserClient().rpc('toggle_like', { p_artwork_id: artworkId, p_device_key: deviceKey() });
    if (!error && Array.isArray(data) && data[0]) {
      setLiked(data[0].liked);
      setCount(data[0].like_count);
    } else {
      setLiked(liked);
      setCount(count);
    }
    setBusy(false);
  }

  return (
    <button type="button" className="btn like" aria-pressed={liked} onClick={toggle} disabled={busy}>
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
        <path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z" />
      </svg>
      {t.like} {count}
    </button>
  );
}

export function SignIn({ locale }: { locale: Locale }) {
  const t = messages(locale);
  const [email, setEmail] = useState('');
  const [state, setState] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');

  async function submit(e: FormEvent) {
    e.preventDefault();
    setState('sending');
    const { error } = await browserClient().auth.signInWithOtp({
      email,
      options: { emailRedirectTo: window.location.href, data: { locale } },
    });
    setState(error ? 'error' : 'sent');
  }

  if (state === 'sent') return <p className="notice" role="status">{t.linkSent}</p>;
  return (
    <form onSubmit={submit} className="composer">
      <div className="field" style={{ flex: 1 }}>
        <label htmlFor="signin-email">{t.signInPrompt}</label>
        <input id="signin-email" className="input" type="email" required autoComplete="email" placeholder={t.email} value={email} onChange={(e) => setEmail(e.target.value)} />
      </div>
      <button className="btn" type="submit" disabled={state === 'sending'}>{t.sendLink}</button>
      {state === 'error' && <p className="notice" role="alert">{t.error}</p>}
    </form>
  );
}

function Star({ on, label, onClick }: { on: boolean; label: string; onClick: () => void }) {
  return (
    <button type="button" className="star" aria-pressed={on} aria-label={label} onClick={onClick}>
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path strokeLinejoin="round" d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z" />
      </svg>
    </button>
  );
}

const empty: Scores = { composition: 0, color: 0, technique: 0, emotion: 0 };

export function RatingForm({ artworkId, ownerId, locale }: { artworkId: string; ownerId: string; locale: Locale }) {
  const t = messages(locale);
  const session = useSession();
  const router = useRouter();
  const [scores, setScores] = useState<Scores>(empty);
  const [hadRating, setHadRating] = useState(false);
  const [state, setState] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');

  useEffect(() => {
    if (!session) return;
    browserClient()
      .from('ratings')
      .select('composition, color, technique, emotion')
      .eq('artwork_id', artworkId)
      .eq('user_id', session.user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (data) {
          setScores(data as Scores);
          setHadRating(true);
        }
      });
  }, [session, artworkId]);

  if (session === undefined) return null;
  if (session === null) return <SignIn locale={locale} />;
  if (session.user.id === ownerId) return <p className="notice">{t.ownWork}</p>;
  if (state === 'sent') return <p className="notice" role="status">{t.ratingSent}</p>;

  const complete = criteria.every((c) => scores[c] > 0);

  async function send() {
    setState('sending');
    const { error } = await browserClient()
      .from('ratings')
      .upsert({ artwork_id: artworkId, user_id: session!.user.id, ...scores }, { onConflict: 'artwork_id,user_id' });
    setState(error ? 'error' : 'sent');
    if (!error) router.refresh();
  }

  return (
    <div>
      {criteria.map((c: Criterion) => (
        <div className="star-row" key={c}>
          <span className="label">{t.criteria[c]}</span>
          {[1, 2, 3, 4, 5].map((n) => (
            <Star key={n} on={n <= scores[c]} label={t.starLabel(t.criteria[c], n)} onClick={() => setScores({ ...scores, [c]: n })} />
          ))}
          <span className="value">{scores[c] ? `${scores[c]} / 5` : '—'}</span>
        </div>
      ))}
      <p className="notice" style={{ marginTop: 4 }}>{t.ratingNote}</p>
      <button type="button" className="btn btn-primary" style={{ width: '100%' }} disabled={!complete || state === 'sending'} onClick={send}>
        {hadRating ? t.updateRating : t.submitRating}
      </button>
      {state === 'error' && <p className="notice" role="alert">{t.error}</p>}
    </div>
  );
}

export function CommentBox({
  galleryId,
  artworkId,
  locale,
}: {
  galleryId: string;
  artworkId: string | null;
  locale: Locale;
}) {
  const t = messages(locale);
  const session = useSession();
  const router = useRouter();
  const [body, setBody] = useState('');
  const [note, setNote] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (session === undefined) return null;
  if (session === null) return <SignIn locale={locale} />;

  async function submit(e: FormEvent) {
    e.preventDefault();
    const text = body.trim();
    if (!text) return;
    setBusy(true);
    const { data, error } = await browserClient()
      .from('comments')
      .insert({ gallery_id: galleryId, artwork_id: artworkId, author_id: session!.user.id, body: text })
      .select('status')
      .single();
    setBusy(false);
    if (error) {
      setNote(error.message.includes('author_blocked') ? t.blocked : error.message.includes('comments_closed') ? t.commentsClosed : t.error);
      return;
    }
    setBody('');
    setNote(data.status === 'pending' ? t.pending : null);
    router.refresh();
  }

  const label = artworkId ? t.writeComment : t.writeGuestbook;
  return (
    <>
      <form className="composer" onSubmit={submit}>
        <label htmlFor={`comment-${artworkId ?? 'guestbook'}`} className="visually-hidden">{label}</label>
        <textarea
          id={`comment-${artworkId ?? 'guestbook'}`}
          className="textarea"
          rows={2}
          maxLength={1000}
          placeholder={label}
          value={body}
          onChange={(e) => setBody(e.target.value)}
        />
        <button className="btn btn-primary" type="submit" disabled={busy || !body.trim()}>{t.send}</button>
      </form>
      {note && <p className="notice" role="status">{note}</p>}
    </>
  );
}

/** Shown on a gallery page only to its owner: a way back to the studio. */
export function OwnerLink({ ownerId, locale }: { ownerId: string; locale: Locale }) {
  const session = useSession();
  if (!session || session.user.id !== ownerId) return null;
  return (
    <a className="btn" href={`/${locale}/studio`}>
      {messages(locale).manage}
    </a>
  );
}
