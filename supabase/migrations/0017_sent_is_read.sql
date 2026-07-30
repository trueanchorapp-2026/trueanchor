-- ============================================================================
-- TrueAnchor — a message you sent is a message you have read
--
-- The reported symptom is the unread badge lighting up for your own message.
-- Fixing it properly means fixing the thing underneath it first.
--
--   1. private.bump_thread_activity() updates public.message_threads, and
--      EVERY update to that table passes through trg_guard_thread first --
--      including this one. Postgres does not exempt a write just because it
--      came from another trigger. The guard ends with
--
--          new.last_message_at := old.last_message_at;
--
--      unconditionally, so it reverts the one column the bump exists to set.
--      last_message_at has therefore never moved off the thread's creation
--      time: the inbox is ordered by when conversations STARTED, not by when
--      they last had anything in them, and a thread marked read once stays
--      read no matter what arrives afterwards.
--
--   2. With the bump landing, last_message_at moves on every message --
--      including yours. Your own message would then sit past your own receipt
--      and read as unread to you until you reopened the thread. Sending is
--      proof you have read everything before it, so the same statement
--      advances the sender's receipt. Only the sender's: the other side stays
--      unread, which is the entire purpose of the column.
--
-- Fixing (2) alone would have been a client-side patch over a server-side
-- fault -- correct until the second device, the push notification, or the
-- email digest asks the database the same question and gets the old answer.
-- ============================================================================

-- The guard is right to distrust anything a client sends; it simply cannot
-- tell a client apart from the trigger standing behind it. So it gets the same
-- escape hatch private.guard_profile_columns() has used since 0002, and it is
-- equally unreachable from outside: the flag is only ever set inside a
-- security definer function in the private schema, which `revoke all on schema
-- private from anon, authenticated` (0001) puts out of a client's reach.
--
-- Everything below the bypass is byte-identical to 0013.
create or replace function private.guard_thread_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('app.bypass_thread_guard', true), '') = 'on' then
    return new;
  end if;

  new.member_id  := old.member_id;
  new.pastor_id  := old.pastor_id;
  new.church_id  := old.church_id;
  new.created_at := old.created_at;

  -- Each side may write only its own read receipt. last_message_at belongs to
  -- the trigger below, never to a client.
  if (select auth.uid()) = old.member_id then
    new.pastor_last_read_at := old.pastor_last_read_at;
  elsif (select auth.uid()) = old.pastor_id then
    new.member_last_read_at := old.member_last_read_at;
  else
    new.member_last_read_at := old.member_last_read_at;
    new.pastor_last_read_at := old.pastor_last_read_at;
  end if;

  new.last_message_at := old.last_message_at;
  return new;
end;
$$;

-- Orders the inbox, and settles the sender's own receipt in the same
-- statement.
--
-- The two belong together: they are the same fact about the same message, and
-- splitting them would leave a window -- however short -- in which the sender
-- has an unread badge for something they just wrote.
create or replace function private.bump_thread_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('app.bypass_thread_guard', 'on', true);

  update public.message_threads
     set last_message_at = new.created_at,
         member_last_read_at = case
           when new.sender_id = member_id then new.created_at
           else member_last_read_at
         end,
         pastor_last_read_at = case
           when new.sender_id = pastor_id then new.created_at
           else pastor_last_read_at
         end
   where id = new.thread_id;

  -- Cleared rather than left standing. set_config(..., true) is transaction
  -- local, and PostgREST can put more than one statement in a transaction --
  -- a client update arriving after this one must still meet the guard.
  perform set_config('app.bypass_thread_guard', 'off', true);
  return null;
end;
$$;

-- --------------------------------------------------------------- backfill ---

-- Every thread that has ever carried a message has the wrong last_message_at,
-- because the bump never landed. Left alone, the inbox stays sorted by
-- creation date and old threads read as permanently read.
--
-- This update meets trg_guard_thread like any other -- a trigger does not care
-- which role issued the statement -- so it would revert itself exactly the way
-- the bump did without the bypass. Session-scoped rather than transaction
-- scoped so it survives however the migration runner wraps this file, and
-- turned off again the moment the statement is done.
select set_config('app.bypass_thread_guard', 'on', false);

-- Receipts are rebuilt in the same pass: a participant is credited up to their
-- own last message, or left where they are if that is already later. Nobody is
-- marked as having read something they did not send. greatest() ignores nulls
-- in PostgreSQL, so a participant who never sent or never read stays null.
with activity as (
  select m.thread_id,
         max(m.created_at)                                        as last_at,
         max(m.created_at) filter (where m.sender_id = t.member_id)
                                                                  as member_sent_at,
         max(m.created_at) filter (where m.sender_id = t.pastor_id)
                                                                  as pastor_sent_at
    from public.messages m
    join public.message_threads t on t.id = m.thread_id
   group by m.thread_id, t.member_id, t.pastor_id
)
update public.message_threads t
   set last_message_at     = activity.last_at,
       member_last_read_at = greatest(t.member_last_read_at,
                                      activity.member_sent_at),
       pastor_last_read_at = greatest(t.pastor_last_read_at,
                                      activity.pastor_sent_at)
  from activity
 where activity.thread_id = t.id;

select set_config('app.bypass_thread_guard', 'off', false);

comment on function private.bump_thread_activity() is
  'Orders the inbox and settles the sender''s own read receipt. Bypasses '
  'trg_guard_thread via app.bypass_thread_guard, which no client can set.';
