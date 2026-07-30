-- ============================================================================
-- TrueAnchor — devotion streak recorded as a milestone
--
-- CLAUDE.md lists "devotion consistency" as a spiritual milestone, and the
-- database already knows when a youth has reached one. Asking a parent to
-- notice a seven-day streak and type it in by hand is busywork nobody will do.
--
-- Same shape as 0007_auto_milestones.sql: a security-definer trigger owning
-- rows flagged auto_logged, arbitrated by the milestones_auto_logged_key
-- partial unique index. That definer matters here for the same reason it did
-- there — milestones_insert forbids a youth from inserting, and the youth is
-- exactly who is checking the box that earns this.
--
-- milestone_type already carries 'devotion_streak' from 0005, so this file may
-- reference it directly. The new-enum-value rule that forced 0008 and 0009
-- apart does not apply.
-- ============================================================================

-- The threshold this row represents. Without it the function would have to
-- parse "30-day devotion streak" back out of the title to decide whether a new
-- streak beats the recorded one, which would break the first time anybody
-- reworded the string.
alter table public.milestones add column if not exists streak_days int;

-- ------------------------------------------------------------- function ---

-- Highest threshold reached wins, and it only ever moves upward.
--
-- This is a deliberate divergence from private.sync_baptism_milestone(), which
-- deletes its row when the fact behind it is retracted. Un-checking baptism is
-- a correction: the claim was never true. Breaking a streak is not a
-- correction -- the youth genuinely did read for thirty days straight, and
-- taking that back would turn a record of their walk into a scoreboard that
-- punishes a bad week. Documented here so the difference from the sibling
-- function does not read as an oversight.
create or replace function private.sync_devotion_streak_milestone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role      public.user_role;
  v_streak    int;
  v_threshold int;
  v_existing  int;
begin
  select role into v_role from public.profiles where id = new.profile_id;
  if v_role is distinct from 'youth' then
    return null;
  end if;

  select current_streak into v_streak
    from private.progress_streak(new.profile_id);

  v_threshold := case
                   when v_streak >= 100 then 100
                   when v_streak >= 30  then 30
                   when v_streak >= 7   then 7
                   else null
                 end;

  if v_threshold is null then
    return null;
  end if;

  select streak_days into v_existing
    from public.milestones
   where profile_id = new.profile_id
     and milestone_type = 'devotion_streak'
     and auto_logged;

  -- Already recorded at this threshold or higher: nothing to say.
  if v_existing is not null and v_existing >= v_threshold then
    return null;
  end if;

  insert into public.milestones
    (profile_id, milestone_type, title, achieved_on, auto_logged, streak_days)
  values
    (new.profile_id, 'devotion_streak',
     v_threshold || '-day devotion streak', new.on_date, true, v_threshold)
  on conflict (profile_id, milestone_type) where auto_logged
  do update set title       = excluded.title,
                achieved_on = excluded.achieved_on,
                streak_days = excluded.streak_days;

  return null;
end;
$$;

-- ------------------------------------------------------------- triggers ---

-- Two triggers rather than one, for the reason 0007 gives: an INSERT trigger's
-- WHEN clause cannot read OLD, and an UPDATE that changes neither column must
-- not do work. The WHEN clauses also keep un-checking a box from running the
-- streak query for nothing.
drop trigger if exists trg_sync_devotion_streak_insert on public.daily_progress;
create trigger trg_sync_devotion_streak_insert
  after insert on public.daily_progress
  for each row
  when (new.devotional_done or new.scripture_done)
  execute function private.sync_devotion_streak_milestone();

drop trigger if exists trg_sync_devotion_streak_update on public.daily_progress;
create trigger trg_sync_devotion_streak_update
  after update of devotional_done, scripture_done on public.daily_progress
  for each row
  when (new.devotional_done is distinct from old.devotional_done
        or new.scripture_done is distinct from old.scripture_done)
  execute function private.sync_devotion_streak_milestone();

-- ------------------------------------------------------------- backfill ---

-- Youth who already had a qualifying streak before this migration. A no-op on
-- a fresh database; present for consistency with 0007 and so the file is safe
-- to re-apply.
--
-- Uses longest_streak rather than current_streak on purpose: the same
-- upward-only rule as the trigger, applied retrospectively. A youth who kept a
-- thirty-day streak in the spring has earned the row even if they are not on a
-- streak this week.
insert into public.milestones
  (profile_id, milestone_type, title, achieved_on, auto_logged, streak_days)
select p.id, 'devotion_streak', s.tier || '-day devotion streak',
       s.last_day, true, s.tier
  from public.profiles p
  cross join lateral private.progress_streak(p.id) st
  cross join lateral (
    select case when st.longest_streak >= 100 then 100
                when st.longest_streak >= 30  then 30
                when st.longest_streak >= 7   then 7 end as tier,
           (select max(on_date) from public.daily_progress d
             where d.profile_id = p.id
               and (d.devotional_done or d.scripture_done)) as last_day
  ) s
 where p.role = 'youth' and s.tier is not null
on conflict (profile_id, milestone_type) where auto_logged do nothing;
