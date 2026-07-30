-- ============================================================================
-- TrueAnchor — daily devotionals (the first global table)
--
-- Every table so far carries church_id, and every select policy filters on
-- private.current_church_id(). Devotionals deliberately do not. The daily
-- devotional is native platform content: every church reads the same one on
-- the same date, so tenancy is not the read gate here — authorship is the
-- write gate.
--
-- Date-keyed: publish_on is unique, and the app asks for "the devotional for
-- today". If a date has no row the client falls back to the most recent one
-- published on or before today, so a gap in the content calendar degrades to
-- yesterday's reading rather than an empty screen. That fallback is a plain
-- indexed query, not an RPC — see supabase_devotional_repository.dart.
--
-- The translation/copyright_notice pair exists for attribution. Public domain
-- texts (WEB, KJV, ASV) need no notice; a licensed translation (NIV, ESV, NLT)
-- requires a specific one on every screen showing verse text, and the app
-- renders copyright_notice in the devotional footer whenever it is present.
-- ============================================================================

-- --------------------------------------------------------------- tables ---

create table public.devotionals (
  id                   uuid primary key default gen_random_uuid(),
  publish_on           date not null unique,
  title                text not null,
  scripture_reference  text not null,
  scripture_text       text not null,
  translation          text not null,
  copyright_notice     text,
  body                 text not null,
  discussion_questions text[] not null default '{}',
  activity             text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- discussion_questions is an array rather than a child table on purpose: it is
-- always read as part of the whole record, never queried or joined on its own,
-- and array order is display order. A child table would buy a join and a second
-- RLS policy for nothing.

-- Serves both reads: the exact-date lookup (via the unique index on publish_on)
-- and the "most recent on or before today" fallback scan.
create index on public.devotionals (publish_on desc);

-- ------------------------------------------------------------- triggers ---

create trigger trg_devotionals_touch before update on public.devotionals
  for each row execute function private.touch_updated_at();

-- ------------------------------------------------------------------ RLS ---

alter table public.devotionals enable row level security;

-- The whole point of a global table: no church test, no role test, no family
-- test. `using (true)` is scoped by the `to authenticated` clause alone — a
-- signed-out visitor still gets nothing, and a signed-in user with no profile
-- row (the mid-onboarding OAuth case) can read devotionals but nothing else.
create policy devotionals_select on public.devotionals
  for select to authenticated using (true);

-- Writes are platform-level. app_admin is the only role in user_role that is
-- not scoped to a single church, which is exactly why it is the only role that
-- may author content every church will read. In this phase content actually
-- arrives through the generated seed script run in the SQL Editor; these
-- policies exist so the direct PostgREST path is closed too.
create policy devotionals_insert on public.devotionals
  for insert to authenticated
  with check ((select private.current_app_role()) = 'app_admin');

create policy devotionals_update on public.devotionals
  for update to authenticated
  using ((select private.current_app_role()) = 'app_admin')
  with check ((select private.current_app_role()) = 'app_admin');

create policy devotionals_delete on public.devotionals
  for delete to authenticated
  using ((select private.current_app_role()) = 'app_admin');
