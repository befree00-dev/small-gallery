-- New galleries start "unlisted": anyone with the link can visit, but the
-- gallery is kept out of search engines and any future discovery feed.
-- Artists can switch to public (or private) in settings.
-- Existing galleries keep their current setting.
alter table public.galleries alter column visibility set default 'unlisted';
