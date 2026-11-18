-- Three more gallery themes: feed (social-profile grid), salon (classic
-- museum wall) and editorial (art-magazine layout).
alter table public.galleries drop constraint if exists galleries_theme_check;
alter table public.galleries add constraint galleries_theme_check
  check (theme in ('white', 'dark', 'wood', 'feed', 'salon', 'editorial'));
