-- ============================================================================
-- TrueAnchor — private messaging with the youth pastor
--
-- A thread is readable by exactly two people: the member and their youth
-- pastor. Nobody else.
--
-- Not the youth's parents. That is the hardest line in this file and it is
-- deliberate: a youth who cannot ask a hard question without their parents
-- reading the answer will not ask it, and the question they cannot ask is
-- usually the one that matters. CLAUDE.md names parents as the primary
-- disciple-makers and it also names privacy balanced with accountability --
-- this is where the second half of that sentence does its work. Parents can
-- still see the journal entries their youth chooses to share (0009); a message
-- to a pastor is not that.
--
-- Not the church admin either, for the reason 0009 gives: administration is
-- not pastoral care.
--
-- The platform's app_admin CAN reach the contents, for legal and safety
-- reasons -- but never through this table. There is no app_admin policy here.
-- Access goes through public.admin_read_thread() in 0014, which writes an
-- audit row before it returns anything. An RLS policy cannot log, because a
-- policy expression must be side-effect free; that is exactly why the admin
-- path is a function instead.
--
-- Messages are never edited. A sender may delete their own within five
-- minutes, for "sent to the wrong person" and "hit send early"; after that the
-- conversation is a record, which is what makes legal review meaningful.
-- ============================================================================

-- --------------------------------------------------------------- tables ---

create table public.message_threads (
  id                  uuid primary key default gen_random_uuid(),
  church_id           uuid not null references public.churches(id) on delete cascade,
  member_id           uuid not null references public.profiles(id) on delete cascade,
  pastor_id           uuid not null references public.profiles(id) on delete cascade,
  created_at          timestamptz not null default now(),
  last_message_at     timestamptz not null default now(),
  member_last_read_at timestamptz,
  pastor_last_read_at timestamptz,
  -- One conversation per pair. "Message my pastor" is idempotent because of
  -- this: open_thread() arbitrates on it rather than starting a second thread.
  constraint message_threads_pair unique (member_id, pastor_id),
  constraint message_threads_distinct check (member_id <> pastor_id)
);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references public.message_threads(id) on delete cascade,
  sender_id  uuid not null references public.profiles(id)        on delete cascade,
  body       text not null check (length(btrim(body)) > 0),
  created_at timestamptz not null default now()
);

-- Both inbox orderings, plus the thread transcript.
create index on public.message_threads (pastor_id, last_message_at desc);
create index on public.message_threads (member_id, last_message_at desc);
create index on public.messages (thread_id, created_at);

-- ------------------------------------------------------------- helpers ---

-- Must exist before the messages policies below, which call it: Postgres
-- resolves a policy's function references when the policy is created, not when
-- it first runs.
--
-- security definer so the messages policies can test thread membership without
-- recursing back through the message_threads policies.
--
-- Note the asymmetry with private.current_church_id() and friends: this takes
-- a column as its argument, so it is correlated per row and CANNOT be wrapped
-- in the (select ...) InitPlan trick the other policies use. It is kept to a
-- single primary-key lookup for exactly that reason.
create or replace function private.can_read_thread(p_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.message_threads t
     where t.id = p_thread_id
       and ((select auth.uid()) in (t.member_id, t.pastor_id))
  )
$$;

-- Lives in the private schema, so it needs no grant: policy evaluation reaches
-- it the same way the existing private.current_app_role() calls do, despite
-- `revoke all on schema private from anon, authenticated` in 0001.

-- ------------------------------------------------------------------ RLS ---

alter table public.message_threads enable row level security;
alter table public.messages        enable row level security;

-- Two people. No role test, no church test, no family test -- the absence of a
-- parent branch here is the feature, exactly as journal_select_family's
-- absence of a role test was in 0009.
create policy threads_select_participant on public.message_threads
  for select to authenticated
  using (member_id = (select auth.uid()) or pastor_id = (select auth.uid()));

-- No insert policy on message_threads at all: threads are opened through
-- public.open_thread() below. A member cannot see a youth pastor's profile to
-- pick one from -- profiles_select_staff (0006) grants staff-only reads, and
-- staff have no family_id so profiles_select_family never matches them -- so
-- there is nothing sensible for a client-side insert to reference.

-- Read receipts are the only thing either participant may change; the column
-- guard below enforces which one.
create policy threads_update_participant on public.message_threads
  for update to authenticated
  using (member_id = (select auth.uid()) or pastor_id = (select auth.uid()))
  with check (member_id = (select auth.uid()) or pastor_id = (select auth.uid()));

create policy messages_select_participant on public.messages
  for select to authenticated
  using (private.can_read_thread(thread_id));

create policy messages_insert_participant on public.messages
  for insert to authenticated
  with check (sender_id = (select auth.uid())
              and private.can_read_thread(thread_id));

