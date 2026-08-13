-- ============================================================================
-- TrueAnchor — devotional restructure for Upward / Inward / Outward sections
--
-- Each devotional now has four conceptual sections:
--   1. Verse of the Day       (existing scripture_reference / scripture_text)
--   2. Upward Reflection      (existing body)
--   3. Inward Reflection      (existing discussion_questions become prompts;
--                               the user's response is a journal_entry linked
--                               by the new devotional_id FK)
--   4. Outward                (new outward_prompt column)
--
-- The existing `activity` column is superseded by `outward_prompt` but is not
-- dropped — older seed rows still carry it and the client can fall back to it.
-- ============================================================================

-- -------------------------------------------------------- devotionals ---

alter table public.devotionals add column outward_prompt text;

-- -------------------------------------------------------- journal_entries ---

-- Links a journal entry to the devotional it was written from (the Inward
-- Reflection). Nullable: standalone entries (written outside a devotional) and
-- all entries created before this migration have no devotional link.
alter table public.journal_entries
  add column devotional_id uuid references public.devotionals(id);

-- Fast lookup when the client asks "did the user already reflect on this
-- devotional?"
create index on public.journal_entries (devotional_id)
  where devotional_id is not null;

-- One reflection per person per devotional. The partial index lets standalone
-- entries (devotional_id is null) coexist freely.
create unique index journal_entries_author_devotional_key
  on public.journal_entries (author_id, devotional_id)
  where devotional_id is not null;
