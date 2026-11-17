import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ArrowKeyNav, LikeButton, ProtectedImage, RatingForm, ViewTracker } from '@/components/client';
import { Comments } from '@/components/comments';
import { average, getArtwork, getArtworks, getComments, getGallery, getRatingStats, getRooms, groupByRoom, neighbors } from '@/lib/data';
import { isLocale, messages, parseHandle, pick, type Locale } from '@/lib/i18n';
import { imageUrl } from '@/lib/supabase';
import { criteria, PUBLIC_RATING_THRESHOLD } from '@/lib/types';

type Params = Promise<{ locale: string; handle: string; artworkId: string }>;

async function load(params: Params) {
  const { locale: raw, handle: segment, artworkId } = await params;
  const handle = parseHandle(segment);
  if (!isLocale(raw) || !handle) notFound();
  const [gallery, artwork] = await Promise.all([getGallery(handle), getArtwork(artworkId)]);
  if (!gallery || !artwork || artwork.gallery_id !== gallery.id) notFound();
  return { locale: raw as Locale, gallery, artwork };
}

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { locale, gallery, artwork } = await load(params);
  const title = pick(artwork.title, artwork.title_en, locale);
  const description = pick(artwork.note, artwork.note_en, locale) || pick(gallery.title, gallery.title_en, locale);
  return {
    title: `${title} · ${pick(gallery.title, gallery.title_en, locale)}`,
    description,
    alternates: {
      languages: { ko: `/ko/@${gallery.handle}/a/${artwork.id}`, en: `/en/@${gallery.handle}/a/${artwork.id}` },
    },
    openGraph: {
      title,
      description,
      type: 'article',
      images: [{ url: imageUrl(artwork.image_path), width: artwork.width, height: artwork.height }],
    },
    twitter: { card: 'summary_large_image' },
  };
}

export default async function ArtworkPage({ params }: { params: Params }) {
  const { locale, gallery, artwork: a } = await load(params);
  const t = messages(locale);
  const [stats, comments, rooms, works] = await Promise.all([
    getRatingStats(a.id),
    getComments(gallery.id, a.id),
    getRooms(gallery.id),
    getArtworks(gallery.id),
  ]);
  // The gallery's hanging order: rooms in order, works in order within each room.
  const sequence = groupByRoom(rooms, works).flatMap((g) => g.artworks);
  const { index, prev, next } = neighbors(sequence, a.id);
  const room = rooms.find((r) => r.id === a.room_id);
  const hrefOf = (w: { id: string } | null) => (w ? `/${locale}/@${gallery.handle}/a/${w.id}` : null);
  const title = pick(a.title, a.title_en, locale);
  const note = pick(a.note, a.note_en, locale);
  const details = [gallery.profiles?.display_name, a.year, a.medium, a.size_text].filter(Boolean).join(' · ');
  const exif = [a.exif.camera, a.exif.lens, a.exif.focal, a.exif.aperture, a.exif.shutter, a.exif.iso && `ISO ${a.exif.iso}`]
    .filter(Boolean)
    .join(' · ');
  const ratingsOpen = gallery.rating_enabled && a.rating_enabled;

  return (
    <main className="page theme-dark viewer">
      <ViewTracker galleryId={gallery.id} artworkId={a.id} />
      <div className="wrap">
        <header className="topbar">
          <Link className="btn btn-quiet" href={`/${locale}/@${gallery.handle}#room-${a.room_id}`}>← {t.back}</Link>
          <span className="address">{pick(gallery.title, gallery.title_en, locale)}</span>
        </header>

        <ArrowKeyNav prevHref={hrefOf(prev)} nextHref={hrefOf(next)} />
        <div className="stage">
          {prev ? (
            <Link className="nav-arrow" href={hrefOf(prev)!} rel="prev" aria-label={t.prevWork(pick(prev.title, prev.title_en, locale))}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7" /></svg>
            </Link>
          ) : (
            <span className="nav-arrow" aria-hidden="true" data-disabled="true">
              <svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7" /></svg>
            </span>
          )}
          <ProtectedImage src={imageUrl(a.image_path)} alt={title} width={a.width} height={a.height} priority />
          {next ? (
            <Link className="nav-arrow" href={hrefOf(next)!} rel="next" aria-label={t.nextWork(pick(next.title, next.title_en, locale))}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 5l7 7-7 7" /></svg>
            </Link>
          ) : (
            <span className="nav-arrow" aria-hidden="true" data-disabled="true">
              <svg viewBox="0 0 24 24"><path d="M9 5l7 7-7 7" /></svg>
            </span>
          )}
        </div>
        {index >= 0 && (
          <p className="position meta">
            {t.position(index + 1, sequence.length)}
            {room && ` · ${pick(room.title, room.title_en, locale)}`}
          </p>
        )}

        <div className="info">
          <h1>{title}</h1>
          {details && <p className="meta" style={{ margin: '6px 0 0' }}>{details}</p>}
          {exif && <p className="meta" style={{ margin: '2px 0 0' }}>{exif}</p>}
          {note && <p className="note">{note}</p>}

          <div className="reactions">
            <LikeButton artworkId={a.id} initialCount={a.like_count} locale={locale} />
            <span className="meta">{t.comments} {a.comment_count}</span>
          </div>

          <section className="panel" aria-labelledby="rate-title">
            <h2 id="rate-title">{t.rateThis}</h2>
            {stats && stats.rating_count >= PUBLIC_RATING_THRESHOLD && (
              <div style={{ marginBottom: 12 }}>
                <p className="notice" style={{ margin: '0 0 6px' }}>{t.averages(stats.rating_count)}</p>
                {criteria.map((c) => {
                  const value = average(stats[`avg_${c}`]);
                  return (
                    <div className="bar-row" key={c}>
                      <span>{t.criteria[c]}</span>
                      <span className="bar" role="img" aria-label={`${t.criteria[c]} ${value.toFixed(1)} / 5`}>
                        <span style={{ width: `${(value / 5) * 100}%` }} />
                      </span>
                      <span className="num">{value.toFixed(1)}</span>
                    </div>
                  );
                })}
              </div>
            )}
            {ratingsOpen ? (
              <RatingForm artworkId={a.id} ownerId={gallery.owner_id} locale={locale} />
            ) : (
              <p className="notice">{t.ratingsOff}</p>
            )}
          </section>

          <Comments comments={comments} galleryId={gallery.id} artworkId={a.id} policy={gallery.comment_policy} locale={locale} />
        </div>
      </div>
    </main>
  );
}
