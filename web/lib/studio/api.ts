import type { PostgrestError } from '@supabase/supabase-js';

import { browserClient } from '../supabase';
import { ImageError, processImage } from './image';

// The artist's side, from the browser. Same tables and rules as the app;
// row-level security decides what each call may touch.

export type Audience = 'public' | 'unlisted' | 'private';
export type Policy = 'open' | 'approve' | 'off';
export type Theme = 'white' | 'dark' | 'wood';
export type Field = 'painting' | 'photo' | 'illustration' | 'other';

export interface StudioGallery {
  id: string;
  owner_id: string;
  handle: string;
  title: string;
  title_en: string | null;
  bio: string;
  bio_en: string | null;
  field: Field;
  theme: Theme;
  visibility: Audience;
  rating_enabled: boolean;
  comment_policy: Policy;
}

export interface StudioRoom {
  id: string;
  gallery_id: string;
  title: string;
  title_en: string | null;
  statement: string;
  statement_en: string | null;
  sort_order: number;
  visibility: Audience;
  artworks: { count: number }[];
}

export interface StudioArtwork {
  id: string;
  gallery_id: string;
  room_id: string;
  title: string;
  title_en: string | null;
  year: number | null;
  medium: string;
  size_text: string;
  note: string;
  note_en: string | null;
  sort_order: number;
  visibility: Audience;
  is_featured: boolean;
  rating_enabled: boolean;
  image_path: string;
  thumb_path: string;
  width: number;
  height: number;
  like_count: number;
  comment_count: number;
}

export interface StudioComment {
  id: string;
  gallery_id: string;
  artwork_id: string | null;
  author_id: string;
  body: string;
  status: 'visible' | 'pending' | 'hidden';
  created_at: string;
  profiles: { display_name: string } | null;
  artworks: { title: string } | null;
}

export interface StudioNotification {
  id: string;
  kind: 'comment' | 'comment_pending' | 'rating' | 'guestbook';
  artwork_id: string | null;
  read_at: string | null;
  created_at: string;
  artworks: { title: string } | null;
}

export interface Draft {
  file: File;
  title: string;
  titleEn: string;
  sizeText: string;
  note: string;
  noteEn: string;
}

export interface SharedDetails {
  roomId: string;
  year: number | null;
  medium: string;
  watermark: boolean;
  ratingEnabled: boolean;
}

/** handle_taken · handle_reserved · quota_exceeded · file_too_large · unsupported_image · unknown */
export class StudioError extends Error {
  constructor(public code: string, detail?: string) {
    super(detail ?? code);
  }
}

function fail(error: PostgrestError | { message: string; statusCode?: string } | null): never {
  const message = error?.message ?? '';
  const code = (error as PostgrestError | null)?.code;
  console.error('[supabase]', code ?? '', message, error);
  if (message.includes('handle_reserved')) throw new StudioError('handle_reserved');
  if (message.includes('artwork_quota_exceeded')) throw new StudioError('quota_exceeded');
  if (code === '23505' && message.includes('handle')) throw new StudioError('handle_taken');
  throw new StudioError('unknown', message);
}

const db = () => browserClient();
const blank = (s: string | null | undefined) => (s && s.trim() ? s.trim() : null);

// galleries and profiles are joined two ways (owner, and blocked_authors);
// embeds name the foreign key they follow.
const commentAuthor = 'profiles!comments_author_id_fkey(display_name)';

export async function myGallery(userId: string): Promise<StudioGallery | null> {
  const { data, error } = await db().from('galleries').select('*').eq('owner_id', userId).maybeSingle();
  if (error) fail(error);
  return data as StudioGallery | null;
}

export async function myPlan(userId: string): Promise<'free' | 'plus'> {
  const { data } = await db().from('profiles').select('plan').eq('id', userId).maybeSingle();
  return (data?.plan as 'free' | 'plus' | undefined) ?? 'free';
}

export async function isHandleAvailable(handle: string): Promise<boolean> {
  const [reserved, taken] = await Promise.all([
    db().from('reserved_handles').select('handle').eq('handle', handle).maybeSingle(),
    db().from('galleries').select('id').eq('handle', handle).maybeSingle(),
  ]);
  return !reserved.data && !taken.data;
}

