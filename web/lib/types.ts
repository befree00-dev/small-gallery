// Row shapes from supabase/migrations. Only the columns the web gallery reads.

export type Audience = 'public' | 'unlisted' | 'private';

export interface Gallery {
  id: string;
  owner_id: string;
  handle: string;
  title: string;
  title_en: string | null;
  bio: string;
  bio_en: string | null;
  theme: 'white' | 'dark' | 'wood' | 'feed' | 'salon' | 'editorial';
  visibility: Audience;
  rating_enabled: boolean;
  comment_policy: 'open' | 'approve' | 'off';
  profiles: { display_name: string } | null;
}

export interface Room {
  id: string;
  title: string;
  title_en: string | null;
  statement: string;
  statement_en: string | null;
  sort_order: number;
}

export interface Artwork {
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
  is_featured: boolean;
  rating_enabled: boolean;
  image_path: string;
  thumb_path: string;
  width: number;
  height: number;
  exif: Record<string, string>;
  like_count: number;
  comment_count: number;
}

export interface RatingStats {
  rating_count: number;
  avg_composition: number | string | null;
  avg_color: number | string | null;
  avg_technique: number | string | null;
  avg_emotion: number | string | null;
}

export interface Comment {
  id: string;
  author_id: string;
  body: string;
  status: 'visible' | 'pending' | 'hidden';
  created_at: string;
  profiles: { display_name: string } | null;
}

export const criteria = ['composition', 'color', 'technique', 'emotion'] as const;
export type Criterion = (typeof criteria)[number];
export type Scores = Record<Criterion, number>;

/** Averages are shown to visitors from this many ratings. Mirrors the RLS policy. */
export const PUBLIC_RATING_THRESHOLD = 5;
