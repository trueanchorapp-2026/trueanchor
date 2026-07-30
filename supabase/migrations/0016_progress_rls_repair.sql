-- ============================================================================
-- TrueAnchor — repair of the daily_progress triggers and policies
--
-- public.daily_progress exists but writes are refused with
--
--     42501: new row violates row-level security policy
--
-- rather than a not-null violation on church_id. Postgres evaluates an RLS
-- WITH CHECK *before* it checks NOT NULL, and the app deliberately never sends
-- profile_id -- so that specific error is the signature of trg_stamp_progress
-- not being installed: profile_id arrives null, `null = auth.uid()` is null,
-- and progress_upsert_own refuses the row before the not-null constraint on
-- church_id ever gets a look.
--
-- This file re-applies everything in 0011 EXCEPT the table itself, which is
-- why it can be run against a database where some, all, or none of these
-- objects are already present. Every statement is create-or-replace or
-- drop-if-exists-then-create. Running it twice changes nothing the second time.
--
-- Nothing here is a new decision. If you are reading this to learn what the
-- rules are, read 0011 -- this is a copy, kept in step with it by hand.
-- ============================================================================

-- ------------------------------------------------------------- triggers ---

create or replace function private.stamp_progress_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.profile_id := (select auth.uid());
  select church_id, family_id into new.church_id, new.family_id
  from public.profiles where id = new.profile_id;
  return new;
end;
$$;

drop trigger if exists trg_stamp_progress on public.daily_progress;
create trigger trg_stamp_progress before insert on public.daily_progress
  for each row execute function private.stamp_progress_context();

drop trigger if exists trg_daily_progress_touch on public.daily_progress;
create trigger trg_daily_progress_touch before update on public.daily_progress
  for each row execute function private.touch_updated_at();

-- ------------------------------------------------------------------ RLS ---

alter table public.daily_progress enable row level security;

drop policy if exists progress_select_own on public.daily_progress;
create policy progress_select_own on public.daily_progress
  for select to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists progress_select_parents on public.daily_progress;
create policy progress_select_parents on public.daily_progress
  for select to authenticated
  using ((select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

drop policy if exists progress_select_pastor on public.daily_progress;
create policy progress_select_pastor on public.daily_progress
  for select to authenticated
  using ((select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

drop policy if exists progress_upsert_own on public.daily_progress;
create policy progress_upsert_own on public.daily_progress
  for insert to authenticated
  with check (profile_id = (select auth.uid())
              and on_date between current_date - 1 and current_date + 1);

drop policy if exists progress_update_own on public.daily_progress;
create policy progress_update_own on public.daily_progress
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid())
              and on_date between current_date - 1 and current_date + 1);

-- Still no delete policy, on purpose: un-checking a box is an update to false.

-- ------------------------------------------------------------- streaks ---

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
       and on_date  > p_as_of - 400
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
    coalesce((select len from runs
               where ended_on >= p_as_of - 1
               order by ended_on desc
               limit 1), 0),
    coalesce((select max(len) from runs), 0),
    (7 - (select count(*) from days where on_date > p_as_of - 7))::int
$$;

-- --------------------------------------------------------------- proof ---
-- Two triggers and five policies. Anything short of that means this file did
-- not finish, and the check-off will still fail.

select tgname from pg_trigger
 where tgrelid = 'public.daily_progress'::regclass and not tgisinternal
 order by tgname;

select polname from pg_policy
 where polrelid = 'public.daily_progress'::regclass
 order by polname;
