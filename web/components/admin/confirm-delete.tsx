'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';

import type { AdminStrings } from '@/lib/admin/messages';

/**
 * A modal that only lets a delete through once the admin types the exact
 * name of what is being deleted (gallery address or email).
 */
export function ConfirmDelete({
  title,
  body,
  word,
  t,
  onConfirm,
  onClose,
}: {
  title: string;
  body: string;
  word: string;
  t: AdminStrings;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [typed, setTyped] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    dialog.current?.showModal();
  }, []);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (typed.trim() !== word || busy) return;
    setBusy(true);
    try {
      await onConfirm();
    } finally {
      setBusy(false);
      dialog.current?.close();
    }
  }

  return (
    <dialog ref={dialog} className="confirm" aria-labelledby="confirm-title" onClose={onClose}>
      <form onSubmit={submit}>
        <h2 id="confirm-title">{title}</h2>
        <p>{body}</p>
        <div className="field">
          <label htmlFor="confirm-word">{t.typeToConfirm(word)}</label>
          <input
            id="confirm-word"
            className="input"
            autoComplete="off"
            autoCapitalize="none"
            spellCheck={false}
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
          />
        </div>
        <div className="row" style={{ justifyContent: 'flex-end' }}>
          <button type="button" className="btn" onClick={() => dialog.current?.close()} disabled={busy}>{t.cancel}</button>
          <button type="submit" className="btn btn-danger" disabled={typed.trim() !== word || busy}>{t.deleteForever}</button>
        </div>
      </form>
    </dialog>
  );
}
