-- ============================================================================
-- TrueAnchor — one youth's last seven days, as counts
--
-- "Parents also need visibility to the youth's summary — did 4 devotions and 2
-- journals and 3 prayers this week." Youth pastors get the same figures for one
-- youth at a time, under the roster they already have.
--
-- This function returns COUNTS AND NOTHING ELSE. No titles, no bodies, no
-- names. That is the whole reason it exists: journal_entries reads are gated by
-- public.entry_visibility, so counting from the client would undercount a youth
-- who keeps entries private, and the number would visibly change every time
-- they adjusted a sharing setting — turning a sharing control into a disclosure
-- signal. The definer counts every row; the privacy boundary on entry *content*
-- is untouched, and a count is not content.
--
-- Same shape as youth_engagement_overview() in 0015, including the rule that
-- the authorization check lives INSIDE the function rather than leaning on the
-- policies the definer bypasses:
--
--   * the youth themself
--   * a parent in the same family        (mirrors progress_select_parents)
--   * a youth_pastor in the same church  (mirrors progress_select_pastor)
--   * app_admin, the unscoped support role
--
-- church_admin is absent for the reason 0009 and 0015 both give: administration
-- is not pastoral care.
--
-- The window is the seven days ending on p_as_of, matching the `> p_as_of - 7`
-- form already used by 0011 and 0015 so "this week" means the same thing on
-- every screen.
-- ============================================================================

create or replace function public.youth_weekly_summary(
  p_profile_id uuid,
  p_as_of      date default current_date
)
returns table (
  devotions      int,
  scripture      int,
  journals       int,
  prayers        int,
  interactions   int,
  current_streak int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller        uuid := (select auth.uid());
  v_caller_role   public.user_role;
  v_caller_family uuid;
  v_caller_church uuid;
  v_target_family uuid;
  v_target_church uuid;
begin
  select p.role, p.family_id, p.church_id
    into v_caller_role, v_caller_family, v_caller_church
    from public.profiles p where p.id = v_caller;

  select p.family_id, p.church_id
    into v_target_family, v_target_church
    from public.profiles p where p.id = p_profile_id;

  -- A null family or church on either side must never satisfy the test: two
  -- youth who have not joined a household would otherwise match each other.
  if not (
       v_caller = p_profile_id
    or v_caller_role = 'app_admin'
    or (v_caller_role = 'parent'
        and v_caller_family is not null
        and v_caller_family = v_target_family)
    or (v_caller_role = 'youth_pastor'
        and v_caller_church is not null
        and v_caller_church = v_target_church)
  ) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  return query
  select coalesce(prog.devotions, 0),
         coalesce(prog.scripture, 0),
         coalesce(entries.journals, 0),
         coalesce(entries.prayers, 0),
         coalesce(acts.interactions, 0),
         streak.current_streak
    from (
      select count(*) filter (where d.devotional_done)::int as devotions,
             count(*) filter (where d.scripture_done)::int  as scripture
        from public.daily_progress d
       where d.profile_id = p_profile_id
         and d.on_date <= p_as_of
         and d.on_date  > p_as_of - 7
    ) prog
    cross join (
      select count(*) filter (where j.entry_type = 'journal')::int as journals,
             count(*) filter (where j.entry_type = 'prayer')::int  as prayers
        from public.journal_entries j
       where j.author_id = p_profile_id
         and j.created_at::date <= p_as_of
         and j.created_at::date  > p_as_of - 7
    ) entries
    cross join (
      select count(*)::int as interactions
        from public.relationship_interactions i
       where i.owner_id = p_profile_id
         and i.occurred_on <= p_as_of
         and i.occurred_on  > p_as_of - 7
    ) acts
    -- The streak deliberately looks further back than seven days: it is the
    -- one figure here that is about momentum rather than about this week.
    cross join lateral private.progress_streak(p_profile_id, p_as_of) streak;
end;
$$;

revoke all on function public.youth_weekly_summary(uuid, date) from public, anon;
grant execute on function public.youth_weekly_summary(uuid, date) to authenticated;

comment on function public.youth_weekly_summary(uuid, date) is
  'Seven-day activity counts for one profile: devotions, Scripture, journals, '
  'prayers, Love in Action interactions, plus the current streak. Counts only '
  '— never entry content. Caller must be the profile itself, a parent in the '
  'same family, a youth_pastor in the same church, or app_admin; raises '
  'NOT_AUTHORIZED otherwise.';
