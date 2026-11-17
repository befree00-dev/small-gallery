import { cache } from 'react';

import { serverClient } from './supabase';
import type { Artwork, Comment, Gallery, RatingStats, Room } from './types';

const galleryColumns = 'id, owner_id, handle, title, title_en, bio, bio_en, theme, rating_enabled, comment_policy, profiles(display_name)';

// cache(): generateMetadata and the page share one query per request.
export const getGallery = cache(async (handle: string): Promise<Gallery | null> => {
  const { data, error } = await serverClient().from('galleries').select(galleryColumns).eq('handle', handle).maybeSingle();
  if (error) throw error;
  return data as unknown as Gallery | null;
});

export const getRooms = cache(async (galleryId: string): Promise<Room[]> => {
  const { data, error } = await serverClient()
    .from('rooms')
    .select('id, title, title_en, statement, statement_en, sort_order')
    .eq('gallery_id', galleryId)
    .order('sort_order')
    .order('created_at');
  if (error) throw error;
  return data ?? [];
});

export const getArtworks = cache(async (galleryId: string): Promise<Artwork[]> => {
  const { data, error } = await serverClient()
    .from('artworks')
    .select('*')
    .eq('gallery_id', galleryId)
    .order('sort_order')
    .order('created_at');
  if (error) throw error;
  return (data ?? []) as Artwork[];
});

export const getArtwork = cache(async (id: string): Promise<Artwork | null> => {
  if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
  const { data, error } = await serverClient().from('artworks').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data as Artwork | null;
});

/** Only returned once there are enough ratings (RLS). */
export async function getRatingStats(artworkId: string): Promise<RatingStats | null> {
  const { data, error } = await serverClient()
    .from('artwork_rating_stats')
    .select('rating_count, avg_composition, avg_color, avg_technique, avg_emotion')
    .eq('artwork_id', artworkId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function getComments(galleryId: string, artworkId: string | null): Promise<Comment[]> {
  let q = serverClient()
    .from('comments')
    .select('id, author_id, body, status, created_at, profiles(display_name)')
    .eq('gallery_id', galleryId)
    .eq('status', 'visible');
  q = artworkId ? q.eq('artwork_id', artworkId) : q.is('artwork_id', null);
  const { data, error } = await q.order('created_at', { ascending: false }).limit(100);
  if (error) throw error;
  return (data ?? []) as unknown as Comment[];
}

/** Puts each work in the room it hangs in, rooms in order, empty rooms dropped. */
export function groupByRoom(rooms: Room[], artworks: Artwork[]): { room: Room; artworks: Artwork[] }[] {
  return rooms
    .map((room) => ({ room, artworks: artworks.filter((a) => a.room_id === room.id) }))
    .filter((g) => g.artworks.length > 0);
}

export function average(value: number | string | null): number {
  if (value === null) return 0;
  return typeof value === 'number' ? value : Number(value);
}
