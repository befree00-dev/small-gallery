-- Admin mode: service-wide statistics and moderation for operators.
--
-- Who is an admin lives in public.admins, which no app role can read or
-- write; add operators from the Supabase SQL editor:
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'you@example.com';
-- Every admin_* function checks is_admin() itself, so the statistics cannot
-- be read by calling the API directly.
--
-- "Today" is the Korean calendar day (Asia/Seoul).

create table public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;
grant execute on function public.is_admin() to authenticated;

create or replace function public.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function public.require_admin() from public, anon, authenticated;

create or replace function public.kst_today()
returns date
language sql
stable
as $$ select (now() at time zone 'Asia/Seoul')::date $$;

-- Count views by the Korean day too, so "today" means the same everywhere.
create or replace function public.record_view(p_gallery_id uuid, p_artwork_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.gallery_is_visible(p_gallery_id) or public.is_gallery_owner(p_gallery_id) then
    return;
  end if;
  if p_artwork_id is not null and not public.artwork_is_visible(p_artwork_id) then
    return;
  end if;
  insert into public.view_stats as v (gallery_id, artwork_id, day, views)
  values (p_gallery_id, p_artwork_id, public.kst_today(), 1)
  on conflict (gallery_id, scope_key, day) do update set views = v.views + 1;
end;
$$;

-- Security fix: profiles_update let a user change any column of their own
-- row, including plan. Users may only edit their name, avatar and locale.
revoke update on public.profiles from authenticated;
grant update (display_name, avatar_path, locale) on public.profiles to authenticated;

-- Headline numbers: today and all-time.
create or replace function public.admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  d date := public.kst_today();
  since timestamptz := (d::timestamp at time zone 'Asia/Seoul');
begin
  perform public.require_admin();
  return jsonb_build_object(
    'day', d,
    'users', jsonb_build_object(
      'today', (select count(*) from public.profiles where created_at >= since),
      'total', (select count(*) from public.profiles)),
    'galleries', jsonb_build_object(
      'today', (select count(*) from public.galleries where created_at >= since),
      'total', (select count(*) from public.galleries)),
    'artworks', jsonb_build_object(
      'today', (select count(*) from public.artworks where created_at >= since),
      'total', (select count(*) from public.artworks)),
    'comments', jsonb_build_object(
      'today', (select count(*) from public.comments where created_at >= since),
      'total', (select count(*) from public.comments)),
    'ratings', jsonb_build_object(
      'today', (select count(*) from public.ratings where created_at >= since),
      'total', (select count(*) from public.ratings)),
    'likes', jsonb_build_object(
      'today', (select count(*) from public.likes where created_at >= since),
      'total', (select count(*) from public.likes)),
    'views', jsonb_build_object(
      'today', (select coalesce(sum(views), 0) from public.view_stats where day = d and artwork_id is null),
      'total', (select coalesce(sum(views), 0) from public.view_stats where artwork_id is null)),
    'pending_comments', (select count(*) from public.comments where status = 'pending'),
    'open_reports', (select count(*) from public.reports where status = 'open')
  );
end;
$$;

-- One row per Korean day for the last p_days days, oldest first.
create or replace function public.admin_daily(p_days integer default 30)
returns table (day date, users bigint, galleries bigint, artworks bigint, comments bigint, views bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  with days as (
    select generate_series(public.kst_today() - (least(greatest(p_days, 1), 366) - 1), public.kst_today(), '1 day')::date as d
  )
  select
    days.d,
    (select count(*) from public.profiles p where (p.created_at at time zone 'Asia/Seoul')::date = days.d),
    (select count(*) from public.galleries g where (g.created_at at time zone 'Asia/Seoul')::date = days.d),
    (select count(*) from public.artworks a where (a.created_at at time zone 'Asia/Seoul')::date = days.d),
    (select count(*) from public.comments c where (c.created_at at time zone 'Asia/Seoul')::date = days.d),
    (select coalesce(sum(v.views), 0)::bigint from public.view_stats v where v.day = days.d and v.artwork_id is null)
  from days
  order by days.d;
end;
$$;

create or replace function public.admin_galleries(p_limit integer default 50)
returns table (
  id uuid, handle text, title text, owner_name text, visibility text,
  artworks bigint, views bigint, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select g.id, g.handle, g.title, p.display_name, g.visibility,
         (select count(*) from public.artworks a where a.gallery_id = g.id),
         (select coalesce(sum(v.views), 0)::bigint from public.view_stats v where v.gallery_id = g.id and v.artwork_id is null),
         g.created_at
  from public.galleries g
  join public.profiles p on p.id = g.owner_id
  order by g.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

create or replace function public.admin_comments(p_limit integer default 50)
returns table (
  id uuid, body text, status text, author_name text, gallery_handle text,
  artwork_title text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select c.id, c.body, c.status, p.display_name, g.handle, a.title, c.created_at
  from public.comments c
  join public.galleries g on g.id = c.gallery_id
  join public.profiles p on p.id = c.author_id
  left join public.artworks a on a.id = c.artwork_id
  order by c.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

create or replace function public.admin_reports()
returns table (
  id uuid, target_type text, target_id uuid, reason text, detail text,
  reporter_name text, target_label text, gallery_handle text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select r.id, r.target_type, r.target_id, r.reason, r.detail, p.display_name,
         case r.target_type
           when 'comment' then (select c.body from public.comments c where c.id = r.target_id)
           when 'artwork' then (select a.title from public.artworks a where a.id = r.target_id)
           when 'gallery' then (select g.title from public.galleries g where g.id = r.target_id)
         end,
         case r.target_type
           when 'comment' then (select g.handle from public.comments c join public.galleries g on g.id = c.gallery_id where c.id = r.target_id)
           when 'artwork' then (select g.handle from public.artworks a join public.galleries g on g.id = a.gallery_id where a.id = r.target_id)
           when 'gallery' then (select g.handle from public.galleries g where g.id = r.target_id)
         end,
         r.created_at
  from public.reports r
  join public.profiles p on p.id = r.reporter_id
  where r.status = 'open'
  order by r.created_at;
end;
$$;

-- Moderation -----------------------------------------------------------------

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
end;
$$;

-- Takes a gallery down (private) or puts it back (public).
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
end;
$$;

-- Only signed-in callers may try; require_admin() decides the rest.
do $$
declare f text;
begin
  foreach f in array array[
    'admin_overview()', 'admin_daily(integer)', 'admin_galleries(integer)', 'admin_comments(integer)',
    'admin_reports()', 'admin_set_comment_status(uuid, text)', 'admin_set_gallery_visibility(uuid, text)',
    'admin_resolve_report(uuid, text)'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
