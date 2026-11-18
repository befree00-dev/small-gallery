'use client';

import Link from 'next/link';
import { useEffect, useState, type FormEvent } from 'react';

import { CopyText, Loading, useLoad } from '@/components/studio/ui';
import { useStudio } from '@/components/studio/shell';
import * as api from '@/lib/studio/api';
import { effectiveVisibility } from '@/lib/studio/image-utils';

export default function StudioHome() {
  const { t, locale, gallery } = useStudio();
  const rooms = useLoad(() => api.rooms(gallery.id), [gallery.id]);
  const [title, setTitle] = useState('');
  const [busy, setBusy] = useState(false);
  const [origin, setOrigin] = useState('');
  useEffect(() => setOrigin(window.location.origin), []);

  async function addRoom(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setBusy(true);
    try {
      await api.createRoom(gallery.id, title.trim(), rooms.data?.length ?? 0);
      setTitle('');
      rooms.reload();
    } finally {
      setBusy(false);
    }
  }

  const total = (rooms.data ?? []).reduce((s, r) => s + (r.artworks[0]?.count ?? 0), 0);

  return (
    <>
      <header className="studio-head">
        <div>
          <h1 className="title" style={{ fontSize: 30 }}>{gallery.title}</h1>
          <p className="meta" style={{ margin: 0 }}>
            {origin.replace(/^https?:\/\//, '')}/@{gallery.handle} · {t.works(total)}
          </p>
          <p className="meta" style={{ margin: 0 }}>
            <Link href={`/${locale}/studio/settings`}>{t.galleryVisibility(t.visibilities[gallery.visibility])}</Link>
          </p>
        </div>
        <div className="row">
          <CopyText text={`${origin}/@${gallery.handle}`} label={t.copyLink} done={t.copied} />
          <Link className="btn btn-primary" href={`/${locale}/studio/upload`}>{t.navUpload}</Link>
        </div>
      </header>

      <section aria-labelledby="rooms-title">
        <h2 id="rooms-title" className="studio-h2">{t.rooms}</h2>
        <Loading state={rooms} t={t}>
          {(list) =>
            list.length === 0 ? (
              <p className="notice">{t.emptyGallery}</p>
            ) : (
              <ul className="room-list">
                {list.map((r) => (
                  <li key={r.id}>
                    <Link href={`/${locale}/studio/rooms/${r.id}`} className="room-row">
                      <span>
                        <strong>{r.title}</strong>
                        <span className="meta"> · {t.works(r.artworks[0]?.count ?? 0)} · {t.visibilities[effectiveVisibility(gallery.visibility, r.visibility)]}</span>
                      </span>
                      <span aria-hidden="true">›</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )
          }
        </Loading>
        <form className="composer" onSubmit={addRoom} style={{ marginTop: 16 }}>
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="new-room">{t.newRoom}</label>
            <input id="new-room" className="input" maxLength={60} placeholder={t.roomTitle} value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
          <button className="btn" type="submit" disabled={busy || !title.trim()}>{t.newRoom}</button>
        </form>
      </section>
    </>
  );
}
