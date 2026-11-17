'use client';

import { useEffect, useMemo, useRef, useState, type DragEvent } from 'react';

import { useStudio } from '@/components/studio/shell';
import { Toast, useLoad, useToast } from '@/components/studio/ui';
import * as api from '@/lib/studio/api';
import { MAX_UPLOAD_BYTES, titleFromFileName } from '@/lib/studio/image-utils';

interface Pending extends api.Draft {
  key: string;
  preview: string;
}

export default function UploadPage() {
  const { t, gallery, userId } = useStudio();
  const rooms = useLoad(() => api.rooms(gallery.id), [gallery.id]);
  const [items, setItems] = useState<Pending[]>([]);
  const [selected, setSelected] = useState(0);
  const [roomId, setRoomId] = useState('');
  const [year, setYear] = useState(String(new Date().getFullYear()));
  const [medium, setMedium] = useState('');
  const [watermark, setWatermark] = useState(false);
  const [ratings, setRatings] = useState(true);
  const [dragging, setDragging] = useState(false);
  const [done, setDone] = useState<number | null>(null);
  const [toast, showToast] = useToast();
  const input = useRef<HTMLInputElement>(null);

  // Free preview URLs when photos leave the list or the page closes.
  const previews = useRef(new Set<string>());
  useEffect(() => () => previews.current.forEach((u) => URL.revokeObjectURL(u)), []);

  const room = roomId || rooms.data?.[0]?.id || '';
  const current = items[selected];
  const total = (done ?? 0) + items.length;

  function add(files: FileList | File[]) {
    let tooLarge = false;
    const added: Pending[] = [];
    for (const file of Array.from(files)) {
      if (!file.type.startsWith('image/') && !/\.(heic|heif)$/i.test(file.name)) continue;
      if (file.size > MAX_UPLOAD_BYTES) {
        tooLarge = true;
        continue;
      }
      const preview = URL.createObjectURL(file);
      previews.current.add(preview);
      added.push({ key: crypto.randomUUID(), file, preview, title: titleFromFileName(file.name), titleEn: '', sizeText: '', note: '', noteEn: '' });
    }
    if (tooLarge) showToast(t.tooLarge);
    if (added.length) {
      setSelected(items.length);
      setItems([...items, ...added]);
    }
  }

  function removeAt(i: number) {
    URL.revokeObjectURL(items[i].preview);
    previews.current.delete(items[i].preview);
    const next = items.filter((_, j) => j !== i);
    setItems(next);
    setSelected(Math.max(0, Math.min(selected, next.length - 1)));
  }

  function update(patch: Partial<api.Draft>) {
    setItems(items.map((p, i) => (i === selected ? { ...p, ...patch } : p)));
  }

  async function submit() {
    if (!room) return showToast(t.needRoom);
    const missing = items.findIndex((p) => !p.title.trim());
    if (missing >= 0) {
      setSelected(missing);
      return showToast(t.titleRequired);
    }
    const shared: api.SharedDetails = { roomId: room, year: Number(year) || null, medium, watermark, ratingEnabled: ratings };
    let queue = [...items];
    setDone(0);
    let count = 0;
    while (queue.length) {
      const p = queue[0];
      try {
        await api.uploadArtwork(gallery, userId, p, shared);
      } catch (e) {
        const code = e instanceof api.StudioError ? e.code : 'unknown';
        showToast(code === 'quota_exceeded' ? t.quota : code === 'unsupported_image' ? t.unsupported : code === 'file_too_large' ? t.tooLarge : t.error);
        setItems(queue);
        setSelected(0);
        setDone(null);
        return;
      }
      URL.revokeObjectURL(p.preview);
      previews.current.delete(p.preview);
      queue = queue.slice(1);
      count += 1;
      setItems(queue);
      setDone(count);
    }
    setDone(null);
    setSelected(0);
    showToast(t.uploaded);
  }

  function onDrop(e: DragEvent) {
    e.preventDefault();
    setDragging(false);
    if (done === null) add(e.dataTransfer.files);
  }

  const mediaChips = useMemo(() => t.media, [t]);

  return (
    <>
      <h1 className="title" style={{ fontSize: 30, marginBottom: 16 }}>{t.uploadTitle}</h1>

      <div
        className="dropzone"
        data-dragging={dragging}
        onDragOver={(e) => {
          e.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={onDrop}
      >
        <p style={{ margin: 0 }}>
          {t.dropHere}{' '}
          <button type="button" className="btn" onClick={() => input.current?.click()} disabled={done !== null}>{t.pick}</button>
        </p>
        <p className="meta" style={{ margin: 0 }}>{t.formats}</p>
        <input
          ref={input}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          hidden
          onChange={(e) => {
            if (e.target.files) add(e.target.files);
            e.target.value = '';
          }}
        />
      </div>

      {items.length > 0 && (
        <ul className="picked" aria-label={t.selected}>
          {items.map((p, i) => (
            <li key={p.key} data-selected={i === selected}>
              <button type="button" className="picked-thumb" aria-pressed={i === selected} onClick={() => setSelected(i)}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.preview} alt={p.title || p.file.name} />
              </button>
              {done === null && (
                <button type="button" className="picked-remove" aria-label={t.remove(p.file.name)} onClick={() => removeAt(i)}>×</button>
              )}
            </li>
          ))}
        </ul>
      )}

      <p className="meta" role="status">{done !== null ? t.uploading(done, total) : t.gpsRemoved}</p>
      {done !== null && <progress max={total} value={done} className="steps" />}

      {current && (
        <div className="studio-card wide upload-form">
          <div className="grid-2" key={current.key}>
            <div className="field">
              <label htmlFor="u-title">{t.title}</label>
              <input id="u-title" className="input" maxLength={80} value={current.title} onChange={(e) => update({ title: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="u-title-en">{t.titleEn}</label>
              <input id="u-title-en" className="input" maxLength={80} value={current.titleEn} onChange={(e) => update({ titleEn: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="u-size">{t.size}</label>
              <input id="u-size" className="input" placeholder="32×24cm" value={current.sizeText} onChange={(e) => update({ sizeText: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="u-year">{t.year}</label>
              <input id="u-year" className="input" inputMode="numeric" value={year} onChange={(e) => setYear(e.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="u-note">{t.note}</label>
            <textarea id="u-note" className="textarea" rows={3} value={current.note} onChange={(e) => update({ note: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="u-note-en">{t.noteEn}</label>
            <textarea id="u-note-en" className="textarea" rows={2} value={current.noteEn} onChange={(e) => update({ noteEn: e.target.value })} />
          </div>

          <fieldset className="choices">
            <legend>{t.medium}</legend>
            <div className="chips">
              {mediaChips.map((m) => (
                <button type="button" key={m} className="chip" aria-pressed={medium === m} onClick={() => setMedium(medium === m ? '' : m)}>
                  {m}
                </button>
              ))}
            </div>
          </fieldset>

          <div className="field">
            <label htmlFor="u-room">{t.room}</label>
            <select id="u-room" className="input" value={room} onChange={(e) => setRoomId(e.target.value)}>
              {(rooms.data ?? []).map((r) => (
                <option key={r.id} value={r.id}>{r.title}</option>
              ))}
            </select>
          </div>
          <label className="check"><input type="checkbox" checked={watermark} onChange={(e) => setWatermark(e.target.checked)} /> {t.watermark}</label>
          <label className="check"><input type="checkbox" checked={ratings} onChange={(e) => setRatings(e.target.checked)} /> {t.acceptRatings}</label>

          <button className="btn btn-primary" onClick={submit} disabled={done !== null}>{t.hang}</button>
        </div>
      )}
      <Toast message={toast} />
    </>
  );
}
