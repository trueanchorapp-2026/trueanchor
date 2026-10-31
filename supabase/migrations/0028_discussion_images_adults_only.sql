-- ============================================================================
-- TrueAnchor 0028 — tighten discussion image uploads
--
-- 0027's upload policy let any authenticated user (youth included) write
-- anywhere in the bucket. Community is adults-only at the RLS level, and the
-- delete policy already expects each user's files under their own folder, so
-- uploads now require both. The bucket also gains a size cap and an image
-- allow-list matching CommunityDiscussion.imageContentTypes.
-- ============================================================================

drop policy if exists discussion_images_upload on storage.objects;

create policy discussion_images_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'discussion-images'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and (select private.current_app_role()) <> 'youth');

update storage.buckets
  set file_size_limit = 5242880,  -- 5 MB
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/gif',
                                 'image/webp']
  where id = 'discussion-images';
