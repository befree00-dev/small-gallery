import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { CopyLink, ProtectedImage, ViewTracker } from '@/components/client';
import { Comments } from '@/components/comments';
import { getArtworks, getComments, getGallery, getRooms, groupByRoom } from '@/lib/data';
import { isLocale, messages, parseHandle, pick, type Locale } from '@/lib/i18n';
import { imageUrl, siteHost, siteUrl } from '@/lib/supabase';

type Params = Promise<{ locale: string; handle: string }>;

async function load(params: Params) {
  const { locale: raw, handle: segment } = await params;
  const handle = parseHandle(segment);
  if (!isLocale(raw) || !handle || !decodeURIComponent(segment).startsWith('@')) notFound();
  const gallery = await getGallery(handle);
  if (!gallery) notFound();
  return { locale: raw as Locale, gallery };
}

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { locale, gallery } = await load(params);
  const artworks = await getArtworks(gallery.id);
  const cover = artworks.find((a) => a.is_featured) ?? artworks[0];
  const title = pick(gallery.title, gallery.title_en, locale);
  const description = pick(gallery.bio, gallery.bio_en, locale) || messages(locale).intro;
  return {
    title,
    description,
    alternates: { languages: { ko: `/ko/@${gallery.handle}`, en: `/en/@${gallery.handle}` } },
    openGraph: {
      title,
      description,
      type: 'website',
      url: `/${locale}/@${gallery.handle}`,
      images: cover ? [{ url: imageUrl(cover.image_path), width: cover.width, height: cover.height }] : undefined,
    },
    twitter: { card: cover ? 'summary_large_image' : 'summary' },
  };
}

export default async function GalleryPage({ params }: { params: Params }) {
  const { locale, gallery } = await load(params);
  const t = messages(locale);
  const [rooms, artworks, guestbook] = await Promise.all([
    getRooms(gallery.id),
    getArtworks(gallery.id),
    getComments(gallery.id, null),
  ]);
  const groups = groupByRoom(rooms, artworks);
  const other: Locale = locale === 'ko' ? 'en' : 'ko';

  return (
    <main className={`page theme-${gallery.theme}`}>
      <ViewTracker galleryId={gallery.id} />
      <div className="wrap">
        <header className="topbar">
          <span className="address">{siteHost}/@{gallery.handle}</span>
          <div className="actions">
            <a className="btn btn-quiet" href={`/${other}/@${gallery.handle}`} hrefLang={other}>{t.language}</a>
            <CopyLink url={`${siteUrl}/@${gallery.handle}`} locale={locale} />
          </div>
        </header>

        <section className="cover">
          {gallery.profiles?.display_name && <span className="artist">{gallery.profiles.display_name}</span>}
          <h1 className="title">{pick(gallery.title, gallery.title_en, locale)}</h1>
          {pick(gallery.bio, gallery.bio_en, locale) && <p className="bio">{pick(gallery.bio, gallery.bio_en, locale)}</p>}
          <span className="meta">{t.works(artworks.length)} · {t.rooms(groups.length)}</span>
        </section>

        {groups.length > 1 && (
          <nav className="room-nav" aria-label={t.rooms(groups.length)}>
            {groups.map(({ room, artworks: works }) => (
              <a className="chip" href={`#room-${room.id}`} key={room.id}>
                {pick(room.title, room.title_en, locale)} · {works.length}
              </a>
            ))}
          </nav>
        )}

        {groups.length === 0 && <p className="empty">{t.noWorks}</p>}

        {groups.map(({ room, artworks: works }, roomIndex) => (
          <section className="room" id={`room-${room.id}`} key={room.id} aria-labelledby={`room-title-${room.id}`}>
            <h2 id={`room-title-${room.id}`}>{pick(room.title, room.title_en, locale)}</h2>
            {pick(room.statement, room.statement_en, locale) && (
              <p className="statement">{pick(room.statement, room.statement_en, locale)}</p>
            )}
            <div className="masonry">
              {works.map((a, i) => {
                const title = pick(a.title, a.title_en, locale);
                return (
                  <Link className="work" href={`/${locale}/@${gallery.handle}/a/${a.id}`} key={a.id}>
                    <figure style={{ margin: 0 }}>
                      <div className="frame">
                        <ProtectedImage
                          src={imageUrl(a.thumb_path)}
                          alt={title}
                          width={a.width}
                          height={a.height}
                          priority={roomIndex === 0 && i < 4}
                        />
                      </div>
                      <figcaption>
                        <span>{title}</span>
                        <span className="likes" aria-label={`${t.like} ${a.like_count}`}>♡ {a.like_count}</span>
                      </figcaption>
                    </figure>
                  </Link>
                );
              })}
            </div>
          </section>
        ))}

        <Comments comments={guestbook} galleryId={gallery.id} artworkId={null} policy={gallery.comment_policy} locale={locale} />
      </div>
    </main>
  );
}
