-- ============================================================================
-- TrueAnchor — church events (view-only for members)
--
-- Church-scoped like everything else: every row carries church_id, stamped
-- from the author's profile by a trigger so a client cannot post into another
-- church. Youth pastors and church admins create; everyone in the church reads.
-- ============================================================================

create table public.events (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches(id) on delete cascade,
  created_by  uuid references public.profiles(id) on delete set null,
  title       text not null,
  description text,
  location    text,
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index on public.events (church_id, starts_at);

-- ------------------------------------------------------------- triggers ---

create trigger trg_events_touch before update on public.events
  for each row execute function private.touch_updated_at();

-- Same defence as stamp_journal_context: church_id and created_by come from
-- the signed-in author's profile, never from client input, so an event can
-- only ever land in the author's own church.
create or replace function private.stamp_event_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.created_by := (select auth.uid());
  select church_id into new.church_id
  from public.profiles where id = (select auth.uid());
  return new;
end;
$$;

create trigger trg_stamp_event before insert on public.events
  for each row execute function private.stamp_event_context();

-- ------------------------------------------------------------------ RLS ---

alter table public.events enable row level security;

-- Everyone in the church can read the church calendar.
create policy events_select on public.events for select to authenticated
  using (church_id = (select private.current_church_id()));

-- Only staff create/edit/delete, and only within their own church.
create policy events_insert on public.events for insert to authenticated
  with check ((select private.current_app_role())
                in ('youth_pastor','church_admin','app_admin'));

create policy events_update on public.events for update to authenticated
  using (church_id = (select private.current_church_id())
         and (select private.current_app_role())
             in ('youth_pastor','church_admin','app_admin'))
  with check (church_id = (select private.current_church_id()));

create policy events_delete on public.events for delete to authenticated
  using (church_id = (select private.current_church_id())
         and (select private.current_app_role())
             in ('youth_pastor','church_admin','app_admin'));