export async function createGallery(input: {
  ownerId: string;
  handle: string;
  title: string;
  field: Field;
  theme: Theme;
  firstRoomTitle: string;
}): Promise<StudioGallery> {
  const { data, error } = await db()
    .from('galleries')
    .insert({ owner_id: input.ownerId, handle: input.handle, title: input.title, field: input.field, theme: input.theme })
    .select('*')
    .single();
  if (error) fail(error);
  await createRoom(data.id, input.firstRoomTitle, 0);
  return data as StudioGallery;
}

export async function updateGallery(g: StudioGallery): Promise<void> {
  const { error } = await db()
    .from('galleries')
    .update({
      title: g.title.trim(),
      title_en: blank(g.title_en),
      bio: g.bio.trim(),
      bio_en: blank(g.bio_en),
      theme: g.theme,
      visibility: g.visibility,
      rating_enabled: g.rating_enabled,
      comment_policy: g.comment_policy,
    })
    .eq('id', g.id);
  if (error) fail(error);
}

export async function rooms(galleryId: string): Promise<StudioRoom[]> {
  const { data, error } = await db()
    .from('rooms')
    .select('*, artworks(count)')
    .eq('gallery_id', galleryId)
    .order('sort_order')
    .order('created_at');
  if (error) fail(error);
  return data as StudioRoom[];
}

export async function createRoom(galleryId: string, title: string, sortOrder: number): Promise<StudioRoom> {
  const { data, error } = await db()
    .from('rooms')
    .insert({ gallery_id: galleryId, title, sort_order: sortOrder })
    .select('*, artworks(count)')
    .single();
  if (error) fail(error);
  return data as StudioRoom;
}

export async function updateRoom(r: StudioRoom): Promise<void> {
  const { error } = await db()
    .from('rooms')
    .update({ title: r.title.trim(), statement: r.statement.trim(), visibility: r.visibility })
    .eq('id', r.id);
  if (error) fail(error);
}

export async function deleteRoom(roomId: string): Promise<void> {
  const works = await artworks(roomId);
  const { error } = await db().from('rooms').delete().eq('id', roomId);
  if (error) fail(error);
  await removeFiles(works);
}

export async function artworks(roomId: string): Promise<StudioArtwork[]> {
  const { data, error } = await db()
    .from('artworks')
    .select('*')
    .eq('room_id', roomId)
    .order('sort_order')
    .order('created_at');
  if (error) fail(error);
  return data as StudioArtwork[];
}

export async function artworkCount(galleryId: string): Promise<number> {
  const { count, error } = await db().from('artworks').select('id', { count: 'exact', head: true }).eq('gallery_id', galleryId);
  if (error) fail(error);
  return count ?? 0;
}

export async function uploadArtwork(gallery: StudioGallery, ownerId: string, draft: Draft, shared: SharedDetails): Promise<void> {
  let processed;
  try {
    processed = await processImage(draft.file, shared.watermark ? gallery.handle : undefined);
  } catch (e) {
    if (e instanceof ImageError) throw new StudioError(e.code);
    throw e;
  }

  const id = crypto.randomUUID();
  const displayPath = `${ownerId}/${id}/display.jpg`;
  const thumbPath = `${ownerId}/${id}/thumb.jpg`;
  const originalPath = `${ownerId}/${id}/original`;
  const bucket = db().storage.from('artworks');
  const jpeg = { contentType: 'image/jpeg', cacheControl: '31536000', upsert: false };

  for (const [path, blob] of [
    [displayPath, processed.display],
    [thumbPath, processed.thumbnail],
  ] as const) {
    const { error } = await bucket.upload(path, blob, jpeg);
    if (error) fail(error);
  }
  // The original stays private to the artist.
  await db().storage.from('originals').upload(originalPath, draft.file, { contentType: draft.file.type || undefined, upsert: false });

  const existing = await artworks(shared.roomId);
  const { error } = await db().from('artworks').insert({
    id,
    gallery_id: gallery.id,
    room_id: shared.roomId,
    title: draft.title.trim(),
    title_en: blank(draft.titleEn),
    year: shared.year,
    medium: shared.medium,
    size_text: draft.sizeText.trim(),
    note: draft.note.trim(),
    note_en: blank(draft.noteEn),
    watermark: shared.watermark,
    rating_enabled: shared.ratingEnabled,
    sort_order: existing.length,
    image_path: displayPath,
    thumb_path: thumbPath,
    width: processed.width,
    height: processed.height,
    exif: processed.exif,
  });
  if (error) {
    await bucket.remove([displayPath, thumbPath]);
    await db().storage.from('originals').remove([originalPath]);
    fail(error);
  }
}

