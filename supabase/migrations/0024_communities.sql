-- ============================================================================
-- TrueAnchor — Communities, memberships, news, discussions, events
--
-- Depends on 0021_regional_admin_tables.sql (regions table).
--
-- Communities are city-level groups within regions. Any family can join one
-- community regardless of church affiliation. Only adults see community
-- features. Community Admin is a contextual role within memberships — an
-- existing parent elevated by a Regional Admin.
-- ============================================================================

-- ============================================================================
-- A. Communities table
-- ============================================================================
create table public.communities (
  id         uuid primary key default gen_random_uuid(),
  region_id  uuid not null references public.regions(id) on delete cascade,
  name       text not null check (trim(name) <> ''),
  city       text,
  state      text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (region_id, name)
);

alter table public.communities enable row level security;

create policy communities_select on public.communities
  for select to authenticated using (true);

create policy communities_insert on public.communities
  for insert to authenticated
  with check (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

create policy communities_update on public.communities
  for update to authenticated
  using (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  )
  with check (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

create policy communities_delete on public.communities
  for delete to authenticated
  using (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

-- Stamp created_by on insert.
create or replace function private.stamp_community_creator()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.created_by := (select auth.uid());
  return new;
end;
$$;

create trigger trg_stamp_community_creator
  before insert on public.communities
  for each row execute function private.stamp_community_creator();

-- ============================================================================
-- B. Community memberships (per-family, one community per family)
-- ============================================================================
create table public.community_memberships (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  family_id    uuid not null references public.families(id) on delete cascade,
  joined_by    uuid not null references public.profiles(id),
  is_admin     boolean not null default false,
  joined_at    timestamptz not null default now(),
  unique (family_id)
);

create index idx_community_memberships_community
  on public.community_memberships(community_id);

alter table public.community_memberships enable row level security;

-- Helper: is the caller's family a member of a given community?
create or replace function private.is_community_member(p_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.community_memberships
    where community_id = p_community_id
      and family_id = (select private.current_family_id())
  )
$$;

-- Helper: is the caller a community admin for a given community?
create or replace function private.is_community_admin(p_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.community_memberships
    where community_id = p_community_id
      and family_id = (select private.current_family_id())
      and is_admin = true
  )
$$;

-- Helper: the community_id for the caller's family (or NULL).
create or replace function private.community_id_for_user()
returns uuid language sql stable security definer set search_path = '' as $$
  select community_id from public.community_memberships
  where family_id = (select private.current_family_id())
$$;

-- Members can see other members in the same community.
create policy community_memberships_select on public.community_memberships
  for select to authenticated
  using (
    community_id = (select private.community_id_for_user())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- No direct INSERT policy — use join_community RPC.
-- Members can leave (delete own membership).
create policy community_memberships_delete_own on public.community_memberships
  for delete to authenticated
  using (
    joined_by = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- Regional admin can update is_admin.
create policy community_memberships_update on public.community_memberships
  for update to authenticated
  using (
    (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- ============================================================================
-- C. RPCs for community operations
-- ============================================================================

-- Join a community (head of household only).
create or replace function public.join_community(p_community_id uuid)
returns public.community_memberships
language plpgsql security definer set search_path = '' as $$
declare
  v_uid       uuid := (select auth.uid());
  v_profile   public.profiles%rowtype;
  v_family    public.families%rowtype;
  v_membership public.community_memberships%rowtype;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_profile from public.profiles where id = v_uid;
  if not found then raise exception 'NO_PROFILE'; end if;

  -- Must be an adult role.
  if v_profile.role = 'youth' then
    raise exception 'YOUTH_NOT_ALLOWED';
  end if;

  if v_profile.family_id is null then
    raise exception 'NO_FAMILY';
  end if;

  -- Must be head of household.
  select * into v_family from public.families where id = v_profile.family_id;
  if v_family.head_of_household_id <> v_uid then
    raise exception 'NOT_HEAD_OF_HOUSEHOLD';
  end if;

  -- Check community exists.
  if not exists (select 1 from public.communities where id = p_community_id) then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;

  -- Idempotent: if already in this community, return existing.
  select * into v_membership
  from public.community_memberships
  where family_id = v_profile.family_id;

  if found then
    if v_membership.community_id = p_community_id then
      return v_membership;
    end if;
    -- Switch communities: remove old, create new.
    delete from public.community_memberships where id = v_membership.id;
  end if;

  insert into public.community_memberships (community_id, family_id, joined_by)
  values (p_community_id, v_profile.family_id, v_uid)
  returning * into v_membership;

  return v_membership;
end;
$$;

grant execute on function public.join_community(uuid) to authenticated;

-- Leave a community.
create or replace function public.leave_community()
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := (select auth.uid());
  v_family_id uuid;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;

  select family_id into v_family_id from public.profiles where id = v_uid;
  if v_family_id is null then raise exception 'NO_FAMILY'; end if;

  delete from public.community_memberships
  where family_id = v_family_id;
end;
$$;

grant execute on function public.leave_community() to authenticated;

-- Set community admin (regional admin only).
create or replace function public.set_community_admin(
  p_membership_id uuid,
  p_is_admin boolean
)
returns public.community_memberships
language plpgsql security definer set search_path = '' as $$
declare
  v_role text;
  v_membership public.community_memberships%rowtype;
begin
  select role::text into v_role from public.profiles where id = (select auth.uid());
  if v_role not in ('regional_admin', 'app_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  update public.community_memberships
  set is_admin = p_is_admin
  where id = p_membership_id
  returning * into v_membership;

  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  return v_membership;
end;
$$;

grant execute on function public.set_community_admin(uuid, boolean) to authenticated;

-- ============================================================================
-- D. Community news/updates
-- ============================================================================
create table public.community_news (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  author_id    uuid not null references public.profiles(id),
  title        text not null check (trim(title) <> ''),
  body         text not null check (trim(body) <> ''),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_community_news_community
  on public.community_news(community_id, created_at desc);

alter table public.community_news enable row level security;

create trigger trg_community_news_touch before update on public.community_news
  for each row execute function private.touch_updated_at();

-- Readable by community members, regional admins, and app admins.
create policy community_news_select on public.community_news
  for select to authenticated
  using (
    (select private.is_community_member(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- Writable by community admins, regional admins, app admins.
create policy community_news_insert on public.community_news
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (
      (select private.is_community_admin(community_id))
      or (select private.current_app_role()) in ('regional_admin', 'app_admin')
    )
  );

create policy community_news_update on public.community_news
  for update to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    author_id = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy community_news_delete on public.community_news
  for delete to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- ============================================================================
-- E. Community discussions
-- ============================================================================
create table public.community_discussions (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  author_id    uuid not null references public.profiles(id),
  title        text not null check (trim(title) <> ''),
  body         text not null check (trim(body) <> ''),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_community_discussions_community
  on public.community_discussions(community_id, created_at desc);

alter table public.community_discussions enable row level security;

create trigger trg_community_discussions_touch before update on public.community_discussions
  for each row execute function private.touch_updated_at();

-- Readable by community members, regional admins, app admins.
create policy community_discussions_select on public.community_discussions
  for select to authenticated
  using (
    (select private.is_community_member(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- Any community member can start a discussion.
create policy community_discussions_insert on public.community_discussions
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (
      (select private.is_community_member(community_id))
      or (select private.current_app_role()) in ('regional_admin', 'app_admin')
    )
  );

create policy community_discussions_update on public.community_discussions
  for update to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy community_discussions_delete on public.community_discussions
  for delete to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- ============================================================================
-- F. Discussion replies
-- ============================================================================
create table public.community_discussion_replies (
  id            uuid primary key default gen_random_uuid(),
  discussion_id uuid not null references public.community_discussions(id) on delete cascade,
  author_id     uuid not null references public.profiles(id),
  body          text not null check (trim(body) <> ''),
  created_at    timestamptz not null default now()
);

create index idx_community_replies_discussion
  on public.community_discussion_replies(discussion_id, created_at);

alter table public.community_discussion_replies enable row level security;

-- Readable if parent discussion is readable (community members).
create policy community_replies_select on public.community_discussion_replies
  for select to authenticated
  using (
    exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          (select private.is_community_member(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

-- Community members can reply.
create policy community_replies_insert on public.community_discussion_replies
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          (select private.is_community_member(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

-- Author can delete own reply, community admin and regional admin can delete any.
create policy community_replies_delete on public.community_discussion_replies
  for delete to authenticated
  using (
    author_id = (select auth.uid())
    or exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          (select private.is_community_admin(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

-- ============================================================================
-- G. Community events (separate from church events)
-- ============================================================================
create table public.community_events (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  created_by   uuid references public.profiles(id),
  title        text not null check (trim(title) <> ''),
  description  text,
  location     text,
  starts_at    timestamptz not null,
  ends_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_community_events_community
  on public.community_events(community_id, starts_at);

alter table public.community_events enable row level security;

create trigger trg_community_events_touch before update on public.community_events
  for each row execute function private.touch_updated_at();

-- Stamp created_by on insert.
create or replace function private.stamp_community_event_creator()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.created_by := (select auth.uid());
  return new;
end;
$$;

create trigger trg_stamp_community_event_creator
  before insert on public.community_events
  for each row execute function private.stamp_community_event_creator();

-- Readable by community members, regional admins, app admins.
create policy community_events_select on public.community_events
  for select to authenticated
  using (
    (select private.is_community_member(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- Community admins and regional admins can create events.
create policy community_events_insert on public.community_events
  for insert to authenticated
  with check (
    (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy community_events_update on public.community_events
  for update to authenticated
  using (
    created_by = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    created_by = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy community_events_delete on public.community_events
  for delete to authenticated
  using (
    created_by = (select auth.uid())
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

-- ============================================================================
-- H. Profile policy: expose names of community co-members
-- ============================================================================
create policy profiles_select_community_member on public.profiles
  for select to authenticated
  using (
    family_id is not null
    and family_id in (
      select cm.family_id from public.community_memberships cm
      where cm.community_id = (select private.community_id_for_user())
    )
  );
