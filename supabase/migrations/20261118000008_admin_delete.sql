-- Admin: delete a gallery or a user, with an audit log of admin actions.
--
-- Deleting cascades through the schema's foreign keys (rooms, artworks,
-- comments, ratings, likes, notifications, view stats). Image files live in
-- Storage, which SQL may not delete directly, so the delete functions return
-- the file paths and the admin page removes them through the Storage API.

-- Audit log ---------------------------------------------------------------------

create table public.admin_actions (
  id         uuid primary key default gen_random_uuid(),
  admin_id   uuid references auth.users (id) on delete set null,
  admin_email text not null default '',
  action     text not null,
  target     text not null default '',
  detail     jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.admin_actions enable row level security;
revoke all on public.admin_actions from anon, authenticated;

create or replace function public.log_admin_action(p_action text, p_target text, p_detail jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.admin_actions (admin_id, admin_email, action, target, detail)
  select auth.uid(), coalesce((select email from auth.users where id = auth.uid()), ''), p_action, p_target, p_detail;
$$;
revoke execute on function public.log_admin_action(text, text, jsonb) from public, anon, authenticated;

create or replace function public.admin_action_log(p_limit integer default 50)
returns table (id uuid, admin_email text, action text, target text, detail jsonb, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select a.id, a.admin_email, a.action, a.target, a.detail, a.created_at
  from public.admin_actions a
  order by a.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

-- Existing moderation actions now leave a record too.

create or replace function public.admin_set_comment_status(p_comment_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  if p_status not in ('visible', 'hidden') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  update public.comments set status = p_status where id = p_comment_id;
  perform public.log_admin_action(
    case p_status when 'hidden' then 'hide_comment' else 'show_comment' end,
    coalesce((select left(body, 80) from public.comments where id = p_comment_id), p_comment_id::text));
end;
$$;

create or replace function public.admin_set_gallery_visibility(p_gallery_id uuid, p_visibility text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  if p_visibility not in ('public', 'unlisted', 'private') then
    raise exception 'invalid_visibility' using errcode = '22023';
  end if;
  update public.galleries set visibility = p_visibility, updated_at = now() where id = p_gallery_id;
  perform public.log_admin_action('set_gallery_visibility',
    coalesce((select '@' || handle from public.galleries where id = p_gallery_id), p_gallery_id::text),
    jsonb_build_object('visibility', p_visibility));
end;
$$;

create or replace function public.admin_resolve_report(p_report_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  if p_status not in ('actioned', 'dismissed') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  update public.reports set status = p_status where id = p_report_id;
  perform public.log_admin_action('resolve_report', p_report_id::text, jsonb_build_object('status', p_status));
end;
$$;

-- Deletes -------------------------------------------------------------------

-- Storage paths of a set of artworks: display + thumbnail (public bucket) and originals.
create or replace function public.artwork_files(p_artwork_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'artworks', coalesce((select jsonb_agg(p) from (
        select image_path as p from public.artworks where id = any(p_artwork_ids)
        union all
        select thumb_path from public.artworks where id = any(p_artwork_ids)) f), '[]'::jsonb),
    'originals', coalesce((select jsonb_agg(replace(image_path, 'display.jpg', 'original'))
        from public.artworks where id = any(p_artwork_ids)), '[]'::jsonb)
  );
$$;
revoke execute on function public.artwork_files(uuid[]) from public, anon, authenticated;

create or replace function public.admin_delete_gallery(p_gallery_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  g record;
  files jsonb;
  works integer;
begin
  perform public.require_admin();
  select id, handle, title into g from public.galleries where id = p_gallery_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select count(*) into works from public.artworks where gallery_id = g.id;
  files := public.artwork_files(array(select id from public.artworks where gallery_id = g.id));
  delete from public.galleries where id = g.id;
  perform public.log_admin_action('delete_gallery', '@' || g.handle,
    jsonb_build_object('title', g.title, 'artworks', works));
  return files;
end;
$$;

create or replace function public.admin_delete_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u record;
  files jsonb;
  works integer;
  handle text;
begin
  perform public.require_admin();
  if p_user_id = auth.uid() then
    raise exception 'cannot_delete_self' using errcode = '42501';
  end if;
  if exists (select 1 from public.admins a where a.user_id = p_user_id) then
    raise exception 'cannot_delete_admin' using errcode = '42501';
  end if;
  select id, email into u from auth.users where id = p_user_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select g.handle into handle from public.galleries g where g.owner_id = u.id;
  select count(*) into works from public.artworks a join public.galleries g on g.id = a.gallery_id where g.owner_id = u.id;
  files := public.artwork_files(array(
    select a.id from public.artworks a join public.galleries g on g.id = a.gallery_id where g.owner_id = u.id));
  -- Removing the auth user cascades to the profile, gallery and everything they wrote.
  delete from auth.users where id = u.id;
  perform public.log_admin_action('delete_user', coalesce(u.email, u.id::text),
    jsonb_build_object('gallery', handle, 'artworks', works));
  return files;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array['admin_action_log(integer)', 'admin_delete_gallery(uuid)', 'admin_delete_user(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- Storage: admins may remove anyone's artwork files; removing also needs read.
-- Owners get read on their own files too, so their own deletes work.
create policy "admins delete artwork images" on storage.objects for delete to authenticated
  using (bucket_id in ('artworks', 'originals') and public.is_admin());
create policy "admins read artwork images" on storage.objects for select to authenticated
  using (bucket_id in ('artworks', 'originals') and public.is_admin());
create policy "artists read own artwork images" on storage.objects for select to authenticated
  using (bucket_id = 'artworks' and (storage.foldername(name))[1] = auth.uid()::text);
