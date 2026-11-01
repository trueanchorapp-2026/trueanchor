-- ============================================================================
-- TrueAnchor 0029 — multiple images on discussions and replies
--
-- Replaces 0027's single community_discussions.image_url with an image_urls
-- array (up to 5, matching DiscussionImages.maxPerEntry) and gives replies
-- the same column. Files live in the same discussion-images bucket, under
-- the uploader's folder (0028).
-- ============================================================================

alter table public.community_discussions
  add column image_urls text[] not null default '{}'
    check (cardinality(image_urls) <= 5);

update public.community_discussions
  set image_urls = array[image_url]
  where image_url is not null;

alter table public.community_discussions
  drop column image_url;

alter table public.community_discussion_replies
  add column image_urls text[] not null default '{}'
    check (cardinality(image_urls) <= 5);
