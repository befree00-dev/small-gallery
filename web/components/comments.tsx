import type { Locale } from '@/lib/i18n';
import { messages } from '@/lib/i18n';
import type { Comment } from '@/lib/types';

import { CommentBox } from './client';

/** Published comments (or guestbook entries) with a box to add one. */
export function Comments({
  comments,
  galleryId,
  artworkId,
  policy,
  locale,
}: {
  comments: Comment[];
  galleryId: string;
  artworkId: string | null;
  policy: 'open' | 'approve' | 'off';
  locale: Locale;
}) {
  const t = messages(locale);
  const dateFormat = new Intl.DateTimeFormat(locale === 'ko' ? 'ko-KR' : 'en-US', { dateStyle: 'medium' });
  return (
    <section className="section" aria-labelledby={`comments-${artworkId ?? 'guestbook'}`}>
      <h2 id={`comments-${artworkId ?? 'guestbook'}`}>{artworkId ? t.comments : t.guestbook}</h2>
      {policy === 'off' ? (
        <p className="notice">{t.commentsClosed}</p>
      ) : (
        <CommentBox galleryId={galleryId} artworkId={artworkId} locale={locale} />
      )}
      {comments.map((c) => (
        <article className="comment" key={c.id}>
          <div className="who">
            {c.profiles?.display_name ?? ''} · <time dateTime={c.created_at}>{dateFormat.format(new Date(c.created_at))}</time>
          </div>
          <p>{c.body}</p>
        </article>
      ))}
    </section>
  );
}
