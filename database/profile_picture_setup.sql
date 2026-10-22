-- Run once in the Supabase SQL Editor to enable profile picture uploads.

alter table public.users
  add column if not exists profile_picture_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profilePictures',
  'profilePictures',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users view their own profile pictures" on storage.objects;
create policy "Users view their own profile pictures"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profilePictures'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users upload their own profile pictures" on storage.objects;
create policy "Users upload their own profile pictures"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profilePictures'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users update their own profile pictures" on storage.objects;
create policy "Users update their own profile pictures"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profilePictures'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'profilePictures'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users delete their own profile pictures" on storage.objects;
create policy "Users delete their own profile pictures"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profilePictures'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
