-- ============================================================================
-- TrueAnchor 0027 — discussion images, parent resources, Love in Action
--                    for parents
--
-- 1. Adds image_url to community_discussions.
-- 2. Creates a Supabase Storage bucket for discussion images.
-- 3. Creates the parent_resources table (read-only from the app; rows
--    inserted via manual SQL).
-- 4. Opens Love in Action authoring to parents and widens the visibility
--    constraint and RLS policies to support parent-authored entries.
-- ============================================================================


-- ─── 1. Discussion images ──────────────────────────────────────────────────

alter table public.community_discussions
  add column image_url text;

-- Storage bucket for discussion images (public reads).
insert into storage.buckets (id, name, public)
  values ('discussion-images', 'discussion-images', true)
  on conflict (id) do nothing;

create policy discussion_images_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'discussion-images');

create policy discussion_images_read on storage.objects
  for select using (bucket_id = 'discussion-images');

create policy discussion_images_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'discussion-images'
         and (storage.foldername(name))[1] = (select auth.uid())::text);


-- ─── 2. Parent resources ───────────────────────────────────────────────────

create table public.parent_resources (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (length(btrim(title)) > 0),
  url        text not null check (length(btrim(url)) > 0),
  sort_order int  not null default 0,
  created_at timestamptz not null default now()
);

alter table public.parent_resources enable row level security;

create policy parent_resources_select on public.parent_resources
  for select to authenticated using (true);


-- ─── 3. Love in Action for parents ─────────────────────────────────────────

-- A. Widen the visibility constraint so parent-authored entries can use the
--    full ladder. Dart controls which rungs each role actually sets.

alter table public.relationships
  drop constraint relationships_visibility_youth_rungs;

alter table public.relationships
  add constraint relationships_visibility_valid
  check (visibility in ('private', 'parents', 'parents_pastor',
                         'family', 'family_pastor'));

-- B. Allow parents to insert relationships (was youth-only).

drop policy if exists relationships_insert_own on public.relationships;

create policy relationships_insert_own on public.relationships
  for insert to authenticated
  with check ((select private.current_app_role()) in ('youth', 'parent'));

-- C. Update select policies to cover family-wide visibility.

-- Parents see entries in their family where visibility reaches adults.
drop policy if exists relationships_select_parents on public.relationships;

create policy relationships_select_parents on public.relationships
  for select to authenticated
  using (visibility in ('parents', 'parents_pastor', 'family', 'family_pastor')
         and (select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

-- Youth see family-shared entries (from parents or siblings).
create policy relationships_select_youth_family on public.relationships
  for select to authenticated
  using (visibility in ('family', 'family_pastor')
         and (select private.current_app_role()) = 'youth'
         and family_id is not null
         and family_id = (select private.current_family_id()));

-- Pastor sees entries shared with pastor, regardless of author role.
drop policy if exists relationships_select_pastor on public.relationships;

create policy relationships_select_pastor on public.relationships
  for select to authenticated
  using (visibility in ('parents_pastor', 'family_pastor')
         and (select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

-- D. Update interactions select to mirror new visibility.

drop policy if exists interactions_select on public.relationship_interactions;

create policy interactions_select on public.relationship_interactions
  for select to authenticated
  using (exists (
    select 1 from public.relationships r
    where r.id = relationship_id
      and (r.owner_id = (select auth.uid())
           or (r.visibility in ('parents', 'parents_pastor', 'family', 'family_pastor')
               and (select private.current_app_role()) = 'parent'
               and r.family_id is not null
               and r.family_id = (select private.current_family_id()))
           or (r.visibility in ('family', 'family_pastor')
               and (select private.current_app_role()) = 'youth'
               and r.family_id is not null
               and r.family_id = (select private.current_family_id()))
           or (r.visibility in ('parents_pastor', 'family_pastor')
               and (select private.current_app_role()) = 'youth_pastor'
               and r.church_id = (select private.current_church_id())))
  ));
