-- ============================================================================
-- TrueAnchor — Add regional_admin to user_role enum
--
-- ALTER TYPE ADD VALUE cannot be used in the same transaction that references
-- the new value. This migration must commit on its own before 0021 can run.
-- ============================================================================

alter type public.user_role add value 'regional_admin' before 'church_admin';
