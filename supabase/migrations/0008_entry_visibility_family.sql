-- ============================================================================
-- TrueAnchor — new entry_visibility levels
--
-- This migration adds enum values ONLY. Postgres will not let a new enum
-- value be referenced in the same transaction that created it, and Supabase
-- runs each migration file in a transaction — so the policies that use these
-- values live in 0009. Do not merge the two files.
--
-- The sharing model these support (see 0009 for the enforcement):
--
--   Youth   private        -> self only
--           parents        -> every adult in the household
--           parents_pastor -> ^ + the church's youth pastor
--
--   Parent  parents        -> every adult in the household  (their baseline)
--           family         -> ^ + the youth in the household
--           family_pastor  -> ^ + the church's youth pastor
--
-- Parents are not offered `private`: adults in one household disciple
-- together, so their floor is each other rather than themselves. The value
-- stays in the enum because entries parents wrote before this change were
-- promised "only you can see this", and that promise is kept by leaving those
-- rows exactly as they are.
-- ============================================================================

alter type public.entry_visibility add value if not exists 'family';
alter type public.entry_visibility add value if not exists 'family_pastor';
