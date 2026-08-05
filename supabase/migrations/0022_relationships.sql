-- ============================================================================
-- TrueAnchor — relational capital tracker
--
-- Youth track ongoing relationships with non-app people (classmates,
-- neighbours, etc.) and log interactions over time. Each relationship can
-- carry a "next step" describing what the youth plans to do next.
--
-- Visibility mirrors the household boundary: the youth sees their own,
-- parents in the same family, and the youth pastor in the same church.
-- Only the owning youth can write.
-- ============================================================================

create type public.interaction_type as enum
  ('hangout','invited','prayer','encouragement','service','other');

-- A. Relationships — the tracked person (NOT an app user).

create table public.relationships (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  church_id   uuid not null references public.churches(id) on delete cascade,
  family_id   uuid references public.families(id) on delete set null,
  name        text not null check (length(btrim(name)) > 0),
  context     text,
  next_step   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index on public.relationships (owner_id, created_at desc);

-- B. Relationship interactions — logged events over time.

create table public.relationship_interactions (
  id                uuid primary key default gen_random_uuid(),
  relationship_id   uuid not null references public.relationships(id) on delete cascade,
  owner_id          uuid not null references public.profiles(id) on delete cascade,
  interaction_type  public.interaction_type not null,
  note              text,
  occurred_on       date not null default current_date,
  created_at        timestamptz not null default now()
);

create index on public.relationship_interactions (relationship_id, occurred_on desc);

-- ------------------------------------------------------------- triggers ---

create or replace function private.stamp_relationship_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.owner_id := (select auth.uid());
  select church_id, family_id into new.church_id, new.family_id
  from public.profiles where id = new.owner_id;
  return new;
end;
$$;

create trigger trg_stamp_relationship before insert on public.relationships
  for each row execute function private.stamp_relationship_context();

create trigger trg_relationship_touch before update on public.relationships
  for each row execute function private.touch_updated_at();

create or replace function private.stamp_interaction_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.owner_id := (select auth.uid());
  return new;
end;
$$;

create trigger trg_stamp_interaction before insert on public.relationship_interactions
  for each row execute function private.stamp_interaction_owner();

-- ------------------------------------------------------------------ RLS ---

alter table public.relationships enable row level security;

create policy relationships_select_own on public.relationships
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy relationships_select_parents on public.relationships
  for select to authenticated
  using ((select private.current_app_role()) = 'parent'
         and family_id is not null
         and family_id = (select private.current_family_id()));

create policy relationships_select_pastor on public.relationships
  for select to authenticated
  using ((select private.current_app_role()) = 'youth_pastor'
         and church_id = (select private.current_church_id()));

create policy relationships_insert_own on public.relationships
  for insert to authenticated
  with check ((select private.current_app_role()) = 'youth');

create policy relationships_update_own on public.relationships
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy relationships_delete_own on public.relationships
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Interactions inherit visibility from their parent relationship.

alter table public.relationship_interactions enable row level security;

create policy interactions_select on public.relationship_interactions
  for select to authenticated
  using (exists (
    select 1 from public.relationships r
    where r.id = relationship_id
      and (r.owner_id = (select auth.uid())
           or ((select private.current_app_role()) = 'parent'
               and r.family_id is not null
               and r.family_id = (select private.current_family_id()))
           or ((select private.current_app_role()) = 'youth_pastor'
               and r.church_id = (select private.current_church_id())))
  ));

create policy interactions_insert_own on public.relationship_interactions
  for insert to authenticated
  with check (exists (
    select 1 from public.relationships r
    where r.id = relationship_id
      and r.owner_id = (select auth.uid())));

create policy interactions_update_own on public.relationship_interactions
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy interactions_delete_own on public.relationship_interactions
  for delete to authenticated
  using (owner_id = (select auth.uid()));
