import Link from 'next/link';
import type { CSSProperties } from 'react';

import { ProtectedImage } from '@/components/client';
import type { Locale, Messages } from '@/lib/i18n';
import { pick } from '@/lib/i18n';
import { imageUrl } from '@/lib/supabase';
import type { Artwork, Gallery, Room } from '@/lib/types';

// Layouts for the themes that change more than color. Each gets the same
// data; the default (white / dark / wood) layout lives in the page itself.

export interface LayoutProps {
  gallery: Gallery;
  groups: { room: Room; artworks: Artwork[] }[];
  locale: Locale;
  t: Messages;
  /** Feed only: the room picked from the highlights row, if any. */
  roomFilter?: string;
}

const href = (locale: Locale, g: Gallery, a: Artwork) => `/${locale}/@${g.handle}/a/${a.id}`;

/** The work's proportions as a CSS variable, so its box is reserved before the image loads. */
const ratio = (a: Artwork) => ({ '--ar': `${a.width} / ${a.height}` }) as CSSProperties;

/** Social-profile style: round cover, counts row, room highlights, square 3-column grid. */
export function FeedLayout({ gallery, groups, locale, t, roomFilter }: LayoutProps) {
  const all = groups.flatMap((g) => g.artworks);
  const shown = roomFilter ? groups.find((g) => g.room.id === roomFilter)?.artworks ?? all : all;
  const cover = all.find((a) => a.is_featured) ?? all[0];
  const likes = all.reduce((s, a) => s + a.like_count, 0);
  const num = new Intl.NumberFormat(locale === 'ko' ? 'ko-KR' : 'en-US', { notation: 'compact' });
  const bio = pick(gallery.bio, gallery.bio_en, locale);
  const base = `/${locale}/@${gallery.handle}`;

  return (
    <div className="feed">
      <header className="feed-head">
        <div className="feed-avatar">
          {cover ? <ProtectedImage src={imageUrl(cover.thumb_path)} alt="" width={cover.width} height={cover.height} priority /> : null}
        </div>
        <div className="feed-info">
          <h1 className="feed-handle">{gallery.handle}</h1>
          <ul className="feed-stats">
            <li><strong>{num.format(all.length)}</strong> {t.statWorks}</li>
            <li><strong>{num.format(groups.length)}</strong> {t.statRooms}</li>
            <li><strong>{num.format(likes)}</strong> {t.statLikes}</li>
          </ul>
          <p className="feed-name">{pick(gallery.title, gallery.title_en, locale)}</p>
          {gallery.profiles?.display_name && <p className="feed-artist">{gallery.profiles.display_name}</p>}
          {bio && <p className="feed-bio">{bio}</p>}
        </div>
      </header>

      {groups.length > 1 && (
        <nav className="feed-highlights" aria-label={t.rooms(groups.length)}>
          <Link href={base} className="feed-highlight" aria-current={!roomFilter ? 'page' : undefined} scroll={false}>
            <span className="feed-ring feed-ring-all" aria-hidden="true">{all.length}</span>
            <span>{t.all}</span>
          </Link>
          {groups.map(({ room, artworks }) => (
            <Link key={room.id} href={`${base}?room=${room.id}`} className="feed-highlight" aria-current={roomFilter === room.id ? 'page' : undefined} scroll={false}>
              <span className="feed-ring">
                <ProtectedImage src={imageUrl(artworks[0].thumb_path)} alt="" width={artworks[0].width} height={artworks[0].height} />
              </span>
              <span>{pick(room.title, room.title_en, locale)}</span>
            </Link>
          ))}
        </nav>
      )}

      <div className="feed-tab"><span>{t.statWorks}</span></div>

      {shown.length === 0 ? (
        <p className="empty">{t.noWorks}</p>
      ) : (
        <div className="feed-grid">
          {shown.map((a, i) => {
            const title = pick(a.title, a.title_en, locale);
            return (
              <Link key={a.id} href={href(locale, gallery, a)} className="feed-cell" aria-label={`${title} · ${t.like} ${a.like_count}`}>
                <ProtectedImage src={imageUrl(a.thumb_path)} alt={title} width={a.width} height={a.height} priority={i < 6} />
                <span className="feed-overlay" aria-hidden="true">
                  <svg viewBox="0 0 24 24" width="20" height="20"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z" /></svg>
                  {a.like_count}
                </span>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}

/** Classic museum wall: framed and matted works, each with a wall label. */
export function SalonLayout({ gallery, groups, locale, t }: LayoutProps) {
  const bio = pick(gallery.bio, gallery.bio_en, locale);
  return (
    <div className="salon">
      <header className="salon-head">
        <p className="salon-kicker">{t.exhibition}</p>
        <h1>{pick(gallery.title, gallery.title_en, locale)}</h1>
        {gallery.profiles?.display_name && <p className="salon-artist">{gallery.profiles.display_name}</p>}
        <hr />
        {bio && <p className="salon-bio">{bio}</p>}
      </header>
      {groups.length === 0 && <p className="empty">{t.noWorks}</p>}
      {groups.map(({ room, artworks }) => (
        <section key={room.id} id={`room-${room.id}`} className="salon-room" aria-labelledby={`salon-${room.id}`}>
          <h2 id={`salon-${room.id}`}>{pick(room.title, room.title_en, locale)}</h2>
          {pick(room.statement, room.statement_en, locale) && <p className="salon-statement">{pick(room.statement, room.statement_en, locale)}</p>}
          <div className="salon-wall">
            {artworks.map((a, i) => {
              const title = pick(a.title, a.title_en, locale);
              return (
                <Link key={a.id} href={href(locale, gallery, a)} className="salon-piece" style={ratio(a)}>
                  <figure>
                    <div className="salon-frame">
                      <div className="salon-mat">
                        <ProtectedImage src={imageUrl(a.image_path)} alt={title} width={a.width} height={a.height} priority={i < 2} />
                      </div>
                    </div>
                    <figcaption className="salon-label">
                      <strong>{title}</strong>
                      <span>{[gallery.profiles?.display_name, a.year].filter(Boolean).join(', ')}</span>
                      <span>{[a.medium, a.size_text].filter(Boolean).join(' · ')}</span>
                    </figcaption>
                  </figure>
                </Link>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}

/** Art-magazine spread: oversized title, numbered works in a varied grid. */
export function EditorialLayout({ gallery, groups, locale, t }: LayoutProps) {
  const bio = pick(gallery.bio, gallery.bio_en, locale);
  // A repeating rhythm of wide and narrow pieces on a 12-column grid.
  const spans = ['span-12', 'span-7', 'span-5', 'span-5', 'span-7', 'span-4', 'span-4', 'span-4'];
  let n = 0;
  return (
    <div className="editorial">
      <header className="ed-head">
        <h1>{pick(gallery.title, gallery.title_en, locale)}</h1>
        <div className="ed-deck">
          {gallery.profiles?.display_name && <p className="ed-artist">{gallery.profiles.display_name}</p>}
          {bio && <p className="ed-bio">{bio}</p>}
        </div>
      </header>
      {groups.length === 0 && <p className="empty">{t.noWorks}</p>}
      {groups.map(({ room, artworks }, ri) => (
        <section key={room.id} id={`room-${room.id}`} className="ed-chapter" aria-labelledby={`ed-${room.id}`}>
          <h2 id={`ed-${room.id}`}>
            <span className="ed-chapter-no">{String(ri + 1).padStart(2, '0')}</span> {pick(room.title, room.title_en, locale)}
          </h2>
          {pick(room.statement, room.statement_en, locale) && <p className="ed-statement">{pick(room.statement, room.statement_en, locale)}</p>}
          <div className="ed-grid">
            {artworks.map((a, i) => {
              // The rhythm runs across the whole gallery, so rooms don't all open with a full-width piece.
              const span = spans[n % spans.length];
              n += 1;
              const title = pick(a.title, a.title_en, locale);
              const wide = span === 'span-12' || span === 'span-7';
              return (
                <Link key={a.id} href={href(locale, gallery, a)} className={`ed-piece ${span}`} style={ratio(a)}>
                  <figure>
                    <ProtectedImage src={imageUrl(wide ? a.image_path : a.thumb_path)} alt={title} width={a.width} height={a.height} priority={ri === 0 && i < 2} />
                    <figcaption>
                      <span className="ed-no">{String(n).padStart(2, '0')}</span>
                      <em>{title}</em>
                      {a.year && <span className="ed-year">{a.year}</span>}
                    </figcaption>
                  </figure>
                </Link>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}
