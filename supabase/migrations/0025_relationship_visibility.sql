-- ============================================================================
-- TrueAnchor — per-entry sharing for Love in Action
--
-- 0022 shipped relationships with unconditional sharing: every relationship a
-- youth logged was readable by every parent in their household and by their
-- youth pastor, with no way to keep one back. This adds the per-entry choice
-- the journal has had since 0001.
--
-- Reuses `public.entry_visibility` rather than defining a second enum. One
-- vocabulary means one set of labels the user learns once, and it keeps this
-- to a single migration file — a new enum value cannot be referenced in the
-- transaction that created it (see the note at the top of 0008).
--
-- Only a youth can author a relationship (`relationships_insert_own`), and the
-- youth branch of `EntrySharing.resolve` in
-- `lib/core/domain/entry_visibility.dart` only ever produces three of the five
-- rungs. The CHECK constraint pins that down so the two cannot drift.
--
-- Existing rows default to 'parents_pastor': that is exactly what they are
-- today, and what `relationship_editor_page` promised their authors. Defaulting
-- to 'private' would quietly narrow entries whose owners never asked for it.
-- New entries share by default for the same reason, and a youth can opt any
-- entry out. No entry ever widens without its author ticking a box.
--
-- The Dart labels are the user's only window onto these policies. If the
-- wording there drifts from what is enforced here, the app is lying about
-- privacy — keep the two in step.
-- ============================================================================

alter table public.relationships
  add column visibility public.entry_visibility not null
    default 'parents_pastor';

alter table public.relationships
  add constraint relationships_visibility_youth_rungs
  check (visibility in ('private', 'parents', 'parents_pastor'));

-- Mirrors `journal_entries (family_id) where visibility <> 'private'` from
-- 0001: the household read never has to walk the private rows.
create index on public.relationships (family_id) where visibility <> 'private';

-- --------------------------------------------------------------- policies ---

-- Both replace their 0022 counterparts, which had no visibility test at all.
-- This is a narrowing in every case, so it cannot break a promise made at
-- write time — an entry is now read by the same people or fewer.

drop policy if exists relationships_select_parents on public.relationships;

create policy relationships_select_parents on public.relationships
  for select to authenticated
  using (visibility in ('parents', 'parents_pastor')
         and (select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

drop policy if exists relationships_select_pastor on public.relationships;

create policy relationships_select_pastor on public.relationships
  for select to authenticated
  using (visibility = 'parents_pastor'
         and (select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

-- Interactions inherit visibility from their parent relationship, so the same
-- two tests are inlined here. This policy duplicates the predicates above by
-- necessity — change one and you must change the other.

drop policy if exists interactions_select on public.relationship_interactions;

create policy interactions_select on public.relationship_interactions
  for select to authenticated
  using (exists (
    select 1 from public.relationships r
    where r.id = relationship_id
      and (r.owner_id = (select auth.uid())
           or (r.visibility in ('parents', 'parents_pastor')
               and (select private.current_app_role()) = 'parent'
               and r.family_id is not null
               and r.family_id = (select private.current_family_id()))
           or (r.visibility = 'parents_pastor'
               and (select private.current_app_role()) = 'youth_pastor'
               and r.church_id = (select private.current_church_id())))
  ));
