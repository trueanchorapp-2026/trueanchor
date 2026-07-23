-- ============================================================================
-- TrueAnchor — joining an existing household, and household roles
--
-- Adds `profiles.family_role`: the label a household uses for a member
-- (Parent, Guardian, Grandparent, Youth). It is NOT a permission level.
-- `profiles.role` stays the only thing RLS reads; it is DERIVED from
-- family_role so the two can never disagree.
-- ============================================================================

create type public.family_role as enum
  ('parent','guardian','grandparent','youth');

alter table public.profiles
  add column family_role public.family_role;

-- Adults keep adult permissions whatever they are called at home; youth are
-- the only family role that narrows what RLS will show.
create or replace function private.user_role_for_family_role(
  p_family_role public.family_role
)
returns public.user_role language sql immutable set search_path = '' as $$
  select case p_family_role
    when 'youth' then 'youth'::public.user_role
    else 'parent'::public.user_role
  end
$$;

-- Backfill: existing members are labelled by whatever their church code gave
-- them. Church staff stay null — they have no household.
update public.profiles
   set family_role = case role
     when 'parent' then 'parent'::public.family_role
     when 'youth'  then 'youth'::public.family_role
   end
 where role in ('parent','youth');

-- ---------------------------------------------------------------- triggers ---

-- Redefined from 0001 only to stamp family_role alongside role, so every
-- household member has a label from the moment they sign up.
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

  insert into public.profiles (
    id, church_id, role, family_role, first_name, last_name, email
  )
  values (
    new.id,
    v_invite.church_id,
    v_invite.role,
    case v_invite.role
      when 'parent' then 'parent'::public.family_role
      when 'youth'  then 'youth'::public.family_role
    end,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name',  ''),
    new.email
  );

  update public.church_invites set uses = uses + 1 where id = v_invite.id;
  return new;
end;
$$;

-- family_role decides `role`, so it has to be as privileged as `role` is.
-- Without this a youth could PATCH themselves to 'parent' and, on the next
-- assignment, be handed parent permissions.
create or replace function private.guard_profile_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('app.bypass_profile_guard', true), '') = 'on' then
    return new;              -- set by create_family()/join_family()/role RPC
  end if;
  if private.current_app_role() in ('church_admin','app_admin') then
    return new;
  end if;
  new.role        := old.role;        -- silently revert privileged fields
  new.family_role := old.family_role;
  new.church_id   := old.church_id;
  new.family_id   := old.family_id;
  return new;
end;
$$;

-- ------------------------------------------------- client-callable RPCs ---

-- Redefined from 0001 to refuse a caller who is already in a household.
--
-- families_select shows join_code to every member, so without this any member
-- holding another household's code could move themselves into it and read its
-- 'parents'-visibility journal entries. Moving between households is a church
-- admin action, not a self-service one.
create or replace function public.join_family(p_code text)
returns public.families language plpgsql security definer set search_path = '' as $$
declare v_fam public.families%rowtype;
begin
  if private.current_family_id() is not null then
    raise exception 'ALREADY_IN_A_FAMILY';
  end if;

  select * into v_fam from public.families
  where join_code = upper(trim(p_code))
    and church_id = private.current_church_id();   -- cannot cross church boundary

  if not found then raise exception 'INVALID_FAMILY_CODE'; end if;

  perform set_config('app.bypass_profile_guard', 'on', true);
  update public.profiles set family_id = v_fam.id where id = (select auth.uid());
  return v_fam;
end;
$$;

-- Lets the head of household label the people who joined with their code, and
-- in doing so set whether the app treats them as an adult or as youth.
--
-- Deliberately cannot reach church roles in either direction: a household must
-- never be able to mint a youth_pastor, nor demote one who shares their home.
create or replace function public.set_family_member_role(
  p_member      uuid,
  p_family_role public.family_role
)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  v_member public.profiles%rowtype;
  v_fam    public.families%rowtype;
  v_result public.profiles%rowtype;
begin
  select * into v_member from public.profiles where id = p_member;
  if not found or v_member.family_id is null then
    raise exception 'NOT_A_FAMILY_MEMBER';
  end if;

  if v_member.role not in ('parent','youth') then
    raise exception 'CANNOT_CHANGE_STAFF_ROLE';
  end if;

  select * into v_fam from public.families where id = v_member.family_id;

  if v_fam.church_id <> private.current_church_id()
     or not (v_fam.head_of_household_id = (select auth.uid())
             or private.current_app_role() in ('church_admin','app_admin')) then
    raise exception 'ONLY_HEAD_CAN_ASSIGN_ROLES';
  end if;

  -- The head is the only account that can assign roles here. Letting them
  -- become youth would leave the household with nobody who can fix it.
  if p_member = v_fam.head_of_household_id and p_family_role = 'youth' then
    raise exception 'HEAD_MUST_BE_AN_ADULT';
  end if;

  perform set_config('app.bypass_profile_guard', 'on', true);
  update public.profiles
     set family_role = p_family_role,
         role        = private.user_role_for_family_role(p_family_role)
   where id = p_member
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.set_family_member_role(uuid, public.family_role)
  to authenticated;
