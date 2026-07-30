-- ============================================================================
-- TrueAnchor — daily progress tracking
--
-- One row per person per day, carrying two booleans: did they read the
-- devotional, and did they read Scripture. That is the entire model.
--
-- What is deliberately NOT here is time tracking. "Minutes in app" would be
-- easy to add and would work against the mission — the principle is Scripture
-- engagement over app engagement, and a youth who reads their Bible on paper
-- for forty minutes must not score worse than one who leaves the app open. It
-- is also screen-time telemetry on minors, which is a liability nobody asked
-- for.
--
-- Visibility mirrors the journal's parents-and-pastor rung from 0009: the youth
-- themselves, parents in the same family, and the youth pastor of the same
-- church. church_admin gets nothing, for the same reason it lost journal reads
-- there — administration is not pastoral care.
--
-- This file also defines private.progress_streak(), the gaps-and-islands streak
-- calculation that 0012 (auto-milestones) and 0015 (the pastor dashboard) both
-- build on. It is never called from the client: the app computes its own user's
-- streak in Dart from rows it already has, which saves a round trip on the most
-- visited screen in the app. The two implementations are documented mirrors of
-- each other — see ProgressStreak.from in progress_streak.dart.
-- ============================================================================

-- --------------------------------------------------------------- tables ---

create table public.daily_progress (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null references public.profiles(id)    on delete cascade,
  church_id       uuid not null references public.churches(id)    on delete cascade,
  family_id       uuid references public.families(id)             on delete set null,
  devotional_id   uuid references public.devotionals(id)          on delete set null,
  on_date         date not null default current_date,
  devotional_done boolean not null default false,
  scripture_done  boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- The upsert arbiter: one row per person per day, so checking a box twice
-- updates rather than duplicates.
create unique index daily_progress_key on public.daily_progress (profile_id, on_date);

-- The pastor dashboard scans by church; the parent view scans by family.
create index on public.daily_progress (church_id, on_date desc);
create index on public.daily_progress (family_id, on_date desc);

-- devotional_id is nullable and on delete set null: a youth can mark Scripture
-- reading on a day with no published devotional, and retiring old content must
-- never erase the record that someone showed up.

-- ------------------------------------------------------------- triggers ---

-- Same shape as private.stamp_journal_context() in 0001. Forces profile_id to
-- the caller and derives church_id/family_id from that profile, so a client
-- cannot check off someone else's day or tag a row to another church even
-- before RLS gets a look at it.
create or replace function private.stamp_progress_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.profile_id := (select auth.uid());
  select church_id, family_id into new.church_id, new.family_id
  from public.profiles where id = new.profile_id;
  return new;
end;
$$;

create trigger trg_stamp_progress before insert on public.daily_progress
  for each row execute function private.stamp_progress_context();

create trigger trg_daily_progress_touch before update on public.daily_progress
  for each row execute function private.touch_updated_at();

-- ------------------------------------------------------------------ RLS ---

alter table public.daily_progress enable row level security;

create policy progress_select_own on public.daily_progress
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- No role test beyond parent: family_id is stamped by the trigger, so matching
-- it is already the household test.
create policy progress_select_parents on public.daily_progress
  for select to authenticated
  using ((select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

create policy progress_select_pastor on public.daily_progress
  for select to authenticated
  using ((select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

-- Self-only writes, with the date fenced. A youth cannot back-fill a month to
-- manufacture a streak. The +/- 1 day is the timezone allowance -- a client in
-- California legitimately calls "today" a date the server's UTC clock has
-- already left, or not yet reached -- not a grace period for catching up.
create policy progress_upsert_own on public.daily_progress
  for insert to authenticated
  with check (profile_id = (select auth.uid())
              and on_date between current_date - 1 and current_date + 1);

create policy progress_update_own on public.daily_progress
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid())
              and on_date between current_date - 1 and current_date + 1);

-- No delete policy, on purpose. Un-checking a box is an update to false, and a
-- deleted row would be indistinguishable from a day the person never opened --
-- which would let anyone quietly erase a bad week from a pastor's view.

-- ------------------------------------------------------------- streaks ---

-- A day counts when the person engaged at all -- devotional OR Scripture, not
-- both. The mission is Scripture engagement, not compliance with a two-box
-- form, and a stricter rule would punish the youth who read their Bible but
-- skipped the discussion questions.
--
-- The row_number() subtraction is the standard gaps-and-islands trick: across a
-- run of consecutive dates, (on_date - row_number()) is constant, so grouping
-- by it yields exactly one group per unbroken run.
create or replace function private.progress_streak(
  p_profile_id uuid,
  p_as_of      date default current_date
) returns table (current_streak int, longest_streak int, missed_last_7 int)
language sql stable security definer set search_path = '' as $$
  with days as (
    select on_date
      from public.daily_progress
     where profile_id = p_profile_id
       and on_date <= p_as_of
       and on_date  > p_as_of - 400          -- bounds the scan; ~13 months
       and (devotional_done or scripture_done)
  ),
  runs as (
    select count(*)::int as len, max(on_date) as ended_on
      from (
        select on_date,
               on_date - (row_number() over (order by on_date))::int as grp
          from days
      ) g
     group by grp
  )
  select
    -- A run counts as *current* only if it reaches today or yesterday: someone
    -- who simply has not opened the app yet this morning still has their streak.
    coalesce((select len from runs
               where ended_on >= p_as_of - 1
               order by ended_on desc
               limit 1), 0),
    coalesce((select max(len) from runs), 0),
    (7 - (select count(*) from days where on_date > p_as_of - 7))::int
$$;
