import { browserClient } from '../supabase';

// Operator statistics and moderation. Every call is an admin_* database
// function that checks the caller is an admin, so nothing here relies on the
// page hiding itself.

export interface Count {
  today: number;
  total: number;
}

export interface Overview {
  day: string;
  users: Count;
  galleries: Count;
  artworks: Count;
  comments: Count;
  ratings: Count;
  likes: Count;
  views: Count;
  pending_comments: number;
  open_reports: number;
}

export interface Day {
  day: string;
  users: number;
  galleries: number;
  artworks: number;
  comments: number;
  views: number;
}

export interface AdminGallery {
  id: string;
  handle: string;
  title: string;
  owner_name: string;
  visibility: 'public' | 'unlisted' | 'private';
  artworks: number;
  views: number;
  created_at: string;
}

export interface AdminComment {
  id: string;
  body: string;
  status: 'visible' | 'pending' | 'hidden';
  author_name: string;
  gallery_handle: string;
  artwork_title: string | null;
  created_at: string;
}

export interface AdminReport {
  id: string;
  target_type: 'comment' | 'artwork' | 'gallery';
  target_id: string;
  reason: string;
  detail: string;
  reporter_name: string;
  target_label: string | null;
  gallery_handle: string | null;
  created_at: string;
}

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await browserClient().rpc(name, args);
  if (error) {
    console.error('[supabase]', error.code, error.message);
    throw new Error(error.message);
  }
  return data as T;
}

/** Postgres bigint arrives as a number or a string; make it a number. */
const n = (v: unknown) => Number(v ?? 0);

export const isAdmin = () => rpc<boolean>('is_admin');

export async function overview(): Promise<Overview> {
  const o = await rpc<Record<string, unknown>>('admin_overview');
  const count = (k: string) => {
    const c = o[k] as { today: unknown; total: unknown };
    return { today: n(c.today), total: n(c.total) };
  };
  return {
    day: String(o.day),
    users: count('users'),
    galleries: count('galleries'),
    artworks: count('artworks'),
    comments: count('comments'),
    ratings: count('ratings'),
    likes: count('likes'),
    views: count('views'),
    pending_comments: n(o.pending_comments),
    open_reports: n(o.open_reports),
  };
}

export async function daily(days = 30): Promise<Day[]> {
  const rows = await rpc<Record<string, unknown>[]>('admin_daily', { p_days: days });
  return rows.map((r) => ({
    day: String(r.day),
    users: n(r.users),
    galleries: n(r.galleries),
    artworks: n(r.artworks),
    comments: n(r.comments),
    views: n(r.views),
  }));
}

export async function galleries(limit = 50): Promise<AdminGallery[]> {
  const rows = await rpc<AdminGallery[]>('admin_galleries', { p_limit: limit });
  return rows.map((g) => ({ ...g, artworks: n(g.artworks), views: n(g.views) }));
}

export const comments = (limit = 50) => rpc<AdminComment[]>('admin_comments', { p_limit: limit });
export const reports = () => rpc<AdminReport[]>('admin_reports');

export const setCommentStatus = (id: string, status: 'visible' | 'hidden') =>
  rpc<void>('admin_set_comment_status', { p_comment_id: id, p_status: status });
export const setGalleryVisibility = (id: string, visibility: 'public' | 'private') =>
  rpc<void>('admin_set_gallery_visibility', { p_gallery_id: id, p_visibility: visibility });
export const resolveReport = (id: string, status: 'actioned' | 'dismissed') =>
  rpc<void>('admin_resolve_report', { p_report_id: id, p_status: status });
