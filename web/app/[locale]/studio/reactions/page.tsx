'use client';

import { useEffect } from 'react';

import { useStudio } from '@/components/studio/shell';
import { Loading, useLoad } from '@/components/studio/ui';
import * as api from '@/lib/studio/api';

export default function ReactionsPage() {
  const { t, locale, gallery, userId } = useStudio();
  const summary = useLoad(() => api.summary(gallery.id), [gallery.id]);
  const queue = useLoad(() => api.moderationQueue(gallery.id), [gallery.id]);
  const notes = useLoad(() => api.notifications(), []);
  const dateFormat = new Intl.DateTimeFormat(locale === 'ko' ? 'ko-KR' : 'en-US', { dateStyle: 'medium', timeStyle: 'short' });

  // Opening this page counts as reading the notifications.
  useEffect(() => {
    api.markNotificationsRead(userId);
  }, [userId]);

  async function moderate(c: api.StudioComment, status: 'visible' | 'hidden') {
    await api.setCommentStatus(c.id, status);
    queue.reload();
    summary.reload();
  }

  async function block(c: api.StudioComment) {
    await api.blockAuthor(gallery.id, c.author_id);
    await moderate(c, 'hidden');
  }

  const ratings = (notes.data ?? []).filter((n) => n.kind === 'rating');

  return (
    <>
      <h1 className="title" style={{ fontSize: 30, marginBottom: 16 }}>{t.reactionsTitle}</h1>
      <dl className="stats">
        <div><dt>{t.viewsWeek}</dt><dd>{summary.data?.views ?? '–'}</dd></div>
        <div><dt>{t.likes}</dt><dd>{summary.data?.likes ?? '–'}</dd></div>
        <div><dt>{t.pending}</dt><dd>{summary.data?.pending ?? '–'}</dd></div>
      </dl>

      <section aria-labelledby="queue-title">
        <h2 id="queue-title" className="studio-h2">{t.comments}</h2>
        <Loading state={queue} t={t}>
          {(list) =>
            list.length === 0 && ratings.length === 0 ? (
              <p className="notice">{t.noReactions}</p>
            ) : (
              list.map((c) => (
                <article key={c.id} className="comment" data-pending={c.status === 'pending'}>
                  <div className="who">
                    {c.status === 'pending' && <strong className="pending">{t.pending} · </strong>}
                    {c.artwork_id ? c.artworks?.title : t.guestbook} · {dateFormat.format(new Date(c.created_at))}
                  </div>
                  <p><strong>{c.profiles?.display_name}</strong> {c.body}</p>
                  <div className="row" style={{ marginTop: 8 }}>
                    {c.status === 'pending' && <button className="btn btn-primary" onClick={() => moderate(c, 'visible')}>{t.approve}</button>}
                    <button className="btn" onClick={() => moderate(c, 'hidden')}>{t.hide}</button>
                    <button className="btn btn-quiet" style={{ marginLeft: 'auto' }} onClick={() => block(c)}>{t.block}</button>
                  </div>
                </article>
              ))
            )
          }
        </Loading>
      </section>

      {ratings.length > 0 && (
        <section aria-labelledby="ratings-title" style={{ marginTop: 24 }}>
          <h2 id="ratings-title" className="studio-h2">{t.recentRatings}</h2>
          <ul className="room-list">
            {ratings.map((n) => (
              <li key={n.id} className="room-row">
                <span>☆ {t.newRating(n.artworks?.title ?? '')}</span>
                <span className="meta">{dateFormat.format(new Date(n.created_at))}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  );
}
