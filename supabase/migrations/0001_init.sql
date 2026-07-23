-- ============================================================================
-- TrueAnchor V1 — initial schema
-- Applied to project vilevuoyzfkzcybgoixd on 2026-07-22.
--
-- Multi-tenancy: every church-owned record carries church_id.
-- Privacy: journal_entries.visibility is enforced by RLS, not by the UI.
-- ============================================================================

-- Private schema for RLS helpers. Deliberately NOT exposed via PostgREST:
-- anything in `public` is callable by any client holding the publishable key.
create schema if not exists private;

create type public.user_role        as enum ('app_admin','church_admin','youth_pastor','parent','youth');
create type public.entry_type       as enum ('journal','prayer');
create type public.entry_visibility as enum ('private','parents','parents_pastor');

-- ---------------------------------------------------------------- tables ---

create table public.churches (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  city       text,
  state      text,
  created_at timestamptz not null default now()
);

create table public.families (
  id                   uuid primary key default gen_random_uuid(),
  church_id            uuid not null references public.churches(id) on delete cascade,
  name                 text not null,
  head_of_household_id uuid,          -- FK added below; circular with profiles
  join_code            text not null unique,
  created_at           timestamptz not null default now()
);

create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  church_id   uuid not null references public.churches(id) on delete restrict,
  family_id   uuid references public.families(id) on delete set null,
  role        public.user_role not null,
  first_name  text not null,
  last_name   text not null,
  email       text not null,
  phone       text,
  avatar_url  text,
  birth_date  date,        -- age is derived client-side, never stored
  grade       int,
  gender      text,
  baptized    boolean not null default false,
  baptized_on date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.families
  add constraint families_head_fk
  foreign key (head_of_household_id) references public.profiles(id) on delete set null;

create table public.church_invites (
  id         uuid primary key default gen_random_uuid(),
  church_id  uuid not null references public.churches(id) on delete cascade,
  code       text not null unique,
  role       public.user_role not null,
  max_uses   int  not null default 100,
  uses       int  not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.journal_entries (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references public.profiles(id) on delete cascade,
  church_id  uuid not null references public.churches(id) on delete cascade,
  family_id  uuid references public.families(id) on delete set null,
  entry_type public.entry_type not null default 'journal',
  title      text,
  body       text not null,
  visibility public.entry_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index on public.profiles        (church_id);
create index on public.profiles        (family_id);
create index on public.families        (church_id);
create index on public.journal_entries (author_id, created_at desc);
create index on public.journal_entries (family_id) where visibility <> 'private';

-- ------------------------------------------------------- RLS helper fns ---
-- security definer => these read profiles bypassing RLS, which is what stops
-- a policy on profiles that needs "same church as me" from recursing forever.

create or replace function private.current_church_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select church_id from public.profiles where id = (select auth.uid())
$$;

-- NOT named current_role(): that is a reserved SQL keyword.
create or replace function private.current_app_role()
returns public.user_role language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = (select auth.uid())
$$;

create or replace function private.current_family_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select family_id from public.profiles where id = (select auth.uid())
$$;

revoke all on schema private from anon, authenticated;
grant usage on schema private to postgres;

-- ------------------------------------------------------------- triggers ---

create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end;
$$;

create trigger trg_profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger trg_journal_touch before update on public.journal_entries
  for each row execute function private.touch_updated_at();

-- Creates the profile row from signUp(options.data), resolving church + role
-- from the invite code atomically. Raising here aborts the signup, which is
-- intended: a user with no valid church must never exist.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_code   text;
  v_invite public.church_invites%rowtype;
begin
  v_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'invite_code', '')));

  select * into v_invite
  from public.church_invites
  where code = v_code
    and (expires_at is null or expires_at > now())
    and uses < max_uses;

  if not found then
    raise exception 'INVALID_INVITE_CODE';
  end if;

  insert into public.profiles (id, church_id, role, first_name, last_name, email)
  values (
    new.id,
    v_invite.church_id,
    v_invite.role,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name',  ''),
    new.email
  );

  update public.church_invites set uses = uses + 1 where id = v_invite.id;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- RLS controls which ROWS you may update, not which COLUMNS. Without this a
-- parent could PATCH their own row to role='app_admin'.
create or replace function private.guard_profile_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('app.bypass_profile_guard', true), '') = 'on' then
    return new;                       -- set by create_family()/join_family()
  end if;
  if private.current_app_role() in ('church_admin','app_admin') then
    return new;
  end if;
  new.role      := old.role;          -- silently revert privileged fields
  new.church_id := old.church_id;
  new.family_id := old.family_id;
  return new;
end;
$$;

create trigger trg_guard_profile before update on public.profiles
  for each row execute function private.guard_profile_columns();

-- Stops a client posting an entry tagged to another church/family.
create or replace function private.stamp_journal_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select church_id, family_id into new.church_id, new.family_id
  from public.profiles where id = new.author_id;
  return new;
end;
$$;

create trigger trg_stamp_journal before insert on public.journal_entries
  for each row execute function private.stamp_journal_context();

-- ------------------------------------------------- client-callable RPCs ---