export async function updateArtwork(a: StudioArtwork): Promise<void> {
  const { error } = await db()
    .from('artworks')
    .update({
      title: a.title.trim(),
      title_en: blank(a.title_en),
      year: a.year,
      size_text: a.size_text.trim(),
      note: a.note.trim(),
      note_en: blank(a.note_en),
      visibility: a.visibility,
      is_featured: a.is_featured,
      rating_enabled: a.rating_enabled,
    })
    .eq('id', a.id);
  if (error) fail(error);
}

export async function reorderArtworks(inOrder: StudioArtwork[]): Promise<void> {
  for (let i = 0; i < inOrder.length; i++) {
    if (inOrder[i].sort_order !== i) {
      const { error } = await db().from('artworks').update({ sort_order: i }).eq('id', inOrder[i].id);
      if (error) fail(error);
    }
  }
}

export async function deleteArtwork(a: StudioArtwork): Promise<void> {
  const { error } = await db().from('artworks').delete().eq('id', a.id);
  if (error) fail(error);
  await removeFiles([a]);
}

async function removeFiles(works: StudioArtwork[]) {
  if (works.length === 0) return;
  await db().storage.from('artworks').remove(works.flatMap((a) => [a.image_path, a.thumb_path]));
  await db().storage.from('originals').remove(works.map((a) => a.image_path.replace('display.jpg', 'original')));
}

export async function moderationQueue(galleryId: string): Promise<StudioComment[]> {
  const { data, error } = await db()
    .from('comments')
    .select(`*, ${commentAuthor}, artworks(title)`)
    .eq('gallery_id', galleryId)
    .neq('status', 'hidden')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) fail(error);
  return data as unknown as StudioComment[];
}

export async function setCommentStatus(id: string, status: 'visible' | 'hidden'): Promise<void> {
  const { error } = await db().from('comments').update({ status }).eq('id', id);
  if (error) fail(error);
}

export async function blockAuthor(galleryId: string, authorId: string): Promise<void> {
  const { error } = await db().from('blocked_authors').upsert({ gallery_id: galleryId, author_id: authorId });
  if (error) fail(error);
}

export async function notifications(): Promise<StudioNotification[]> {
  const { data, error } = await db()
    .from('notifications')
    .select('*, artworks(title)')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) fail(error);
  return data as StudioNotification[];
}

export async function markNotificationsRead(userId: string): Promise<void> {
  await db().from('notifications').update({ read_at: new Date().toISOString() }).eq('recipient_id', userId).is('read_at', null);
}

export async function summary(galleryId: string): Promise<{ views: number; likes: number; pending: number }> {
  const since = new Date(Date.now() - 6 * 864e5).toISOString().slice(0, 10);
  const [views, likes, pending] = await Promise.all([
    db().from('view_stats').select('views').eq('gallery_id', galleryId).gte('day', since),
    db().from('artworks').select('like_count').eq('gallery_id', galleryId),
    db().from('comments').select('id', { count: 'exact', head: true }).eq('gallery_id', galleryId).eq('status', 'pending'),
  ]);
  return {
    views: (views.data ?? []).reduce((s, r) => s + (r.views as number), 0),
    likes: (likes.data ?? []).reduce((s, r) => s + (r.like_count as number), 0),
    pending: pending.count ?? 0,
  };
}
