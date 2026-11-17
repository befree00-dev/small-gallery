-- Small Gallery · MVP schema
-- Galleries, rooms, artworks, and visitor reactions (likes, ratings, comments),
-- with row-level security so that visitors only ever see what an artist published.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 40),
  avatar_path  text,
  locale       text not null default 'ko' check (locale in ('ko', 'en')),
  plan         text not null default 'free' check (plan in ('free', 'plus')),
  created_at   timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1), ''),
    case when new.raw_user_meta_data ->> 'locale' = 'en' then 'en' else 'ko' end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Galleries · rooms · artworks
-- ---------------------------------------------------------------------------

create table public.galleries (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null unique references public.profiles (id) on delete cascade,
  handle         text not null unique check (handle ~ '^[a-z0-9_]{3,30}$'),
  title          text not null check (char_length(title) between 1 and 60),
  title_en       text check (char_length(title_en) <= 60),
  bio            text not null default '' check (char_length(bio) <= 500),
  bio_en         text check (char_length(bio_en) <= 500),
  field          text not null default 'painting' check (field in ('painting', 'photo', 'illustration', 'other')),
  cover_path     text,
  theme          text not null default 'white' check (theme in ('white', 'dark', 'wood')),
  visibility     text not null default 'public' check (visibility in ('public', 'unlisted', 'private')),
  rating_enabled boolean not null default true,
  comment_policy text not null default 'approve' check (comment_policy in ('open', 'approve', 'off')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Handles that would collide with app routes or impersonate the service.
create table public.reserved_handles (handle text primary key);
insert into public.reserved_handles (handle) values
  ('admin'), ('api'), ('app'), ('help'), ('support'), ('settings'), ('studio'),
  ('login'), ('signup'), ('ko'), ('en'), ('smallgallery'), ('official');

create or replace function public.check_handle_not_reserved()
returns trigger
language plpgsql
as $$
begin
  if exists (select 1 from public.reserved_handles r where r.handle = new.handle) then
    raise exception 'handle_reserved' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger galleries_handle_reserved
  before insert or update of handle on public.galleries
  for each row execute function public.check_handle_not_reserved();

create table public.rooms (
  id           uuid primary key default gen_random_uuid(),
  gallery_id   uuid not null references public.galleries (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 60),
  title_en     text check (char_length(title_en) <= 60),
  statement    text not null default '' check (char_length(statement) <= 1000),
  statement_en text check (char_length(statement_en) <= 1000),
  sort_order   integer not null default 0,
  visibility   text not null default 'public' check (visibility in ('public', 'unlisted', 'private')),
  created_at   timestamptz not null default now()
);
create index rooms_gallery_idx on public.rooms (gallery_id, sort_order);

create table public.artworks (
  id             uuid primary key default gen_random_uuid(),
  gallery_id     uuid not null references public.galleries (id) on delete cascade,
  room_id        uuid not null references public.rooms (id) on delete cascade,
  title          text not null check (char_length(title) between 1 and 80),
  title_en       text check (char_length(title_en) <= 80),
  year           integer check (year between 1900 and 2100),
  medium         text not null default '' check (char_length(medium) <= 40),
  size_text      text not null default '' check (char_length(size_text) <= 40),
  note           text not null default '' check (char_length(note) <= 2000),
  note_en        text check (char_length(note_en) <= 2000),
  tags           text[] not null default '{}',
  sort_order     integer not null default 0,
  visibility     text not null default 'public' check (visibility in ('public', 'unlisted', 'private')),
  is_featured    boolean not null default false,
  rating_enabled boolean not null default true,
  watermark      boolean not null default false,
  -- Storage paths in the "artworks" bucket. Display variants only; originals stay private.
  image_path     text not null,
  thumb_path     text not null,
  width          integer not null check (width > 0),
  height         integer not null check (height > 0),
  exif           jsonb not null default '{}'::jsonb,
  like_count     integer not null default 0,
  comment_count  integer not null default 0,
  created_at     timestamptz not null default now()
);
create index artworks_room_idx on public.artworks (room_id, sort_order);
create index artworks_gallery_idx on public.artworks (gallery_id);

-- An artwork's gallery must be its room's gallery.
create or replace function public.check_artwork_gallery()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.rooms r where r.id = new.room_id and r.gallery_id = new.gallery_id) then
    raise exception 'room_not_in_gallery' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger artworks_gallery_matches_room
  before insert or update of room_id, gallery_id on public.artworks
  for each row execute function public.check_artwork_gallery();

-- Plan limits: Free 100 artworks, Plus 2,000.
create or replace function public.check_artwork_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_plan text;
  current_count integer;
  max_count integer;
begin
  select p.plan into owner_plan
  from public.galleries g join public.profiles p on p.id = g.owner_id
  where g.id = new.gallery_id;

  max_count := case owner_plan when 'plus' then 2000 else 100 end;
  select count(*) into current_count from public.artworks a where a.gallery_id = new.gallery_id;

  if current_count >= max_count then
    raise exception 'artwork_quota_exceeded' using errcode = 'P0001', detail = max_count::text;
  end if;
  return new;
end;
$$;

create trigger artworks_quota
  before insert on public.artworks
  for each row execute function public.check_artwork_quota();

-- ---------------------------------------------------------------------------
-- Visibility helpers (security definer so policies can call them without recursion)
-- ---------------------------------------------------------------------------

create or replace function public.is_gallery_owner(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.galleries g where g.id = gid and g.owner_id = auth.uid());
$$;

create or replace function public.gallery_is_visible(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.galleries g
    where g.id = gid and (g.visibility <> 'private' or g.owner_id = auth.uid())
  );
$$;

create or replace function public.artwork_is_visible(aid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.artworks a
    join public.rooms r on r.id = a.room_id
    join public.galleries g on g.id = a.gallery_id
    where a.id = aid
      and (
        g.owner_id = auth.uid()
        or (g.visibility <> 'private' and r.visibility <> 'private' and a.visibility <> 'private')
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Reactions
-- ---------------------------------------------------------------------------

-- Likes work without signing in: anonymous visitors are keyed by a hash of a
-- random id their device keeps. Writes only go through toggle_like().
create table public.likes (
  artwork_id  uuid not null references public.artworks (id) on delete cascade,
  visitor_key text not null check (char_length(visitor_key) between 16 and 80),
  user_id     uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (artwork_id, visitor_key)
);

create table public.ratings (
  artwork_id  uuid not null references public.artworks (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  composition smallint not null check (composition between 1 and 5),
  color       smallint not null check (color between 1 and 5),
  technique   smallint not null check (technique between 1 and 5),
  emotion     smallint not null check (emotion between 1 and 5),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (artwork_id, user_id)
);

-- Averages are public only once 5 or more ratings exist (see RLS below).
create table public.artwork_rating_stats (
  artwork_id      uuid primary key references public.artworks (id) on delete cascade,
  gallery_id      uuid not null references public.galleries (id) on delete cascade,
  rating_count    integer not null default 0,
  avg_composition numeric(3, 2),
  avg_color       numeric(3, 2),
  avg_technique   numeric(3, 2),
  avg_emotion     numeric(3, 2),
  updated_at      timestamptz not null default now()
);

-- artwork_id null = the gallery's guestbook.
create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  gallery_id  uuid not null references public.galleries (id) on delete cascade,
  artwork_id  uuid references public.artworks (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (char_length(btrim(body)) between 1 and 1000),
  status      text not null default 'visible' check (status in ('visible', 'pending', 'hidden')),
  created_at  timestamptz not null default now()
);
create index comments_gallery_idx on public.comments (gallery_id, created_at desc);
create index comments_artwork_idx on public.comments (artwork_id, created_at desc);

create table public.blocked_authors (
  gallery_id uuid not null references public.galleries (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (gallery_id, author_id)
);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('artwork', 'comment', 'gallery')),
  target_id   uuid not null,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason      text not null check (reason in ('copyright', 'abuse', 'sexual', 'spam', 'other')),
  detail      text not null default '' check (char_length(detail) <= 1000),
  status      text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  created_at  timestamptz not null default now(),
  unique (target_type, target_id, reporter_id)
);

-- In-app notifications for the artist. Push delivery reads this table later.
create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  kind         text not null check (kind in ('comment', 'comment_pending', 'rating', 'guestbook')),
  artwork_id   uuid references public.artworks (id) on delete cascade,
  comment_id   uuid references public.comments (id) on delete cascade,
  actor_id     uuid references public.profiles (id) on delete set null,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications (recipient_id, created_at desc);

create table public.view_stats (
  gallery_id uuid not null references public.galleries (id) on delete cascade,
  artwork_id uuid references public.artworks (id) on delete cascade,
  day        date not null default current_date,
  views      integer not null default 0,
  -- Postgres treats NULLs as distinct in unique constraints; this key does not.
  scope_key  uuid generated always as (coalesce(artwork_id, gallery_id)) stored,
  primary key (gallery_id, scope_key, day)
);

-- ---------------------------------------------------------------------------
-- Reaction triggers and functions
-- ---------------------------------------------------------------------------

create or replace function public.refresh_rating_stats(aid uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.artwork_rating_stats as s
    (artwork_id, gallery_id, rating_count, avg_composition, avg_color, avg_technique, avg_emotion, updated_at)
  select a.id, a.gallery_id, count(r.user_id),
         avg(r.composition), avg(r.color), avg(r.technique), avg(r.emotion), now()
  from public.artworks a
  left join public.ratings r on r.artwork_id = a.id
  where a.id = aid
  group by a.id, a.gallery_id
  on conflict (artwork_id) do update set
    rating_count    = excluded.rating_count,
    avg_composition = excluded.avg_composition,
    avg_color       = excluded.avg_color,
    avg_technique   = excluded.avg_technique,
    avg_emotion     = excluded.avg_emotion,
    updated_at      = excluded.updated_at;
$$;

create or replace function public.on_rating_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  aid uuid := coalesce(new.artwork_id, old.artwork_id);
  owner uuid;
begin
  perform public.refresh_rating_stats(aid);

  if tg_op = 'INSERT' then
    select g.owner_id into owner
    from public.artworks a join public.galleries g on g.id = a.gallery_id
    where a.id = aid;
    insert into public.notifications (recipient_id, kind, artwork_id, actor_id)
    values (owner, 'rating', aid, new.user_id);
  end if;
  return null;
end;
$$;

create trigger ratings_changed
  after insert or update or delete on public.ratings
  for each row execute function public.on_rating_change();

create or replace function public.ratings_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger ratings_updated_at
  before update on public.ratings
  for each row execute function public.ratings_touch_updated_at();

-- Words that send a comment to the artist's approval queue even when the
-- gallery accepts comments openly. A text classifier replaces this later.
create table public.flagged_words (word text primary key);
insert into public.flagged_words (word) values
  ('시발'), ('씨발'), ('병신'), ('개새끼'), ('좆'), ('fuck'), ('shit'), ('bitch');

create or replace function public.prepare_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  policy text;
  owner uuid;
begin
  select g.comment_policy, g.owner_id into policy, owner
  from public.galleries g where g.id = new.gallery_id;

  if new.artwork_id is not null
     and not exists (select 1 from public.artworks a where a.id = new.artwork_id and a.gallery_id = new.gallery_id) then
    raise exception 'artwork_not_in_gallery' using errcode = '23514';
  end if;

  if policy = 'off' and new.author_id <> owner then
    raise exception 'comments_closed' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.blocked_authors b where b.gallery_id = new.gallery_id and b.author_id = new.author_id) then
    raise exception 'author_blocked' using errcode = 'P0001';
  end if;

  new.body := btrim(new.body);

  if new.author_id = owner then
    new.status := 'visible';
  elsif policy = 'approve'
     or exists (select 1 from public.flagged_words w where position(w.word in lower(new.body)) > 0) then
    new.status := 'pending';
  else
    new.status := 'visible';
  end if;
  return new;
end;
$$;

create trigger comments_prepare
  before insert on public.comments
  for each row execute function public.prepare_comment();

create or replace function public.on_comment_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  aid uuid := coalesce(new.artwork_id, old.artwork_id);
  owner uuid;
begin
  if aid is not null then
    update public.artworks a
    set comment_count = (select count(*) from public.comments c where c.artwork_id = aid and c.status = 'visible')
    where a.id = aid;
  end if;

  if tg_op = 'INSERT' then
    select g.owner_id into owner from public.galleries g where g.id = new.gallery_id;
    if new.author_id <> owner then
      insert into public.notifications (recipient_id, kind, artwork_id, comment_id, actor_id)
      values (
        owner,
        case
          when new.status = 'pending' then 'comment_pending'
          when new.artwork_id is null then 'guestbook'
          else 'comment'
        end,
        new.artwork_id, new.id, new.author_id
      );
    end if;
  end if;
  return null;
end;
$$;

create trigger comments_changed
  after insert or update of status or delete on public.comments
  for each row execute function public.on_comment_change();

-- Like or unlike. Signed-in visitors are keyed by user id; others by device key.
create or replace function public.toggle_like(p_artwork_id uuid, p_device_key text default null)
returns table (liked boolean, like_count integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  key text;
  was_liked boolean;
begin
  if not public.artwork_is_visible(p_artwork_id) then
    raise exception 'artwork_not_found' using errcode = 'P0002';
  end if;

  if auth.uid() is not null then
    key := 'u:' || auth.uid()::text;
  elsif p_device_key is not null and char_length(p_device_key) between 16 and 64 then
    key := 'd:' || encode(digest(p_device_key, 'sha256'), 'hex');
  else
    raise exception 'visitor_key_required' using errcode = '22023';
  end if;

  delete from public.likes l where l.artwork_id = p_artwork_id and l.visitor_key = key;
  was_liked := found;

  if not was_liked then
    insert into public.likes (artwork_id, visitor_key, user_id) values (p_artwork_id, key, auth.uid());
  end if;

  update public.artworks a
  set like_count = greatest(0, a.like_count + case when was_liked then -1 else 1 end)
  where a.id = p_artwork_id;

  return query select not was_liked, a.like_count from public.artworks a where a.id = p_artwork_id;
end;
$$;

create or replace function public.has_liked(p_artwork_id uuid, p_device_key text default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.likes l
    where l.artwork_id = p_artwork_id
      and l.visitor_key = case
        when auth.uid() is not null then 'u:' || auth.uid()::text
        else 'd:' || encode(digest(coalesce(p_device_key, ''), 'sha256'), 'hex')
      end
  );
$$;

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
  values (p_gallery_id, p_artwork_id, current_date, 1)
  on conflict (gallery_id, scope_key, day) do update set views = v.views + 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.profiles             enable row level security;
alter table public.galleries            enable row level security;
alter table public.rooms                enable row level security;
alter table public.artworks             enable row level security;
alter table public.likes                enable row level security;
alter table public.ratings              enable row level security;
alter table public.artwork_rating_stats enable row level security;
alter table public.comments             enable row level security;
alter table public.blocked_authors      enable row level security;
alter table public.reports              enable row level security;
alter table public.notifications        enable row level security;
alter table public.view_stats           enable row level security;
alter table public.reserved_handles     enable row level security;
alter table public.flagged_words        enable row level security;

-- Profiles: display names are public (shown on comments); only you edit yours.
create policy profiles_read on public.profiles for select using (true);
create policy profiles_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Galleries
create policy galleries_read on public.galleries for select
  using (visibility <> 'private' or owner_id = auth.uid());
create policy galleries_insert on public.galleries for insert to authenticated
  with check (owner_id = auth.uid());
create policy galleries_update on public.galleries for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy galleries_delete on public.galleries for delete to authenticated
  using (owner_id = auth.uid());

-- Rooms
create policy rooms_read on public.rooms for select
  using (public.is_gallery_owner(gallery_id) or (visibility <> 'private' and public.gallery_is_visible(gallery_id)));
create policy rooms_write on public.rooms for all to authenticated
  using (public.is_gallery_owner(gallery_id)) with check (public.is_gallery_owner(gallery_id));

-- Artworks
create policy artworks_read on public.artworks for select
  using (public.artwork_is_visible(id));
create policy artworks_insert on public.artworks for insert to authenticated
  with check (public.is_gallery_owner(gallery_id));
create policy artworks_update on public.artworks for update to authenticated
  using (public.is_gallery_owner(gallery_id)) with check (public.is_gallery_owner(gallery_id));
create policy artworks_delete on public.artworks for delete to authenticated
  using (public.is_gallery_owner(gallery_id));

-- Counters are maintained by triggers; owners cannot edit them directly.
-- (A column-level revoke cannot narrow a table-level grant, so grant columns explicitly.)
revoke update on public.artworks from authenticated;
grant update (
  room_id, title, title_en, year, medium, size_text, note, note_en, tags, sort_order,
  visibility, is_featured, rating_enabled, watermark, image_path, thumb_path, width, height, exif
) on public.artworks to authenticated;

-- Likes: no direct access; toggle_like() / has_liked() only.

-- Ratings: one per signed-in visitor per artwork, never on your own work.
create policy ratings_read on public.ratings for select to authenticated
  using (user_id = auth.uid());
create policy ratings_insert on public.ratings for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.artworks a join public.galleries g on g.id = a.gallery_id
      where a.id = artwork_id
        and a.rating_enabled and g.rating_enabled
        and g.owner_id <> auth.uid()
        and public.artwork_is_visible(a.id)
    )
  );
create policy ratings_update on public.ratings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy ratings_delete on public.ratings for delete to authenticated
  using (user_id = auth.uid());

-- Rating averages: the artist always; everyone else once there are 5+ ratings.
create policy rating_stats_read on public.artwork_rating_stats for select
  using (public.is_gallery_owner(gallery_id) or (rating_count >= 5 and public.artwork_is_visible(artwork_id)));

-- Comments
create policy comments_read on public.comments for select
  using (
    public.is_gallery_owner(gallery_id)
    or author_id = auth.uid()
    or (status = 'visible' and public.gallery_is_visible(gallery_id)
        and (artwork_id is null or public.artwork_is_visible(artwork_id)))
  );
create policy comments_insert on public.comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.gallery_is_visible(gallery_id)
    and (artwork_id is null or public.artwork_is_visible(artwork_id))
  );
-- Only the artist moderates (status); authors delete their own.
create policy comments_moderate on public.comments for update to authenticated
  using (public.is_gallery_owner(gallery_id)) with check (public.is_gallery_owner(gallery_id));
create policy comments_delete on public.comments for delete to authenticated
  using (author_id = auth.uid() or public.is_gallery_owner(gallery_id));
revoke update on public.comments from authenticated;
grant update (status) on public.comments to authenticated;

create policy blocked_authors_owner on public.blocked_authors for all to authenticated
  using (public.is_gallery_owner(gallery_id)) with check (public.is_gallery_owner(gallery_id));

create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
create policy reports_read_own on public.reports for select to authenticated
  using (reporter_id = auth.uid());

create policy notifications_read on public.notifications for select to authenticated
  using (recipient_id = auth.uid());
create policy notifications_mark_read on public.notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

create policy view_stats_owner on public.view_stats for select to authenticated
  using (public.is_gallery_owner(gallery_id));

create policy reserved_handles_read on public.reserved_handles for select using (true);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on public.likes from anon, authenticated;
revoke all on public.flagged_words from anon, authenticated;
revoke insert, update, delete on public.artwork_rating_stats from anon, authenticated;
revoke insert, update, delete on public.view_stats from anon, authenticated;
revoke insert, delete on public.notifications from anon, authenticated;

revoke execute on function public.refresh_rating_stats(uuid) from public, anon, authenticated;
grant execute on function public.toggle_like(uuid, text) to anon, authenticated;
grant execute on function public.has_liked(uuid, text) to anon, authenticated;
grant execute on function public.record_view(uuid, uuid) to anon, authenticated;
