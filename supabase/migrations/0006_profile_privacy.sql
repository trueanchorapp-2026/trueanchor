-- ============================================================================
-- TrueAnchor — profile privacy + household profile management
--
-- Three corrections, all to policies that were broader or narrower than the
-- product actually intends:
--
--   1. profiles_select_church exposed every column of every profile to every
--      authenticated member of the church -- including other households'
--      parents and other youth. Birth date and gender are not church-wide
--      facts. Narrowed to church staff plus your own household.
--   2. Parents had no way to fill in their youth's birth date, grade or
--      baptism. Only the youth themselves (profiles_update_own) or church
--      staff (profiles_update_admin) could write those columns.
--   3. journal_insert_own let church staff author journal entries they would
--      then never be able to find: the app gives them no Journal tab, and the
--      read policies scope entries to a household they do not belong to.
-- ============================================================================

-- ------------------------------------------------------------- profiles ---

-- Replaces the church-wide read. Staff keep exactly what they had; everyone
-- else drops to their own household. profiles_select_own still covers self,
-- which is what keeps a church-staff account (no family_id) able to load its
-- own profile.
drop policy if exists profiles_select_church on public.profiles;

create policy profiles_select_staff on public.profiles for select to authenticated
  using (church_id = (select private.current_church_id())
         and (select private.current_app_role())
               in ('youth_pastor','church_admin','app_admin'));

create policy profiles_select_family on public.profiles for select to authenticated
  using (family_id is not null
         and family_id = (select private.current_family_id()));

-- Lets the adults in a household maintain their youth's profile -- age and
-- grade have to come from somewhere, and a nine-year-old is not the one
-- filling them in.
--
-- Scoped to youth on purpose: an adult may not edit another adult. Escalation
-- is impossible regardless, because private.guard_profile_columns() reverts
-- role, family_role, church_id and family_id for any caller who is not a
-- church admin, and it is a BEFORE trigger -- so the reverted row is what this
-- policy's WITH CHECK sees.
create policy profiles_update_family_youth on public.profiles for update to authenticated
  using (role = 'youth'
         and family_id is not null
         and family_id = (select private.current_family_id())
         and (select private.current_app_role()) = 'parent')
  with check (role = 'youth'
              and family_id is not null
              and family_id = (select private.current_family_id()));

-- ------------------------------------------------------- journal_entries ---

-- Church staff belong to no household, so stamp_journal_context() writes a
-- null family_id and neither sharing policy can ever match. An entry they
-- wrote would be invisible to everyone including themselves once they had a
-- second one. The nav already hides the feature; this closes the direct-API
-- path that the nav cannot.
drop policy if exists journal_insert_own on public.journal_entries;

create policy journal_insert_own on public.journal_entries for insert to authenticated
  with check (author_id = (select auth.uid())
              and (select private.current_app_role()) in ('parent','youth'));