-- A five-minute window, and only over your own messages. There is no update
-- policy at any point: a message is never rewritten, only withdrawn quickly or
-- kept.
create policy messages_delete_own_recent on public.messages
  for delete to authenticated
  using (sender_id = (select auth.uid())
         and created_at > now() - interval '5 minutes');

-- Without this a member sees a thread whose other party has no name: they are
-- not allowed to read staff profiles. Narrow on purpose -- it exposes exactly
-- the people you are already in a conversation with.
--
-- Not recursive: the message_threads policies test auth.uid() directly and
-- never read back into profiles.
create policy profiles_select_thread_partner on public.profiles
  for select to authenticated
  using (exists (
    select 1 from public.message_threads t
     where (t.member_id = public.profiles.id and t.pastor_id = (select auth.uid()))
        or (t.pastor_id = public.profiles.id and t.member_id = (select auth.uid()))
  ));

-- ------------------------------------------------------------- triggers ---

-- RLS controls which ROWS you may update, not which COLUMNS. Without this a
-- participant could PATCH a thread to point at someone else, or mark the other
-- party's messages as read. Same idea as private.guard_profile_columns().
create or replace function private.guard_thread_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
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

create trigger trg_guard_thread before update on public.message_threads
  for each row execute function private.guard_thread_columns();

-- Keeps the inbox ordered without the client having to write a column the
-- guard above would revert anyway.
create or replace function private.bump_thread_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.message_threads
     set last_message_at = new.created_at
   where id = new.thread_id;
  return null;
end;
$$;

create trigger trg_bump_thread_activity after insert on public.messages
  for each row execute function private.bump_thread_activity();

-- ------------------------------------------------- client-callable RPCs ---

-- Members cannot read staff profiles, so they cannot pick a pastor from a
-- directory they are not allowed to see. Same shape as
-- church_has_youth_pastor() in 0009: security definer, returning only what the
-- picker needs and no more.
create or replace function public.church_youth_pastors()
returns table (id uuid, first_name text, last_name text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.first_name, p.last_name
    from public.profiles p
   where p.church_id = (select private.current_church_id())
     and p.role = 'youth_pastor'
   order by p.first_name, p.last_name
$$;

revoke all on function public.church_youth_pastors() from public, anon;
grant execute on function public.church_youth_pastors() to authenticated;

-- Opens the conversation, or returns the existing one.
--
-- Idempotent by design: the UI never has to distinguish "start a thread" from
-- "open my thread", and a double tap cannot produce two conversations.
--
-- p_with_id null means "my youth pastor" -- the church's longest-serving one.
-- A church with two youth pastors should offer a picker (see
-- church_youth_pastors()); a member who picks nothing gets a real person
-- rather than an error.
create or replace function public.open_thread(p_with_id uuid default null)
returns public.message_threads
language plpgsql security definer set search_path = '' as $$
declare
  v_me      uuid := (select auth.uid());
  v_role    public.user_role;
  v_church  uuid;
  v_member  uuid;
  v_pastor  uuid;
  v_target  public.profiles%rowtype;
  v_thread  public.message_threads%rowtype;
begin
  select role, church_id into v_role, v_church
    from public.profiles where id = v_me;

  if v_role in ('parent', 'youth') then
    if p_with_id is null then
      select * into v_target from public.profiles
       where church_id = v_church and role = 'youth_pastor'
       order by created_at
       limit 1;
      if not found then
        raise exception 'NO_YOUTH_PASTOR';
      end if;
    else
      select * into v_target from public.profiles where id = p_with_id;
      if not found
         or v_target.church_id is distinct from v_church
         or v_target.role <> 'youth_pastor' then
        raise exception 'INVALID_THREAD_PARTICIPANT';
      end if;
    end if;
    v_member := v_me;
    v_pastor := v_target.id;

  elsif v_role = 'youth_pastor' then
    -- A pastor must name who they are writing to; there is no sensible default.
    select * into v_target from public.profiles where id = p_with_id;
    if not found
       or v_target.church_id is distinct from v_church
       or v_target.role not in ('parent', 'youth') then
      raise exception 'INVALID_THREAD_PARTICIPANT';
    end if;
    v_member := v_target.id;
    v_pastor := v_me;

  else
    -- church_admin and app_admin. Not an oversight: see the banner.
    raise exception 'ROLE_CANNOT_MESSAGE';
  end if;

  insert into public.message_threads (church_id, member_id, pastor_id)
  values (v_church, v_member, v_pastor)
  on conflict (member_id, pastor_id)
    do update set member_id = excluded.member_id   -- no-op, to force RETURNING
  returning * into v_thread;

  return v_thread;
end;
$$;

revoke all on function public.open_thread(uuid) from public, anon;
grant execute on function public.open_thread(uuid) to authenticated;