-- Called from the SIGNED-OUT signup screen, so it must be granted to anon.
-- Returns church name + role for display; never exposes the invite row.
create or replace function public.validate_invite_code(p_code text)
returns table (church_id uuid, church_name text, role public.user_role)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, i.role
  from public.church_invites i
  join public.churches c on c.id = i.church_id
  where i.code = upper(trim(p_code))
    and (i.expires_at is null or i.expires_at > now())
    and i.uses < i.max_uses
$$;

create or replace function public.create_family(p_name text)
returns public.families language plpgsql security definer set search_path = '' as $$
declare v_fam public.families%rowtype; v_code text;
begin
  if private.current_app_role() not in ('parent','church_admin','app_admin') then
    raise exception 'ONLY_PARENTS_CAN_CREATE_FAMILIES';
  end if;
  if private.current_family_id() is not null then
    raise exception 'ALREADY_IN_A_FAMILY';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.families where join_code = v_code);
  end loop;

  insert into public.families (church_id, name, head_of_household_id, join_code)
  values (private.current_church_id(), p_name, (select auth.uid()), v_code)
  returning * into v_fam;

  perform set_config('app.bypass_profile_guard', 'on', true);
  update public.profiles set family_id = v_fam.id where id = (select auth.uid());

  return v_fam;
end;
$$;

create or replace function public.join_family(p_code text)
returns public.families language plpgsql security definer set search_path = '' as $$
declare v_fam public.families%rowtype;
begin
  select * into v_fam from public.families
  where join_code = upper(trim(p_code))
    and church_id = private.current_church_id();   -- cannot cross church boundary

  if not found then raise exception 'INVALID_FAMILY_CODE'; end if;

  perform set_config('app.bypass_profile_guard', 'on', true);
  update public.profiles set family_id = v_fam.id where id = (select auth.uid());
  return v_fam;
end;
$$;

grant execute on function public.validate_invite_code(text) to anon, authenticated;
grant execute on function public.create_family(text)        to authenticated;
grant execute on function public.join_family(text)          to authenticated;

-- ------------------------------------------------------------------ RLS ---

alter table public.churches        enable row level security;
alter table public.families        enable row level security;
alter table public.profiles        enable row level security;
alter table public.church_invites  enable row level security;
alter table public.journal_entries enable row level security;

create policy churches_select on public.churches for select to authenticated
  using (id = (select private.current_church_id()));

-- profiles: your church is a visible directory; writes are self-only
create policy profiles_select_own on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_select_church on public.profiles for select to authenticated
  using (church_id = (select private.current_church_id()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_update_admin on public.profiles for update to authenticated
  using (church_id = (select private.current_church_id())
         and (select private.current_app_role()) in ('church_admin','app_admin'))
  with check (church_id = (select private.current_church_id()));
-- no INSERT policy: profiles are created only by the signup trigger.

-- families: members + church staff only (join_code must not leak church-wide)
create policy families_select on public.families for select to authenticated
  using (church_id = (select private.current_church_id())
         and (id = (select private.current_family_id())
              or (select private.current_app_role())
                 in ('church_admin','app_admin','youth_pastor')));
create policy families_update on public.families for update to authenticated
  using (church_id = (select private.current_church_id())
         and (head_of_household_id = (select auth.uid())
              or (select private.current_app_role()) in ('church_admin','app_admin')))
  with check (church_id = (select private.current_church_id()));
-- no INSERT policy: families are created only via create_family().

create policy invites_select on public.church_invites for select to authenticated
  using (church_id = (select private.current_church_id())
         and (select private.current_app_role())
             in ('church_admin','app_admin','youth_pastor'));
create policy invites_insert on public.church_invites for insert to authenticated
  with check (church_id = (select private.current_church_id())
              and (select private.current_app_role()) in ('church_admin','app_admin'));

-- journal_entries: THE PRIVACY BOUNDARY.
-- There is deliberately NO policy granting read on visibility='private' to
-- anyone but the author -- not parents, not pastors, not admins.
create policy journal_select_own on public.journal_entries for select to authenticated
  using (author_id = (select auth.uid()));

create policy journal_select_parents on public.journal_entries for select to authenticated
  using (visibility in ('parents','parents_pastor')
         and (select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

create policy journal_select_pastor on public.journal_entries for select to authenticated
  using (visibility = 'parents_pastor'
         and (select private.current_app_role()) in ('youth_pastor','church_admin')
         and church_id = (select private.current_church_id()));

create policy journal_insert_own on public.journal_entries for insert to authenticated
  with check (author_id = (select auth.uid()));
create policy journal_update_own on public.journal_entries for update to authenticated
  using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy journal_delete_own on public.journal_entries for delete to authenticated
  using (author_id = (select auth.uid()));

-- ----------------------------------------------------------------- seed ---

insert into public.churches (id, name, city, state)
values ('00000000-0000-0000-0000-000000000001', 'CBCCS', 'Coral Springs', 'FL');

-- Codes are upper-cased on lookup. Rotate or delete these before any pilot.
insert into public.church_invites (church_id, code, role, max_uses) values
  ('00000000-0000-0000-0000-000000000001', 'TAADMIN',  'church_admin',   5),
  ('00000000-0000-0000-0000-000000000001', 'TAPASTOR', 'youth_pastor',  10),
  ('00000000-0000-0000-0000-000000000001', 'TAPARENT', 'parent',       200),
  ('00000000-0000-0000-0000-000000000001', 'TAYOUTH',  'youth',        500);
