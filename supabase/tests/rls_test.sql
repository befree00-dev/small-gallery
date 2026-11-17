-- Row-level security and trigger tests. Run with supabase/tests/run.sh.
\set ON_ERROR_STOP on
\set QUIET on
\pset tuples_only on
\pset format unaligned

\set as_admin 'reset role; set request.jwt.claim.sub = '''';'
\set as_anon 'reset role; set request.jwt.claim.sub = ''''; set role anon;'
\set as_artist 'reset role; set request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000a''; set role authenticated;'
\set as_visitor 'reset role; set request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000b''; set role authenticated;'

-- Users ---------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'artist@example.com', '{"display_name":"지수"}'),
  ('00000000-0000-0000-0000-00000000000b', 'visitor@example.com', '{"locale":"en"}'),
  ('00000000-0000-0000-0000-0000000000c1', 'r1@example.com', '{}'),
  ('00000000-0000-0000-0000-0000000000c2', 'r2@example.com', '{}'),
  ('00000000-0000-0000-0000-0000000000c3', 'r3@example.com', '{}'),
  ('00000000-0000-0000-0000-0000000000c4', 'r4@example.com', '{}');

do $$ begin
  assert (select count(*) from public.profiles) = 6, 'a profile is created for every new user';
  assert (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = '지수', 'display name from sign-up metadata';
  assert (select locale from public.profiles where id = '00000000-0000-0000-0000-00000000000b') = 'en', 'locale from sign-up metadata';
end $$;

-- The artist builds a gallery ---------------------------------------------
:as_artist
insert into public.galleries (id, owner_id, handle, title, comment_policy)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'jisu', '지수의 작은 정원', 'approve');
insert into public.rooms (id, gallery_id, title) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '봄의 산책'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '작업 중');
update public.rooms set visibility = 'private' where id = '20000000-0000-0000-0000-000000000002';
insert into public.artworks (id, gallery_id, room_id, title, image_path, thumb_path, width, height) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '4월, 개천 옆 벚나무', 'a/1/display.jpg', 'a/1/thumb.jpg', 1600, 2000),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '비공개 습작', 'a/2/display.jpg', 'a/2/thumb.jpg', 1600, 2000),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '비공개 전시실의 작품', 'a/3/display.jpg', 'a/3/thumb.jpg', 1600, 2000);
update public.artworks set visibility = 'private' where id = '30000000-0000-0000-0000-000000000002';

do $$ begin
  assert (select count(*) from public.artworks) = 3, 'the artist sees all of their artworks';
end $$;

do $$ declare ok boolean := false; begin
  begin update public.artworks set like_count = 999 where id = '30000000-0000-0000-0000-000000000001';
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'the artist cannot edit like counts';
end $$;

do $$ declare ok boolean := false; begin
  begin insert into public.galleries (owner_id, handle, title) values ('00000000-0000-0000-0000-00000000000a', 'second', '두 번째');
  exception when unique_violation then ok := true; end;
  assert ok, 'one gallery per artist';
end $$;

-- A visitor cannot touch someone else's gallery -----------------------------
:as_visitor
do $$ declare ok boolean := false; begin
  begin insert into public.galleries (owner_id, handle, title) values ('00000000-0000-0000-0000-00000000000b', 'admin', '사칭');
  exception when check_violation then ok := true; end;
  assert ok, 'reserved handles are refused';
end $$;

do $$ declare ok boolean := false; begin
  begin insert into public.artworks (gallery_id, room_id, title, image_path, thumb_path, width, height)
    values ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'x', 'x', 'x', 1, 1);
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'visitors cannot add artworks to another gallery';
end $$;

update public.galleries set title = 'hacked' where handle = 'jisu';
do $$ begin
  assert (select title from public.galleries where handle = 'jisu') = '지수의 작은 정원', 'visitors cannot edit another gallery';
end $$;

-- Anonymous visitors see only what is published -----------------------------
:as_anon
do $$ begin
  assert (select count(*) from public.galleries) = 1, 'public gallery is visible without signing in';
  assert (select count(*) from public.rooms) = 1, 'private room is hidden';
  assert (select count(*) from public.artworks) = 1, 'private artwork and artworks in private rooms are hidden';
