-- ============================================================================
-- TrueAnchor — audited platform access to private messages
--
-- 0013 promises a youth that only they and their youth pastor can read a
-- thread, with one stated exception: TrueAnchor's own app_admin, for safety and
-- legal reasons. This file is what makes the rest of that promise -- "and every
-- access is recorded" -- true rather than a claim in a banner.
--
-- Why a function and not a policy. An RLS policy expression must be
-- side-effect free: Postgres may evaluate it any number of times per row, in
-- any order, and it cannot write. So a policy can grant app_admin the read, but
-- it cannot log it. Auditing therefore means the admin reads through
-- public.admin_read_thread() instead of through the table.
--
-- The cost is real and worth naming: the admin path cannot reuse the pastor's
-- messaging screens, because those query public.messages directly and RLS will
-- return an app_admin nothing. The alternative is unlogged platform-wide access
-- to minors' private conversations, which is not a trade this project should
-- make.
--
-- Separated from 0013 on purpose. If the audit design changes, this file can be
-- rewritten or dropped without unpicking the messaging schema.
--
-- No Dart work this phase. There is no app_admin surface in the app yet, so the
-- function is exercised from the Supabase SQL Editor:
--
--   select * from public.admin_read_thread(
--     '<thread uuid>', 'Safeguarding report #123');
--
-- Log rows are permanent by design: no update policy, no delete policy, for
-- anyone. An audit trail its subject can edit is not an audit trail.
-- ============================================================================

-- --------------------------------------------------------------- tables ---

create table public.message_access_log (
  id            uuid primary key default gen_random_uuid(),
  thread_id     uuid not null references public.message_threads(id) on delete cascade,
  read_by       uuid not null references public.profiles(id)        on delete restrict,
  read_at       timestamptz not null default now(),
  message_count int not null,
  reason        text not null check (length(btrim(reason)) > 0)
);

-- on delete restrict above, not cascade: deleting an admin account must not
-- silently erase the record of what that account read.

create index on public.message_access_log (thread_id, read_at desc);
create index on public.message_access_log (read_by, read_at desc);

-- ------------------------------------------------------------------ rls ---

alter table public.message_access_log enable row level security;

-- Readable by the platform role only. A pastor cannot see who reviewed their
-- threads, and a member cannot either -- both are legitimate questions, but the
-- answer to them is a support conversation, not a query.
create policy message_access_log_select on public.message_access_log
  for select to authenticated
  using ((select private.current_app_role()) = 'app_admin');

-- No insert, update or delete policy at any point. The only writer is
-- admin_read_thread(), which is security definer and therefore bypasses these
-- policies entirely. A client cannot forge a reason, backdate a read, or write
-- a log row for a thread it never opened.

-- ------------------------------------------------------------- function ---

-- Volatile, not stable: it writes before it reads, and marking it stable would
-- let the planner skip or reorder that write.
--
-- The audit row is inserted BEFORE the messages are returned. If the insert
-- fails the caller gets nothing, which is the correct direction for the failure
-- to point: no log, no access.
create or replace function public.admin_read_thread(
  p_thread_id uuid,
  p_reason    text
)
returns table (
  id         uuid,
  sender_id  uuid,
  body       text,
  created_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  if (select private.current_app_role()) is distinct from 'app_admin' then
    raise exception 'NOT_AUTHORIZED';
  end if;

  -- A reason is not optional. "Who read this and why" is the whole point of the
  -- log; a blank reason would make it a list of timestamps.
  if p_reason is null or length(btrim(p_reason)) = 0 then
    raise exception 'REASON_REQUIRED';
  end if;

  -- Fails loudly on a bad id rather than logging an access to nothing.
  if not exists (select 1 from public.message_threads t where t.id = p_thread_id)
  then
    raise exception 'THREAD_NOT_FOUND';
  end if;

  select count(*) into v_count
    from public.messages m where m.thread_id = p_thread_id;

  insert into public.message_access_log
    (thread_id, read_by, message_count, reason)
  values
    (p_thread_id, (select auth.uid()), v_count, btrim(p_reason));

  return query
    select m.id, m.sender_id, m.body, m.created_at
      from public.messages m
     where m.thread_id = p_thread_id
     order by m.created_at;
end;
$$;

revoke all on function public.admin_read_thread(uuid, text) from public, anon;
grant execute on function public.admin_read_thread(uuid, text) to authenticated;

comment on function public.admin_read_thread(uuid, text) is
  'Platform-level read of a private message thread. app_admin only. Writes a '
  'public.message_access_log row before returning anything.';
