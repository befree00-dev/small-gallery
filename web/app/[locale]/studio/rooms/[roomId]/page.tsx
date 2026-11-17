'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

import { useStudio } from '@/components/studio/shell';
import { Loading, Thumb, Toast, useLoad, useToast } from '@/components/studio/ui';
import * as api from '@/lib/studio/api';
import { moveItem } from '@/lib/studio/image-utils';

export default function RoomPage() {
  const { t, locale, gallery } = useStudio();
  const { roomId } = useParams<{ roomId: string }>();
  const router = useRouter();
  const rooms = useLoad(() => api.rooms(gallery.id), [gallery.id]);
  const works = useLoad(() => api.artworks(roomId), [roomId]);
  const [room, setRoom] = useState<api.StudioRoom | null>(null);
  const [editing, setEditing] = useState<string | null>(null);
  const [dragFrom, setDragFrom] = useState<number | null>(null);
  const [toast, showToast] = useToast();

  useEffect(() => {
    const found = rooms.data?.find((r) => r.id === roomId);
    if (found && room?.id !== found.id) setRoom(found);
  }, [rooms.data, roomId, room?.id]);

  async function save() {
    if (!room || !room.title.trim()) return;
    try {
      await api.updateRoom(room);
      showToast(t.saved);
    } catch {
      showToast(t.error);
    }
  }

  async function remove() {
    if (!window.confirm(t.deleteRoomConfirm)) return;
    await api.deleteRoom(roomId);
    router.push(`/${locale}/studio`);
  }

  async function reorder(from: number, to: number) {
    const list = works.data ?? [];
    const next = moveItem(list, from, to);
    if (next === list) return;
    works.set(next);
    try {
      await api.reorderArtworks(next);
      works.set(next.map((a, i) => ({ ...a, sort_order: i })));
    } catch {
      showToast(t.error);
      works.reload();
    }
  }

  if (rooms.data && !rooms.data.some((r) => r.id === roomId)) {
    return <p className="notice">404</p>;
  }

  return (
    <>
      <p style={{ margin: '0 0 8px' }}>
        <Link href={`/${locale}/studio`}>← {t.rooms}</Link>
      </p>
      {room ? (
        <section className="studio-card wide" aria-label={t.roomTitle}>
          <div className="field">
            <label htmlFor="room-title">{t.roomTitle}</label>
            <input id="room-title" className="input" maxLength={60} value={room.title} onChange={(e) => setRoom({ ...room, title: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="room-statement">{t.roomStatement}</label>
            <textarea id="room-statement" className="textarea" rows={3} maxLength={1000} value={room.statement} onChange={(e) => setRoom({ ...room, statement: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="room-visibility">{t.visibility}</label>
            <select id="room-visibility" className="input" value={room.visibility} onChange={(e) => setRoom({ ...room, visibility: e.target.value as api.Audience })}>
              {(Object.keys(t.visibilities) as api.Audience[]).map((v) => (
                <option key={v} value={v}>{t.visibilities[v]}</option>
              ))}
            </select>
          </div>
          <div className="row">
            <button className="btn btn-quiet" onClick={remove}>{t.delete}</button>
            <button className="btn btn-primary" style={{ marginLeft: 'auto' }} onClick={save} disabled={!room.title.trim()}>{t.save}</button>
          </div>
        </section>
      ) : (
        <p className="notice">{t.loading}</p>
      )}

      <Loading state={works} t={t}>
        {(list) =>
          list.length === 0 ? (
            <p className="notice">{t.emptyRoom}</p>
          ) : (
            <>
              <p className="meta">{t.reorderHint}</p>
              <ol className="work-list">
                {list.map((a, i) => (
                  <li
                    key={a.id}
                    draggable
                    onDragStart={() => setDragFrom(i)}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => {
                      if (dragFrom !== null) reorder(dragFrom, i);
                      setDragFrom(null);
                    }}
                    className={dragFrom === i ? 'dragging' : undefined}
                  >
                    <div className="work-row">
                      <span className="grip" aria-hidden="true">⋮⋮</span>
                      <Thumb path={a.thumb_path} alt="" />
                      <span className="work-title">
                        <strong>{a.title}</strong>
                        <span className="meta">
                          {[a.is_featured ? t.featured : null, t.visibilities[a.visibility], `♡ ${a.like_count}`].filter(Boolean).join(' · ')}
                        </span>
                      </span>
                      <button className="btn btn-quiet icon" aria-label={t.moveUp(a.title)} disabled={i === 0} onClick={() => reorder(i, i - 1)}>↑</button>
                      <button className="btn btn-quiet icon" aria-label={t.moveDown(a.title)} disabled={i === list.length - 1} onClick={() => reorder(i, i + 1)}>↓</button>
                      <button className="btn" aria-expanded={editing === a.id} onClick={() => setEditing(editing === a.id ? null : a.id)}>
                        {editing === a.id ? t.close : t.edit}
                      </button>
                    </div>
                    {editing === a.id && (
                      <ArtworkEditor
                        artwork={a}
                        onSaved={(updated) => {
                          works.set(list.map((w) => (w.id === updated.id ? updated : w)));
                          setEditing(null);
                          showToast(t.saved);
                        }}
                        onDeleted={() => {
                          works.set(list.filter((w) => w.id !== a.id));
                          setEditing(null);
                        }}
                      />
                    )}
                  </li>
                ))}
              </ol>
            </>
          )
        }
      </Loading>
      <Toast message={toast} />
    </>
  );
}

function ArtworkEditor({
  artwork,
  onSaved,
  onDeleted,
}: {
  artwork: api.StudioArtwork;
  onSaved: (a: api.StudioArtwork) => void;
  onDeleted: () => void;
}) {
  const { t } = useStudio();
  const [a, setA] = useState(artwork);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const id = (k: string) => `edit-${artwork.id}-${k}`;

  async function save() {
    if (!a.title.trim()) return setError(t.titleRequired);
    setBusy(true);
    try {
      await api.updateArtwork(a);
      onSaved(a);
    } catch {
      setError(t.error);
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (!window.confirm(t.deleteArtworkConfirm)) return;
    setBusy(true);
    await api.deleteArtwork(artwork);
    onDeleted();
  }

  return (
    <div className="editor">
      <div className="grid-2">
        <div className="field">
          <label htmlFor={id('title')}>{t.title}</label>
          <input id={id('title')} className="input" maxLength={80} value={a.title} onChange={(e) => setA({ ...a, title: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor={id('title-en')}>{t.titleEn}</label>
          <input id={id('title-en')} className="input" maxLength={80} value={a.title_en ?? ''} onChange={(e) => setA({ ...a, title_en: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor={id('year')}>{t.year}</label>
          <input id={id('year')} className="input" inputMode="numeric" value={a.year ?? ''} onChange={(e) => setA({ ...a, year: e.target.value ? Number(e.target.value) || null : null })} />
        </div>
        <div className="field">
          <label htmlFor={id('size')}>{t.size}</label>
          <input id={id('size')} className="input" value={a.size_text} onChange={(e) => setA({ ...a, size_text: e.target.value })} />
        </div>
      </div>
      <div className="field">
        <label htmlFor={id('note')}>{t.note}</label>
        <textarea id={id('note')} className="textarea" rows={3} value={a.note} onChange={(e) => setA({ ...a, note: e.target.value })} />
      </div>
      <div className="field">
        <label htmlFor={id('note-en')}>{t.noteEn}</label>
        <textarea id={id('note-en')} className="textarea" rows={2} value={a.note_en ?? ''} onChange={(e) => setA({ ...a, note_en: e.target.value })} />
      </div>
      <div className="field">
        <label htmlFor={id('vis')}>{t.visibility}</label>
        <select id={id('vis')} className="input" value={a.visibility} onChange={(e) => setA({ ...a, visibility: e.target.value as api.Audience })}>
          {(Object.keys(t.visibilities) as api.Audience[]).map((v) => (
            <option key={v} value={v}>{t.visibilities[v]}</option>
          ))}
        </select>
      </div>
      <label className="check"><input type="checkbox" checked={a.is_featured} onChange={(e) => setA({ ...a, is_featured: e.target.checked })} /> {t.featured}</label>
      <label className="check"><input type="checkbox" checked={a.rating_enabled} onChange={(e) => setA({ ...a, rating_enabled: e.target.checked })} /> {t.acceptRatings}</label>
      {error && <p className="notice" role="alert">{error}</p>}
      <div className="row">
        <button className="btn btn-quiet" onClick={remove} disabled={busy}>{t.delete}</button>
        <button className="btn btn-primary" style={{ marginLeft: 'auto' }} onClick={save} disabled={busy}>{t.save}</button>
      </div>
    </div>
  );
}