end $$;

-- Likes without signing in --------------------------------------------------
do $$ declare r record; begin
  select * into r from public.toggle_like('30000000-0000-0000-0000-000000000001', 'device-key-0123456789');
  assert r.liked and r.like_count = 1, 'anonymous like counts';
  assert public.has_liked('30000000-0000-0000-0000-000000000001', 'device-key-0123456789'), 'like is remembered for the device';
  select * into r from public.toggle_like('30000000-0000-0000-0000-000000000001', 'device-key-0123456789');
  assert not r.liked and r.like_count = 0, 'second tap removes the like';
  select * into r from public.toggle_like('30000000-0000-0000-0000-000000000001', 'device-key-0123456789');
end $$;

do $$ declare ok boolean := false; begin
  begin perform public.toggle_like('30000000-0000-0000-0000-000000000002', 'device-key-0123456789');
  exception when no_data_found then ok := true; end;
  assert ok, 'private artworks cannot be liked';
end $$;

do $$ declare ok boolean := false; begin
  begin perform * from public.likes;
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'the likes table is not readable directly';
end $$;

select public.record_view('10000000-0000-0000-0000-000000000001');
select public.record_view('10000000-0000-0000-0000-000000000001');
select public.record_view('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001');

do $$ declare ok boolean := false; begin
  begin insert into public.ratings (artwork_id, user_id, composition, color, technique, emotion)
    values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 5, 5, 5, 5);
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'rating requires signing in';
end $$;

-- Ratings -------------------------------------------------------------------
:as_visitor
insert into public.ratings (artwork_id, user_id, composition, color, technique, emotion)
values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 4, 5, 3, 4);

do $$ begin
  assert (select count(*) from public.artwork_rating_stats) = 0, 'averages stay hidden below 5 ratings';
end $$;

do $$ declare ok boolean := false; begin
  begin insert into public.ratings (artwork_id, user_id, composition, color, technique, emotion)
    values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 1, 1, 1, 1);
  exception when unique_violation then ok := true; end;
  assert ok, 'one rating per visitor per artwork';
end $$;

update public.ratings set composition = 5 where artwork_id = '30000000-0000-0000-0000-000000000001';

:as_artist
do $$ declare ok boolean := false; begin
  begin insert into public.ratings (artwork_id, user_id, composition, color, technique, emotion)
    values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 5, 5, 5, 5);
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'artists cannot rate their own work';
end $$;

do $$ begin
  assert (select rating_count from public.artwork_rating_stats) = 1, 'the artist sees averages from the first rating';
  assert (select avg_composition from public.artwork_rating_stats) = 5, 'an updated rating refreshes the average';
  assert (select count(*) from public.notifications where kind = 'rating') = 1, 'the artist is notified of a new rating';
  assert (select count(*) from public.ratings) = 0, 'the artist does not see individual raters';
end $$;

:as_admin
insert into public.ratings (artwork_id, user_id, composition, color, technique, emotion)
select '30000000-0000-0000-0000-000000000001', u, 3, 3, 3, 3
from unnest(array[
  '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2',
  '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000c4']::uuid[]) as u;

:as_anon
do $$ begin
  assert (select rating_count from public.artwork_rating_stats) = 5, 'averages become public at 5 ratings';
  assert (select avg_color from public.artwork_rating_stats) = 3.40, 'average across the 5 ratings';
end $$;

-- Comments and moderation ---------------------------------------------------
:as_visitor
insert into public.comments (id, gallery_id, artwork_id, author_id, body)
values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '  분홍빛이 정말 좋아요  ');

do $$ begin
  assert (select status from public.comments where id = '40000000-0000-0000-0000-000000000001') = 'pending', 'approval policy holds new comments';
  assert (select body from public.comments where id = '40000000-0000-0000-0000-000000000001') = '분홍빛이 정말 좋아요', 'comment body is trimmed';
end $$;

update public.comments set status = 'visible' where id = '40000000-0000-0000-0000-000000000001';
do $$ begin
  assert (select status from public.comments where id = '40000000-0000-0000-0000-000000000001') = 'pending', 'authors cannot approve their own comments';
end $$;

