-- ============================================================================
-- Diagnostic: why does checking a box on /today come back "You don't have
-- permission to do that"?
--
-- That message is the 42501 branch of mapError() in app_exception.dart, i.e.
-- Postgres refused the write. The app sends only (on_date, devotional_done,
-- scripture_done, devotional_id) and lets trg_stamp_progress fill in
-- profile_id / church_id / family_id, so a refusal means one of three things:
--
--   A. the INSERT policy `progress_upsert_own` is not there
--   B. the stamping trigger is not there, so profile_id never gets set
--   C. `authenticated` has no INSERT privilege on the table
--
-- Run part 1 to see which. Run part 2 to see the verbatim error.
-- Nothing here writes anything that survives -- part 2 rolls back.
-- ============================================================================

-- ------------------------------------------------------------------ 1 ---
-- What is actually installed. Expect four policies (progress_select_own,
-- progress_select_parents, progress_select_pastor, progress_upsert_own,
-- progress_update_own -- five in total), two triggers, and true/true/true.

select polname,
       case polcmd when 'r' then 'select' when 'a' then 'insert'
                   when 'w' then 'update' when 'd' then 'delete'
                   else 'all' end                       as command,
       pg_get_expr(polqual,      polrelid)              as using_expr,
       pg_get_expr(polwithcheck, polrelid)              as with_check_expr
  from pg_policy
  join pg_class c on c.oid = polrelid
 where c.relname = 'daily_progress'
 order by polname;

select tgname, tgenabled
  from pg_trigger
 where tgrelid = 'public.daily_progress'::regclass
   and not tgisinternal
 order by tgname;

select has_table_privilege('authenticated', 'public.daily_progress', 'select') as can_select,
       has_table_privilege('authenticated', 'public.daily_progress', 'insert') as can_insert,
       has_table_privilege('authenticated', 'public.daily_progress', 'update') as can_update;

-- Sanity check on the date fence in progress_upsert_own. The app sends the
-- *client's* local date; the database compares it to its own current_date.
-- These must be within one day of each other.
select current_date as db_today, current_setting('TimeZone') as db_timezone;

-- ------------------------------------------------------------------ 2 ---
-- Reproduce the failure as the signed-in user and read the real error text,
-- which the app throws away in favour of friendly wording.
--
-- Replace the uuid below with your own: select id, email, role from
-- public.profiles where email = 'you@example.com';

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  -- Should return your uuid. If it is null, the claims line above is wrong and
  -- everything below will fail for that reason rather than the real one.
  select auth.uid() as acting_as;

  insert into public.daily_progress (on_date, devotional_done, scripture_done)
  values (current_date, true, false);
rollback;
