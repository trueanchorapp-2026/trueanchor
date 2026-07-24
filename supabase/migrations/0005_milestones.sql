-- ============================================================================
-- TrueAnchor — spiritual milestones
--
-- A milestone belongs to a SUBJECT (profile_id, normally a youth). It is
-- recorded by a parent in the subject's family or by church staff — never by
-- the youth themselves, which is enforced here in RLS, not the UI.
--
-- Visibility mirrors the household boundary: the subject, the parents in their
-- family, and church staff can read; nobody else.
-- ============================================================================

create type public.milestone_type as enum
  ('accepted_christ','baptized','scripture_memory','devotion_streak','service','other');

create table public.milestones (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null references public.profiles(id) on delete cascade,
  church_id      uuid not null references public.churches(id) on delete cascade,
  family_id      uuid references public.families(id) on delete set null,
  recorded_by    uuid references public.profiles(id) on delete set null,
  milestone_type public.milestone_type not null,
  title          text,
  note           text,
  achieved_on    date not null default current_date,
  created_at     timestamptz not null default now()
);

create index on public.milestones (profile_id, achieved_on desc);

-- ------------------------------------------------------------- triggers ---

-- church_id and family_id are stamped from the SUBJECT's profile, and
-- recorded_by from the caller, so neither tenancy nor authorship can be forged
-- by client input.
create or replace function private.stamp_milestone_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.recorded_by := (select auth.uid());
  select church_id, family_id into new.church_id, new.family_id
  from public.profiles where id = new.profile_id;
  return new;
end;
$$;

create trigger trg_stamp_milestone before insert on public.milestones
  for each row execute function private.stamp_milestone_context();

-- ------------------------------------------------------------------ RLS ---

alter table public.milestones enable row level security;

-- Subject reads their own; parents read their family's; staff read the church.
create policy milestones_select_own on public.milestones for select to authenticated
  using (profile_id = (select auth.uid()));

create policy milestones_select_parents on public.milestones for select to authenticated
  using ((select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

create policy milestones_select_staff on public.milestones for select to authenticated
  using ((select private.current_app_role())
             in ('youth_pastor','church_admin','app_admin')
         and church_id = (select private.current_church_id()));

-- Insert is checked against the client-supplied profile_id (so it is
-- independent of the stamping trigger's ordering): a parent may record for a
-- member of their own family; staff for anyone in their church. A youth's role
-- matches neither branch, so a youth cannot record — for themselves or anyone.
create policy milestones_insert on public.milestones for insert to authenticated
  with check (
    ((select private.current_app_role()) = 'parent'
     and exists (
       select 1 from public.profiles p
       where p.id = profile_id
         and p.family_id is not null
         and p.family_id = (select private.current_family_id())))
    or
    ((select private.current_app_role())
        in ('youth_pastor','church_admin','app_admin')
     and exists (
       select 1 from public.profiles p
       where p.id = profile_id
         and p.church_id = (select private.current_church_id())))
  );

-- The recorder can correct or remove what they logged; staff can clean up
-- anything in their church.
create policy milestones_update on public.milestones for update to authenticated
  using (recorded_by = (select auth.uid())
         or ((select private.current_app_role())
                in ('youth_pastor','church_admin','app_admin')
             and church_id = (select private.current_church_id())))
  with check (church_id = (select private.current_church_id()));

create policy milestones_delete on public.milestones for delete to authenticated
  using (recorded_by = (select auth.uid())
         or ((select private.current_app_role())
                in ('youth_pastor','church_admin','app_admin')
             and church_id = (select private.current_church_id())));
