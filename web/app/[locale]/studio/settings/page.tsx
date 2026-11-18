'use client';

import { useState, type FormEvent } from 'react';

import { useStudio } from '@/components/studio/shell';
import { Toast, useLoad, useToast } from '@/components/studio/ui';
import * as api from '@/lib/studio/api';

export default function SettingsPage() {
  const { t, gallery, setGallery, userId } = useStudio();
  const [g, setG] = useState(gallery);
  const [busy, setBusy] = useState(false);
  const [toast, showToast] = useToast();
  const usage = useLoad(async () => ({ count: await api.artworkCount(gallery.id), plan: await api.myPlan(userId) }), [gallery.id, userId]);

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!g.title.trim()) return;
    setBusy(true);
    try {
      await api.updateGallery(g);
      setGallery(g);
      showToast(t.saved);
    } catch {
      showToast(t.error);
    } finally {
      setBusy(false);
    }
  }

  const limit = usage.data?.plan === 'plus' ? 2000 : 100;

  return (
    <>
      <h1 className="title" style={{ fontSize: 30, marginBottom: 16 }}>{t.settingsTitle}</h1>
      <form className="studio-card wide" onSubmit={save}>
        <h2 className="studio-h2">{t.galleryInfo}</h2>
        <div className="grid-2">
          <div className="field">
            <label htmlFor="s-title">{t.galleryTitle}</label>
            <input id="s-title" className="input" maxLength={60} value={g.title} onChange={(e) => setG({ ...g, title: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="s-title-en">{t.titleEn}</label>
            <input id="s-title-en" className="input" maxLength={60} value={g.title_en ?? ''} onChange={(e) => setG({ ...g, title_en: e.target.value })} />
          </div>
        </div>
        <div className="field">
          <label htmlFor="s-bio">{t.bio}</label>
          <textarea id="s-bio" className="textarea" rows={3} maxLength={500} value={g.bio} onChange={(e) => setG({ ...g, bio: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor="s-bio-en">{t.bioEn}</label>
          <textarea id="s-bio-en" className="textarea" rows={2} maxLength={500} value={g.bio_en ?? ''} onChange={(e) => setG({ ...g, bio_en: e.target.value })} />
        </div>
        <div className="grid-2">
          <div className="field">
            <label htmlFor="s-theme">{t.theme}</label>
            <select id="s-theme" className="input" value={g.theme} onChange={(e) => setG({ ...g, theme: e.target.value as api.Theme })}>
              {(Object.keys(t.themes) as api.Theme[]).map((th) => <option key={th} value={th}>{t.themes[th]}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="s-vis">{t.visibility}</label>
            <select id="s-vis" className="input" value={g.visibility} onChange={(e) => setG({ ...g, visibility: e.target.value as api.Audience })}>
              {(Object.keys(t.visibilities) as api.Audience[]).map((v) => <option key={v} value={v}>{t.visibilities[v]}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="s-policy">{t.commentPolicy}</label>
            <select id="s-policy" className="input" value={g.comment_policy} onChange={(e) => setG({ ...g, comment_policy: e.target.value as api.Policy })}>
              {(Object.keys(t.policies) as api.Policy[]).map((p) => <option key={p} value={p}>{t.policies[p]}</option>)}
            </select>
          </div>
        </div>
        <label className="check"><input type="checkbox" checked={g.rating_enabled} onChange={(e) => setG({ ...g, rating_enabled: e.target.checked })} /> {t.ratingsAll}</label>
        <p className="meta">{t.addressFixed} (@{g.handle})</p>
        <button className="btn btn-primary" type="submit" disabled={busy || !g.title.trim()}>{t.save}</button>
      </form>

      {usage.data && (
        <section className="studio-card wide">
          <p style={{ margin: 0, fontWeight: 500 }}>{t.plan(usage.data.plan === 'plus' ? 'Plus' : 'Free', usage.data.count, limit)}</p>
          <progress max={limit} value={usage.data.count} className="steps" />
        </section>
      )}

      <Toast message={toast} />
    </>
  );
}
