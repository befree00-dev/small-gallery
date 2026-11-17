-- Storage buckets.
--   artworks  : public display variants (max 2048px long edge) and thumbnails.
--   originals : full-resolution uploads, private to the artist.
-- Object paths start with the uploader's user id: "<uid>/<artwork id>/<file>".

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('artworks', 'artworks', true, 10485760, array['image/jpeg', 'image/webp']),
  ('originals', 'originals', false, 52428800, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do nothing;

create policy "artists write own artwork images" on storage.objects for insert to authenticated
  with check (bucket_id in ('artworks', 'originals') and (storage.foldername(name))[1] = auth.uid()::text);

create policy "artists update own artwork images" on storage.objects for update to authenticated
  using (bucket_id in ('artworks', 'originals') and (storage.foldername(name))[1] = auth.uid()::text);

create policy "artists delete own artwork images" on storage.objects for delete to authenticated
  using (bucket_id in ('artworks', 'originals') and (storage.foldername(name))[1] = auth.uid()::text);

create policy "artists read own originals" on storage.objects for select to authenticated
  using (bucket_id = 'originals' and (storage.foldername(name))[1] = auth.uid()::text);
