-- Older Supabase projects: anon and authenticated get every privilege on new
-- public tables. run.sh tests the schema with and without this file.
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
grant usage on schema storage to anon, authenticated;
grant all on storage.objects to authenticated;
