-- ============================================================================
-- TrueAnchor — household sharing + narrowing the pastor read
--
-- Depends on the enum values added in 0008; see the note there about why this
-- is a separate file.
--
-- Two changes to THE PRIVACY BOUNDARY:
--
--   1. `family` / `family_pastor` become readable by every member of the
--      author's household, youth included. This is what lets a parent post a
--      prayer request the whole family is meant to pray over — previously no
--      visibility a parent could pick was readable by their own children,
--      because journal_select_parents requires the *reader* to be a parent.
--   2. church_admin loses its read on shared entries. Administration is not
--      pastoral care: a church admin manages invites, families and events,
--      and has no reason to read a youth's journal. The youth pastor is the
--      only staff role that keeps it.
--
-- Change 2 is a narrowing, so it cannot break a promise made at write time —
-- an entry shared with staff is now read by strictly fewer people.
-- ============================================================================

-- Every member of the household, regardless of role. Deliberately has no
-- role test: that absence is the whole feature.
create policy journal_select_family on public.journal_entries
  for select to authenticated
  using (visibility in ('family', 'family_pastor')
         and family_id is not null
         and family_id = (select private.current_family_id()));

-- Replaces the 0001 policy: drops church_admin, picks up family_pastor.
-- app_admin was never included and still is not.
drop policy if exists journal_select_pastor on public.journal_entries;

create policy journal_select_pastor on public.journal_entries
  for select to authenticated
  using (visibility in ('parents_pastor', 'family_pastor')
         and (select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

-- ------------------------------------------------------ pastor presence ---

-- Sharing with a pastor who does not exist is the same as sharing with
-- nobody, and the editor should say so before the user writes something
-- vulnerable. A youth cannot discover this themselves: profiles_select_family
-- limits them to their own household, so a direct count returns zero whether
-- or not the church has a youth pastor.
--
-- security definer to see past that, returning a single boolean — no profile
-- data crosses the boundary.
create or replace function public.church_has_youth_pastor()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
     where church_id = (select private.current_church_id())
       and role = 'youth_pastor'
  )
$$;

revoke all on function public.church_has_youth_pastor() from public, anon;
grant execute on function public.church_has_youth_pastor() to authenticated;
