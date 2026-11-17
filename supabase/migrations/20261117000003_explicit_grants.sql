-- Explicit table and function privileges for the app's two roles.
--
-- Older Supabase projects grant anon/authenticated everything on new public
-- tables by default; newer ones can grant nothing, which makes every query
-- fail with "permission denied". These grants make both cases behave the
-- same. They only add privileges; row-level security still decides which
-- rows each role sees, and the revokes in the first migration still hold.

grant usage on schema public to anon, authenticated;

-- Readable without signing in (RLS limits rows to published content).
grant select on
  public.profiles, public.galleries, public.rooms, public.artworks,
  public.artwork_rating_stats, public.comments, public.reserved_handles
to anon, authenticated;

-- Signed-in only.
grant select on
  public.ratings, public.notifications, public.view_stats, public.reports, public.blocked_authors
to authenticated;

grant insert on
  public.galleries, public.rooms, public.artworks, public.ratings,
  public.comments, public.blocked_authors, public.reports
to authenticated;

grant update on public.profiles, public.galleries, public.rooms, public.ratings to authenticated;
grant update (
  room_id, title, title_en, year, medium, size_text, note, note_en, tags, sort_order,
  visibility, is_featured, rating_enabled, watermark, image_path, thumb_path, width, height, exif
) on public.artworks to authenticated;
grant update (status) on public.comments to authenticated;
grant update (read_at) on public.notifications to authenticated;

grant delete on
  public.galleries, public.rooms, public.artworks, public.ratings, public.comments, public.blocked_authors
to authenticated;

-- Policies call these as the visiting role, so both roles must be able to run them.
grant execute on function public.is_gallery_owner(uuid) to anon, authenticated;
grant execute on function public.gallery_is_visible(uuid) to anon, authenticated;
grant execute on function public.artwork_is_visible(uuid) to anon, authenticated;
grant execute on function public.toggle_like(uuid, text) to anon, authenticated;
grant execute on function public.has_liked(uuid, text) to anon, authenticated;
grant execute on function public.record_view(uuid, uuid) to anon, authenticated;

-- Storage tables (Supabase normally grants these already).
grant usage on schema storage to anon, authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to anon, authenticated;
