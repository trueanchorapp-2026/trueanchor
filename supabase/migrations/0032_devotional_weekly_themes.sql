-- ============================================================================
-- TrueAnchor — weekly devotional themes, audiences, and structured sections
--
-- Devotionals are now authored a week at a time under a shared theme (e.g.
-- "Courage"), one devotional per day. Each day carries fixed sections:
--
--   Verse of the Day     scripture_reference / scripture_text  (existing)
--   Context              context
--   Go Deeper            deeper_reference / deeper_text / deeper_translation
--   Summary              summary
--   Upward               upward_body   + upward_questions
--   Inward               inward_body   + inward_questions  (journal prompts)
--   Outward              outward_body  + outward_questions
--   Prayer               prayer
--   Self-Application     self_application_questions
--   Love in Action       love_in_action + love_in_action_questions
--
-- Audience: content is written for youth or adults. The same date may carry
-- one devotional per audience, so publish_on is no longer unique on its own.
-- The client prefers the reader's audience and falls back to youth content
-- (see devotional_selection.dart), so adults read the youth week until adult
-- content exists.
--
-- Legacy columns (body, discussion_questions, activity, outward_prompt) are
-- kept so devotionals published before this migration still render. body
-- becomes nullable because structured rows have no single body.
--
-- Rows still key on id for journal_entries.devotional_id and
-- daily_progress.devotional_id, so nothing downstream changes.
-- ============================================================================

-- ----------------------------------------------------------------- enum ---

create type public.devotional_audience as enum ('youth', 'adult');

-- ------------------------------------------------------- devotional_themes ---

create table public.devotional_themes (
  id          uuid primary key default gen_random_uuid(),
  audience    public.devotional_audience not null,
  title       text not null,
  summary     text,
  starts_on   date not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (audience, starts_on)
);

create trigger trg_devotional_themes_touch before update on public.devotional_themes
  for each row execute function private.touch_updated_at();

alter table public.devotional_themes enable row level security;

-- Global content, same gates as public.devotionals (0010): every signed-in
-- user reads, only app_admin writes. Content normally arrives through the
-- generated seed script run in the SQL Editor.
create policy devotional_themes_select on public.devotional_themes
  for select to authenticated using (true);

create policy devotional_themes_insert on public.devotional_themes
  for insert to authenticated
  with check ((select private.current_app_role()) = 'app_admin');

create policy devotional_themes_update on public.devotional_themes
  for update to authenticated
  using ((select private.current_app_role()) = 'app_admin')
  with check ((select private.current_app_role()) = 'app_admin');

create policy devotional_themes_delete on public.devotional_themes
  for delete to authenticated
  using ((select private.current_app_role()) = 'app_admin');

-- ------------------------------------------------------------ devotionals ---

-- Existing rows were written for youth with parents reading along.
alter table public.devotionals
  add column audience public.devotional_audience not null default 'youth',
  add column theme_id uuid references public.devotional_themes(id) on delete set null,
  add column day_number smallint check (day_number between 1 and 7),
  add column context                    text,
  add column deeper_reference           text,
  add column deeper_text                text,
  add column deeper_translation         text,
  add column summary                    text,
  add column upward_body                text,
  add column upward_questions           text[] not null default '{}',
  add column inward_body                text,
  add column inward_questions           text[] not null default '{}',
  add column outward_body               text,
  add column outward_questions          text[] not null default '{}',
  add column prayer                     text,
  add column self_application_questions text[] not null default '{}',
  add column love_in_action             text,
  add column love_in_action_questions   text[] not null default '{}';

alter table public.devotionals alter column body drop not null;

-- One devotional per audience per date (was: per date).
alter table public.devotionals drop constraint devotionals_publish_on_key;
alter table public.devotionals
  add constraint devotionals_audience_publish_on_key unique (audience, publish_on);

-- One devotional per day of a theme.
alter table public.devotionals
  add constraint devotionals_theme_day_key unique (theme_id, day_number);

-- The read path filters on audience and scans publish_on descending.
drop index if exists public.devotionals_publish_on_idx;
create index devotionals_audience_publish_on_idx
  on public.devotionals (audience, publish_on desc);
