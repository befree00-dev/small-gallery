'use client';

import { useParams } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';

import { useSession } from '@/components/client';
import { DailyBars } from '@/components/admin/daily-bars';
import { Logo } from '@/components/logo';
import { AuthForm } from '@/components/studio/shell';
import { Toast, useToast } from '@/components/studio/ui';
import * as api from '@/lib/admin/api';
import { adminMessages, type AdminStrings } from '@/lib/admin/messages';
import { isLocale, type Locale } from '@/lib/i18n';
import { studioMessages } from '@/lib/studio/messages';
import { browserClient } from '@/lib/supabase';

interface Data {
  overview: api.Overview;
  days: api.Day[];
  galleries: api.AdminGallery[];
  comments: api.AdminComment[];
  reports: api.AdminReport[];
}

export default function AdminPage() {
  const params = useParams<{ locale: string }>();
  const locale: Locale = isLocale(params.locale) ? params.locale : 'ko';
  const t = adminMessages(locale);
  const session = useSession();
  const [admin, setAdmin] = useState<boolean | null>(null);
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);
  const [toast, showToast] = useToast();

  useEffect(() => {
    if (!session) return;
    setAdmin(null);
    api.isAdmin().then(setAdmin, () => setAdmin(false));
  }, [session]);

  const load = useCallback(async () => {
    setError(false);
    try {
      const [overview, days, galleries, comments, reports] = await Promise.all([
        api.overview(),
        api.daily(30),
        api.galleries(50),
        api.comments(50),
        api.reports(),
      ]);
      setData({ overview, days, galleries, comments, reports });
    } catch {
      setError(true);
    }
  }, []);

  useEffect(() => {
    if (admin) load();
  }, [admin, load]);

  async function act(action: () => Promise<void>) {
    try {
      await action();
      await load();
    } catch {
      showToast(t.actionFailed);
    }
  }

  let body;
  if (session === undefined || (session && admin === null)) {
    body = <p className="notice">{t.checking}</p>;
  } else if (session === null) {
    body = <AuthForm locale={locale} t={studioMessages(locale)} />;
  } else if (!admin) {
    body = (
      <div className="studio-center">
        <p role="alert" style={{ margin: 0 }}>{t.denied}</p>
        <p className="meta" style={{ margin: 0 }}>{t.deniedHelp}</p>
        <button className="btn" onClick={() => browserClient().auth.signOut()}>{t.signOut}</button>
      </div>
    );
  } else if (error) {
    body = (
      <div className="row">
        <p role="alert" className="notice" style={{ margin: 0 }}>{t.error}</p>
        <button className="btn" onClick={load}>{t.retry}</button>
      </div>
    );
  } else if (!data) {
    body = <p className="notice">{t.checking}</p>;
  } else {
    body = <Dashboard data={data} locale={locale} t={t} act={act} />;
  }

  return (
    <main className="page admin">
      <div className="wrap">
        <header className="topbar">
          <Logo href={`/${locale}`} />
          <div className="actions">
            {admin && <button className="btn btn-quiet" onClick={load}>{t.refresh}</button>}
            <a className="btn btn-quiet" href={locale === 'ko' ? '/en/admin' : '/ko/admin'}>{locale === 'ko' ? 'English' : '한국어'}</a>
          </div>
        </header>
        <h1 className="title" style={{ fontSize: 30, margin: '24px 0 16px' }}>{t.title}</h1>
        {body}
      </div>
      <Toast message={toast} />
    </main>
  );
}

