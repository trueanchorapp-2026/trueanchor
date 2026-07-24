-- ============================================================================
-- TrueAnchor — milestones logged automatically from profile facts
--
-- Some milestones are already recorded elsewhere in the app: a youth's profile
-- carries `baptized` / `baptized_on`, and re-typing that into the milestone
-- list is busywork nobody will do. This keeps the two in step.
--
-- It lives in the database rather than in the profile edit page because every
-- writer must behave the same — the youth themselves, a parent, church staff —
-- and because `milestones_insert` deliberately forbids a youth from inserting.
-- A security-definer trigger is the only place that can log a youth's own
-- baptism when the youth is the one who saved the form.
-- ============================================================================

-- Distinguishes rows this trigger owns from rows a person typed. The trigger
-- only ever touches its own, so a parent's hand-written baptism note is never
-- overwritten or deleted.
alter table public.milestones
  add column auto_logged boolean not null default false;

-- At most one auto-logged row per profile per type: the arbiter for the upsert
-- below, and the reason a repeated save cannot pile up duplicates.
create unique index milestones_auto_logged_key
  on public.milestones (profile_id, milestone_type)
  where auto_logged;

-- ------------------------------------------------------------- function ---

-- Mirrors profiles.baptized/baptized_on into a 'baptized' milestone.
--
-- Scoped to youth: `baptized` is a youth-profile field, and the milestone list
-- is a youth's record of their walk. An adult's row would surprise its family.
--
-- Un-checking baptism removes the auto row — a correction should not leave a
-- claim behind. Missing baptized_on falls back to today so achieved_on, which
-- is not null, always has a value; correcting the date later updates the row.
create or replace function private.sync_baptism_milestone()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role <> 'youth' then
    return null;
  end if;

  if new.baptized then
    insert into public.milestones (profile_id, milestone_type, achieved_on, auto_logged)
    values (new.id, 'baptized', coalesce(new.baptized_on, current_date), true)
    on conflict (profile_id, milestone_type) where auto_logged
      do update set achieved_on = excluded.achieved_on;
  else
    delete from public.milestones
    where profile_id = new.id
      and milestone_type = 'baptized'
      and auto_logged;
  end if;

  return null;
end;
$$;

-- ------------------------------------------------------------- triggers ---

-- Two triggers rather than one: an INSERT trigger's WHEN clause cannot read
-- OLD, and an UPDATE with no change to either column must not do work.
create trigger trg_sync_baptism_milestone_insert
  after insert on public.profiles
  for each row when (new.baptized)
  execute function private.sync_baptism_milestone();

create trigger trg_sync_baptism_milestone_update
  after update of baptized, baptized_on on public.profiles
  for each row when (new.baptized is distinct from old.baptized
                     or new.baptized_on is distinct from old.baptized_on)
  execute function private.sync_baptism_milestone();

-- ------------------------------------------------------------- backfill ---

-- Youth already marked baptized before this migration. church_id and family_id
-- are left to `stamp_milestone_context`, as they are for every other insert;
-- recorded_by lands null there, which is right — nobody logged these.
insert into public.milestones (profile_id, milestone_type, achieved_on, auto_logged)
select p.id, 'baptized', coalesce(p.baptized_on, current_date), true
from public.profiles p
where p.baptized and p.role = 'youth'
on conflict (profile_id, milestone_type) where auto_logged do nothing;
