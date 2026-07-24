-- ============================================================================
-- TrueAnchor — Google (OAuth) onboarding
--
-- Depends on 0002_family_roles.sql (profiles.family_role, family_role enum).
--
-- Email/password signup carries the invite code in signUp(options.data), so
-- private.handle_new_user() can build the profile atomically. An OAuth user has
-- no such hook: the auth user is created by the provider redirect with no code.
--
-- So the trigger is relaxed to allow a code-less auth user to exist WITHOUT a
-- profile, and a new authenticated RPC (claim_invite) creates the profile once
-- the user supplies a church code on the /complete-signup screen. Until they
-- do, they have no profile and therefore — every church-scoped policy keys off
-- one — can read nothing.
-- ============================================================================

-- Relaxed from 0002: an empty invite code is the OAuth path. Return without
-- inserting a profile instead of aborting the whole signup. A non-empty but
-- invalid code still aborts, exactly as before, so the email/password flow is
-- unchanged.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_code   text;
  v_invite public.church_invites%rowtype;
begin
  v_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'invite_code', '')));

  -- OAuth signup: no code yet. The user claims one via public.claim_invite().
  if v_code = '' then
    return new;
  end if;

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

-- ------------------------------------------------- client-callable RPC ---

-- Called by an authenticated user who has no profile yet (the OAuth path), to
-- turn a church code into their profile row. Mirrors the trigger's logic:
-- validates the code, derives family_role from the invite role, reads the
-- email from auth.users, and increments the code's use count.
create or replace function public.claim_invite(
  p_first text,
  p_last  text,
  p_code  text
)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := (select auth.uid());
  v_invite  public.church_invites%rowtype;
  v_email   text;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Idempotent guard: never overwrite an existing profile, and never let a
  -- second claim re-run the invite's use counter.
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'ALREADY_ONBOARDED';
  end if;

  select * into v_invite
  from public.church_invites
  where code = upper(trim(p_code))
    and (expires_at is null or expires_at > now())
    and uses < max_uses;

  if not found then
    raise exception 'INVALID_INVITE_CODE';
  end if;

  select email into v_email from auth.users where id = v_uid;

  insert into public.profiles (
    id, church_id, role, family_role, first_name, last_name, email
  )
  values (
    v_uid,
    v_invite.church_id,
    v_invite.role,
    case v_invite.role
      when 'parent' then 'parent'::public.family_role
      when 'youth'  then 'youth'::public.family_role
    end,
    trim(coalesce(p_first, '')),
    trim(coalesce(p_last,  '')),
    coalesce(v_email, '')
  )
  returning * into v_profile;

  update public.church_invites set uses = uses + 1 where id = v_invite.id;
  return v_profile;
end;
$$;

grant execute on function public.claim_invite(text, text, text) to authenticated;