function Dashboard({ data, locale, t, act }: { data: Data; locale: Locale; t: AdminStrings; act: (f: () => Promise<void>) => void }) {
  const { overview: o } = data;
  const num = new Intl.NumberFormat(locale === 'ko' ? 'ko-KR' : 'en-US');
  const when = new Intl.DateTimeFormat(locale === 'ko' ? 'ko-KR' : 'en-US', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Seoul' });
  const metrics = ['galleries', 'users', 'artworks', 'comments', 'ratings', 'likes', 'views'] as const;

  return (
    <>
      <section aria-labelledby="today-title">
        <h2 id="today-title" className="studio-h2">{t.todayOf(o.day)}</h2>
        <dl className="kpis">
          {metrics.map((m) => (
            <div key={m}>
              <dt>{t.metrics[m]}</dt>
              <dd className="kpi-today">{num.format(o[m].today)}</dd>
              <dd className="meta">{t.total} {num.format(o[m].total)}</dd>
            </div>
          ))}
        </dl>
        {(o.pending_comments > 0 || o.open_reports > 0) && (
          <ul className="alerts">
            {o.open_reports > 0 && <li><a href="#reports">{t.openReports(o.open_reports)}</a></li>}
            {o.pending_comments > 0 && <li><a href="#comments">{t.pending(o.pending_comments)}</a></li>}
          </ul>
        )}
      </section>

      <section className="charts" aria-label={t.last30}>
        <DailyBars title={t.dailyViews} days={data.days} field="views" locale={locale} t={t} />
        <DailyBars title={t.dailyGalleries} days={data.days} field="galleries" locale={locale} t={t} />
        <DailyBars title={t.dailyComments} days={data.days} field="comments" locale={locale} t={t} />
      </section>

      <section id="reports" aria-labelledby="reports-title" className="admin-section">
        <h2 id="reports-title" className="studio-h2">{t.reports} · {data.reports.length}</h2>
        {data.reports.length === 0 ? (
          <p className="notice">{t.noReports}</p>
        ) : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr><th scope="col">{t.where}</th><th scope="col">{t.body}</th><th scope="col">{t.reporter}</th><th scope="col">{t.created}</th><th scope="col"><span className="visually-hidden">{t.status}</span></th></tr>
              </thead>
              <tbody>
                {data.reports.map((r) => (
                  <tr key={r.id}>
                    <td>{t.targets[r.target_type]} · {t.reasons[r.reason] ?? r.reason}<br />{r.gallery_handle && <a href={`/${locale}/@${r.gallery_handle}`} target="_blank" rel="noreferrer">@{r.gallery_handle}</a>}</td>
                    <td className="clip">{r.target_label}</td>
                    <td>{r.reporter_name}</td>
                    <td className="nowrap">{when.format(new Date(r.created_at))}</td>
                    <td className="nowrap">
                      {r.target_type === 'comment' && (
                        <button className="btn" onClick={() => act(async () => { await api.setCommentStatus(r.target_id, 'hidden'); await api.resolveReport(r.id, 'actioned'); })}>{t.hide}</button>
                      )}
                      {r.target_type !== 'comment' && <button className="btn" onClick={() => act(() => api.resolveReport(r.id, 'actioned'))}>{t.actioned}</button>}
                      <button className="btn btn-quiet" onClick={() => act(() => api.resolveReport(r.id, 'dismissed'))}>{t.dismiss}</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section aria-labelledby="galleries-title" className="admin-section">
        <h2 id="galleries-title" className="studio-h2">{t.galleries}</h2>
        <div className="table-wrap">
          <table className="data">
            <thead>
              <tr>
                <th scope="col">{t.gallery}</th><th scope="col">{t.owner}</th>
                <th scope="col" className="num">{t.works}</th><th scope="col" className="num">{t.views}</th>
                <th scope="col">{t.visibility}</th><th scope="col">{t.created}</th><th scope="col"><span className="visually-hidden">{t.status}</span></th>
              </tr>
            </thead>
            <tbody>
              {data.galleries.map((g) => (
                <tr key={g.id}>
                  <td><a href={`/${locale}/@${g.handle}`} target="_blank" rel="noreferrer">{g.title}</a><br /><span className="meta">@{g.handle}</span></td>
                  <td>{g.owner_name}</td>
                  <td className="num">{num.format(g.artworks)}</td>
                  <td className="num">{num.format(g.views)}</td>
                  <td>{t.visibilities[g.visibility]}</td>
                  <td className="nowrap">{when.format(new Date(g.created_at))}</td>
                  <td className="nowrap">
                    {g.visibility === 'private' ? (
                      <button className="btn" onClick={() => act(() => api.setGalleryVisibility(g.id, 'public'))}>{t.restore}</button>
                    ) : (
                      <button className="btn btn-quiet" onClick={() => act(() => api.setGalleryVisibility(g.id, 'private'))}>{t.takeDown}</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section id="comments" aria-labelledby="comments-title" className="admin-section">
        <h2 id="comments-title" className="studio-h2">{t.comments}</h2>
        <div className="table-wrap">
          <table className="data">
            <thead>
              <tr><th scope="col">{t.body}</th><th scope="col">{t.author}</th><th scope="col">{t.where}</th><th scope="col">{t.status}</th><th scope="col">{t.created}</th><th scope="col"><span className="visually-hidden">{t.hide}</span></th></tr>
            </thead>
            <tbody>
              {data.comments.map((c) => (
                <tr key={c.id}>
                  <td className="clip">{c.body}</td>
                  <td>{c.author_name}</td>
                  <td><a href={`/${locale}/@${c.gallery_handle}`} target="_blank" rel="noreferrer">@{c.gallery_handle}</a><br /><span className="meta">{c.artwork_title ?? t.guestbook}</span></td>
                  <td><span className="status" data-status={c.status}>{t.statuses[c.status]}</span></td>
                  <td className="nowrap">{when.format(new Date(c.created_at))}</td>
                  <td>
                    {c.status === 'hidden' ? (
                      <button className="btn btn-quiet" onClick={() => act(() => api.setCommentStatus(c.id, 'visible'))}>{t.show}</button>
                    ) : (
                      <button className="btn" onClick={() => act(() => api.setCommentStatus(c.id, 'hidden'))}>{t.hide}</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
