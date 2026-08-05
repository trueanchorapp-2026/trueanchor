-- ============================================================================
-- TrueAnchor — Profile city/state of residence
--
-- Used for community matching: families join communities based on location.
-- ============================================================================

alter table public.profiles add column city text;
alter table public.profiles add column state text;