do $$ declare ok boolean := false; begin
  begin update public.comments set body = 'edited' where id = '40000000-0000-0000-0000-000000000001';
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'comment bodies cannot be rewritten';
end $$;

:as_anon
do $$ begin
  assert (select count(*) from public.comments) = 0, 'pending comments are hidden from visitors';
end $$;

:as_artist
do $$ begin
  assert (select count(*) from public.comments) = 1, 'the artist sees pending comments';
  assert (select count(*) from public.notifications where kind = 'comment_pending') = 1, 'the artist is told a comment awaits approval';
end $$;
update public.comments set status = 'visible' where id = '40000000-0000-0000-0000-000000000001';
update public.galleries set comment_policy = 'open' where handle = 'jisu';

:as_anon
do $$ begin
  assert (select count(*) from public.comments) = 1, 'approved comment is public';
  assert (select comment_count from public.artworks) = 1, 'comment count follows approval';
end $$;

:as_visitor
insert into public.comments (gallery_id, author_id, body)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'Lovely spring room!');
insert into public.comments (gallery_id, artwork_id, author_id, body)
values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '이건 좀 병신같네요');

do $$ begin
  assert (select status from public.comments where artwork_id is null) = 'visible', 'open policy publishes guestbook entries';
  assert (select status from public.comments where body like '이건%') = 'pending', 'flagged words go to approval even when open';
end $$;

:as_artist
insert into public.blocked_authors (gallery_id, author_id)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
do $$ begin
  assert (select count(*) from public.notifications where kind = 'guestbook') = 1, 'guestbook entries notify the artist';
  assert (select sum(views) from public.view_stats) = 3, 'gallery and artwork views are counted';
end $$;

:as_visitor
do $$ declare ok boolean := false; begin
  begin insert into public.comments (gallery_id, author_id, body)
    values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'again');
  exception when raise_exception then ok := true; end;
  assert ok, 'blocked authors cannot comment';
end $$;

do $$ begin
  assert (select count(*) from public.notifications) = 0, 'visitors do not see the artist''s notifications';
end $$;

-- Private gallery -----------------------------------------------------------
:as_artist
update public.galleries set visibility = 'private' where handle = 'jisu';
:as_anon
do $$ begin
  assert (select count(*) from public.galleries) = 0, 'private gallery is hidden';
  assert (select count(*) from public.artworks) = 0, 'artworks of a private gallery are hidden';
  assert (select count(*) from public.comments) = 0, 'comments of a private gallery are hidden';
  assert (select count(*) from public.artwork_rating_stats) = 0, 'averages of a private gallery are hidden';
end $$;

-- Storage paths -------------------------------------------------------------
:as_artist
insert into storage.objects (bucket_id, name) values ('artworks', '00000000-0000-0000-0000-00000000000a/30000000/display.jpg');
do $$ declare ok boolean := false; begin
  begin insert into storage.objects (bucket_id, name) values ('artworks', '00000000-0000-0000-0000-00000000000b/x/display.jpg');
  exception when insufficient_privilege then ok := true; end;
  assert ok, 'artists upload only under their own folder';
end $$;

-- Plan quota ----------------------------------------------------------------
:as_admin
insert into public.artworks (gallery_id, room_id, title, image_path, thumb_path, width, height)
select '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'n' || i, 'p', 't', 1, 1
from generate_series(1, 97) as i;

do $$ declare ok boolean := false; begin
  assert (select count(*) from public.artworks) = 100, 'free plan holds 100 artworks';
  begin insert into public.artworks (gallery_id, room_id, title, image_path, thumb_path, width, height)
    values ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'over', 'p', 't', 1, 1);
  exception when raise_exception then ok := true; end;
  assert ok, 'the 101st artwork on the free plan is refused';
end $$;

-- The app and web name these foreign keys in API embeds
-- (galleries↔profiles is ambiguous through blocked_authors).
do $$ begin
  assert exists (select 1 from pg_constraint where conname = 'galleries_owner_id_fkey'), 'galleries_owner_id_fkey exists';
  assert exists (select 1 from pg_constraint where conname = 'comments_author_id_fkey'), 'comments_author_id_fkey exists';
end $$;

\echo 'All RLS tests passed.'
