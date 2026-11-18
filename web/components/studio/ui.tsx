'use client';

import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';

import type { Audience } from '@/lib/studio/api';
import { effectiveVisibility } from '@/lib/studio/image-utils';
import type { StudioStrings } from '@/lib/studio/messages';
import { imageUrl } from '@/lib/supabase';

export interface LoadState<T> {
  data: T | undefined;
  error: boolean;
  loading: boolean;
  reload: () => void;
  set: (value: T) => void;
}

/** Runs `fn` on mount and whenever `deps` change; keeps the last result while reloading. */
export function useLoad<T>(fn: () => Promise<T>, deps: unknown[]): LoadState<T> {
  const [data, setData] = useState<T | undefined>(undefined);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(true);
  const fnRef = useRef(fn);
  fnRef.current = fn;

  const reload = useCallback(() => {
    setLoading(true);
    setError(false);
    fnRef
      .current()
      .then(setData)
      .catch(() => setError(true))
      .finally(() => setLoading(false));
  }, []);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(reload, deps);
  return { data, error, loading, reload, set: setData };
}

export function Loading<T>({ state, t, children }: { state: LoadState<T>; t: StudioStrings; children: (data: T) => ReactNode }) {
  if (state.error) {
    return (
      <div className="row">
        <p role="alert" className="notice" style={{ margin: 0 }}>{t.error}</p>
        <button className="btn" onClick={state.reload}>{t.retry}</button>
      </div>
    );
  }
  if (state.data === undefined) return <p className="notice">{t.loading}</p>;
  return <>{children(state.data)}</>;
}

export function CopyText({ text, label, done }: { text: string; label: string; done: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="btn"
      onClick={async () => {
        await navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }}
    >
      <span aria-live="polite">{copied ? done : label}</span>
    </button>
  );
}

export function Thumb({ path, alt, size = 56 }: { path: string; alt: string; size?: number }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={imageUrl(path)} alt={alt} width={size} height={size} className="thumb" style={{ width: size, height: size }} />
  );
}

/** A short message that clears itself. */
export function useToast(): [string | null, (message: string) => void] {
  const [message, setMessage] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const show = useCallback((m: string) => {
    setMessage(m);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setMessage(null), 3500);
  }, []);
  return [message, show];
}

export function Toast({ message }: { message: string | null }) {
  return (
    <div className="toast" role="status" aria-live="polite">
      {message}
    </div>
  );
}

/**
 * Visibility for a room or a work. Its "public" means "same as what it is in",
 * so it is labelled that way, and the result for visitors is spelled out.
 */
export function InnerVisibilitySelect({
  id,
  value,
  parent,
  parentKind,
  onChange,
  t,
}: {
  id: string;
  value: Audience;
  parent: Audience;
  parentKind: 'gallery' | 'room';
  onChange: (v: Audience) => void;
  t: StudioStrings;
}) {
  const follow = parentKind === 'gallery' ? t.followParent : t.followRoom;
  // "Link only" narrows only a public parent; offer it then (or keep it if already chosen).
  const showUnlisted = parent === 'public' || value === 'unlisted';
  return (
    <div className="field">
      <label htmlFor={id}>{t.visibility}</label>
      <select id={id} className="input" value={value} aria-describedby={`${id}-applies`} onChange={(e) => onChange(e.target.value as Audience)}>
        <option value="public">{follow(t.visibilities[parent])}</option>
        {showUnlisted && <option value="unlisted">{t.visibilities.unlisted}</option>}
        <option value="private">{t.privateOnlyMe}</option>
      </select>
      <span id={`${id}-applies`} className="meta">{t.appliesAs(t.visibilities[effectiveVisibility(parent, value)])}</span>
    </div>
  );
}
