-- ============================================================================
-- TrueAnchor — Regional Admin tables, RLS, RPCs, seed data
--
-- Depends on 0020_regional_admin.sql (regional_admin enum value must be
-- committed before this migration runs).
--
-- Regional admins are standalone: no church membership, no family. They
-- create and manage regions and communities. Their profile has NULL
-- church_id, which naturally locks them out of all church-scoped RLS
-- policies (because `value = NULL` is always false in SQL).
-- ============================================================================

-- A. Make profiles.church_id nullable for regional admins.
alter table public.profiles alter column church_id drop not null;

-- B. Regions table.
create table public.regions (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.regions enable row level security;

create policy regions_select on public.regions
  for select to authenticated using (true);

create policy regions_insert on public.regions
  for insert to authenticated
  with check (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

create policy regions_update on public.regions
  for update to authenticated
  using (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  )
  with check (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

create policy regions_delete on public.regions
  for delete to authenticated
  using (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

-- C. Regional invites — separate from church_invites (no church_id).
create table public.regional_invites (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  role       public.user_role not null default 'regional_admin'
             check (role = 'regional_admin'),
  max_uses   int not null default 100,
  uses       int not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.regional_invites enable row level security;

create policy regional_invites_select on public.regional_invites
  for select to authenticated
  using (
    (select private.current_app_role())
    in ('regional_admin', 'app_admin')
  );

-- D. Redefine validate_invite_code to check both tables.
create or replace function public.validate_invite_code(p_code text)
returns table (church_id uuid, church_name text, role public.user_role)
language sql stable security definer set search_path = '' as $$
  -- Church invites (existing behaviour).
  select c.id, c.name, i.role
  from public.church_invites i
  join public.churches c on c.id = i.church_id
  where i.code = upper(trim(p_code))
    and (i.expires_at is null or i.expires_at > now())
    and i.uses < i.max_uses

  union all

  -- Regional invites (no church).
  select null::uuid, 'TrueAnchor (Regional)', r.role
  from public.regional_invites r
  where r.code = upper(trim(p_code))
    and (r.expires_at is null or r.expires_at > now())
    and r.uses < r.max_uses
$$;

-- E. Redefine handle_new_user to support regional invites.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_code            text;
  v_church_invite   public.church_invites%rowtype;
  v_regional_invite public.regional_invites%rowtype;
begin
  v_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'invite_code', '')));

  -- OAuth signup: no code yet. The user claims one later.
  if v_code = '' then
    return new;
  end if;

  -- Try church invites first.
  select * into v_church_invite
  from public.church_invites
  where code = v_code
    and (expires_at is null or expires_at > now())
    and uses < max_uses;

  if found then
    insert into public.profiles (
      id, church_id, role, family_role, first_name, last_name, email
    )
    values (
      new.id,
      v_church_invite.church_id,
      v_church_invite.role,
      case v_church_invite.role
        when 'parent' then 'parent'::public.family_role
        when 'youth'  then 'youth'::public.family_role
      end,
      coalesce(new.raw_user_meta_data ->> 'first_name', ''),
      coalesce(new.raw_user_meta_data ->> 'last_name',  ''),
      new.email
    );
    update public.church_invites set uses = uses + 1
    where id = v_church_invite.id;
    return new;
  end if;

  -- Fall back to regional invites.
  select * into v_regional_invite
  from public.regional_invites
  where code = v_code
    and (expires_at is null or expires_at > now())
    and uses < max_uses;

  if found then
    insert into public.profiles (
      id, church_id, role, first_name, last_name, email
    )
    values (
      new.id,
      null,
      v_regional_invite.role,
      coalesce(new.raw_user_meta_data ->> 'first_name', ''),
      coalesce(new.raw_user_meta_data ->> 'last_name',  ''),
      new.email
    );
    update public.regional_invites set uses = uses + 1
    where id = v_regional_invite.id;
    return new;
  end if;

  raise exception 'INVALID_INVITE_CODE';
end;
$$;

-- F. Claim regional invite RPC (Google OAuth path).
create or replace function public.claim_regional_invite(
  p_first text,
  p_last  text,
  p_code  text
)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := (select auth.uid());
  v_invite  public.regional_invites%rowtype;
  v_email   text;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'ALREADY_ONBOARDED';
  end if;

  select * into v_invite
  from public.regional_invites
  where code = upper(trim(p_code))
    and (expires_at is null or expires_at > now())
    and uses < max_uses;

  if not found then
    raise exception 'INVALID_INVITE_CODE';
  end if;

  select email into v_email from auth.users where id = v_uid;

  insert into public.profiles (
    id, church_id, role, first_name, last_name, email
  )
  values (
    v_uid,
    null,
    v_invite.role,
    trim(coalesce(p_first, '')),
    trim(coalesce(p_last,  '')),
    coalesce(v_email, '')
  )
  returning * into v_profile;

  update public.regional_invites set uses = uses + 1 where id = v_invite.id;
  return v_profile;
end;
$$;

grant execute on function public.claim_regional_invite(text, text, text) to authenticated;

-- G. Seed data.
insert into public.regions (name) values ('Texas'), ('Florida');
insert into public.regional_invites (code, role) values ('TAREGIONAL', 'regional_admin');
