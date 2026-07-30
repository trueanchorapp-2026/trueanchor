-- ============================================================================
-- DESTRUCTIVE. Drops the messaging tables so 0013 and 0014 can be applied
-- cleanly from the top.
--
-- Why this rather than a repair file in the style of 0016: 0013 landed its
-- tables but none of its policies, which means an unknown amount of the rest of
-- the file -- the two guard triggers, can_read_thread(), open_thread() -- is
-- also missing. Repairing piecemeal means guessing at which half is there. The
-- tables are empty (open_thread() never worked, so no thread was ever opened),
-- so there is nothing to preserve and re-running the real migration is both
-- simpler and more trustworthy than patching around it.
--
-- STOP if either count below is non-zero. A non-zero count means someone did
-- manage to send something, and this script would delete a minor's private
-- conversation. Come back and write a repair instead.
--
-- The cascades are doing real work, not being defensive:
--   * open_thread() returns `public.message_threads`, so it is dropped with it
--   * profiles_select_thread_partner reads message_threads, so it goes too
--   * message_access_log has an FK to message_threads, hence dropping it first
-- Everything dropped here is recreated by 0013 and 0014.
-- ============================================================================

select (select count(*) from public.message_threads) as threads_that_will_be_lost,
       (select count(*) from public.messages)        as messages_that_will_be_lost;

drop table if exists public.message_access_log cascade;
drop table if exists public.messages           cascade;
drop table if exists public.message_threads    cascade;

-- Belt and braces: these are `create or replace` in 0013, so a stale copy left
-- behind by the partial apply would survive the table drops and silently shadow
-- the real one.
drop function if exists public.open_thread(uuid);
drop function if exists public.church_youth_pastors();
drop function if exists public.admin_read_thread(uuid, text);
drop function if exists private.can_read_thread(uuid);
drop function if exists private.guard_thread_columns();
drop function if exists private.bump_thread_activity();

-- Should both come back empty.
select tablename  from pg_tables    where tablename  in ('message_threads', 'messages', 'message_access_log');
select proname    from pg_proc      where proname    in ('open_thread', 'church_youth_pastors', 'admin_read_thread', 'can_read_thread');
