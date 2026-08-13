-- ============================================================================
-- TrueAnchor — youth group chat
--
-- A youth pastor creates a group, adds youth from the same church. Each member
-- can send and read messages. The pastor manages the roster — youth cannot
-- add or remove members.
--
-- Separate from the 1-on-1 message_threads system: that model is hardcoded
-- to exactly two participants with per-column read receipts and cannot scale
-- to N. Group chat uses a members join table with per-row last_read_at.
--
-- Privacy: only group members see the group, its members, or its messages.
-- Parents are NOT included — group chat is youth + pastor only.
-- ============================================================================

-- --------------------------------------------------------------- tables ---

create table public.chat_groups (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches(id) on delete cascade,
  name        text not null check (length(btrim(name)) > 0),
  created_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create index on public.chat_groups (church_id);

create table public.chat_group_members (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.chat_groups(id) on delete cascade,
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz,
  joined_at    timestamptz not null default now(),
  constraint chat_group_members_unique unique (group_id, profile_id)
);

create index on public.chat_group_members (profile_id);
create index on public.chat_group_members (group_id);

create table public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.chat_groups(id) on delete cascade,
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null check (length(btrim(body)) > 0),
  created_at  timestamptz not null default now()
);

create index on public.chat_messages (group_id, created_at);

-- -------------------------------------------------------- helper function ---

create or replace function private.is_chat_group_member(p_group_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id
      and profile_id = (select auth.uid())
  )
$$;

-- ------------------------------------------------------------- triggers ---

create or replace function private.stamp_chat_group_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.created_by := (select auth.uid());
  select church_id into new.church_id
  from public.profiles where id = new.created_by;
  return new;
end;
$$;

create trigger trg_stamp_chat_group before insert on public.chat_groups
  for each row execute function private.stamp_chat_group_context();

create or replace function private.bump_chat_sender_read()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.chat_group_members
     set last_read_at = new.created_at
   where group_id = new.group_id
     and profile_id = new.sender_id;
  return null;
end;
$$;

create trigger trg_bump_chat_sender_read after insert on public.chat_messages
  for each row execute function private.bump_chat_sender_read();

-- ------------------------------------------------------------------ RLS ---

alter table public.chat_groups enable row level security;

create policy chat_groups_select_member on public.chat_groups
  for select to authenticated
  using (private.is_chat_group_member(id));

create policy chat_groups_update_creator on public.chat_groups
  for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()));

create policy chat_groups_delete_creator on public.chat_groups
  for delete to authenticated
  using (created_by = (select auth.uid()));

-- Members table: visible to co-members, updatable only for own row (read
-- receipt). INSERT and DELETE are handled by RPCs below.

alter table public.chat_group_members enable row level security;

create policy chat_members_select on public.chat_group_members
  for select to authenticated
  using (private.is_chat_group_member(group_id));

create policy chat_members_update_own on public.chat_group_members
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- Messages: readable by members, insertable by members, deletable within
-- 5 minutes (mirrors the 1-on-1 pattern).

alter table public.chat_messages enable row level security;

create policy chat_messages_select_member on public.chat_messages
  for select to authenticated
  using (private.is_chat_group_member(group_id));

create policy chat_messages_insert_member on public.chat_messages
  for insert to authenticated
  with check (sender_id = (select auth.uid())
              and private.is_chat_group_member(group_id));

create policy chat_messages_delete_own_recent on public.chat_messages
  for delete to authenticated
  using (sender_id = (select auth.uid())
         and created_at > now() - interval '5 minutes');

-- Profiles policy: group co-members can see each other's names.

create policy profiles_select_chat_group_partner on public.profiles
  for select to authenticated
  using (exists (
    select 1 from public.chat_group_members m1
    join public.chat_group_members m2 on m1.group_id = m2.group_id
    where m1.profile_id = public.profiles.id
      and m2.profile_id = (select auth.uid())
      and m1.profile_id <> m2.profile_id
  ));

-- --------------------------------------------------------------- RPCs ---

create or replace function public.create_chat_group(p_name text)
returns public.chat_groups
language plpgsql security definer set search_path = '' as $$
declare
  v_me    uuid := (select auth.uid());
  v_role  public.user_role;
  v_group public.chat_groups%rowtype;
begin
  select role into v_role from public.profiles where id = v_me;

  if v_role <> 'youth_pastor' then
    raise exception 'NOT_AUTHORIZED';
  end if;

  insert into public.chat_groups (name)
  values (btrim(p_name))
  returning * into v_group;

  insert into public.chat_group_members (group_id, profile_id)
  values (v_group.id, v_me);

  return v_group;
end;
$$;

revoke all on function public.create_chat_group(text) from public, anon;
grant execute on function public.create_chat_group(text) to authenticated;

create or replace function public.add_chat_group_member(
  p_group_id uuid,
  p_profile_id uuid
) returns public.chat_group_members
language plpgsql security definer set search_path = '' as $$
declare
  v_me        uuid := (select auth.uid());
  v_group     public.chat_groups%rowtype;
  v_target    public.profiles%rowtype;
  v_my_church uuid;
  v_member    public.chat_group_members%rowtype;
begin
  select * into v_group from public.chat_groups where id = p_group_id;
  if not found or v_group.created_by <> v_me then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select church_id into v_my_church from public.profiles where id = v_me;

  select * into v_target from public.profiles where id = p_profile_id;
  if not found
     or v_target.church_id is distinct from v_my_church
     or v_target.role <> 'youth' then
    raise exception 'INVALID_THREAD_PARTICIPANT';
  end if;

  insert into public.chat_group_members (group_id, profile_id)
  values (p_group_id, p_profile_id)
  on conflict (group_id, profile_id) do nothing
  returning * into v_member;

  if v_member.id is null then
    select * into v_member from public.chat_group_members
    where group_id = p_group_id and profile_id = p_profile_id;
  end if;

  return v_member;
end;
$$;

revoke all on function public.add_chat_group_member(uuid, uuid) from public, anon;
grant execute on function public.add_chat_group_member(uuid, uuid) to authenticated;

create or replace function public.remove_chat_group_member(
  p_group_id uuid,
  p_profile_id uuid
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_me    uuid := (select auth.uid());
  v_group public.chat_groups%rowtype;
begin
  select * into v_group from public.chat_groups where id = p_group_id;
  if not found or v_group.created_by <> v_me then
    raise exception 'NOT_AUTHORIZED';
  end if;

  if p_profile_id = v_me then
    raise exception 'NOT_AUTHORIZED';
  end if;

  delete from public.chat_group_members
  where group_id = p_group_id and profile_id = p_profile_id;
end;
$$;

revoke all on function public.remove_chat_group_member(uuid, uuid) from public, anon;
grant execute on function public.remove_chat_group_member(uuid, uuid) to authenticated;
