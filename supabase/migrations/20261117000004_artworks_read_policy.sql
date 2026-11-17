-- Fix: uploading an artwork failed with
--   new row violates row-level security policy for table "artworks"
--
-- The app inserts and reads the new row back in one statement
-- (INSERT … RETURNING). The read policy called artwork_is_visible(id), which
-- looks the artwork up again; inside the same statement the new row is not
-- visible yet, so the check failed. Judge from the row's own columns instead.

create or replace function public.room_is_public(rid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rooms r
    join public.galleries g on g.id = r.gallery_id
    where r.id = rid and r.visibility <> 'private' and g.visibility <> 'private'
  );
$$;

grant execute on function public.room_is_public(uuid) to anon, authenticated;

drop policy if exists artworks_read on public.artworks;
create policy artworks_read on public.artworks for select
  using (
    public.is_gallery_owner(gallery_id)
    or (visibility <> 'private' and public.room_is_public(room_id))
  );
