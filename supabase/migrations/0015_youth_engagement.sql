-- ============================================================================
-- TrueAnchor — youth engagement overview for the youth pastor
--
-- CLAUDE.md asks for "Youth Pastor alerts for disengagement" — youth A has
-- missed three or more days of devotions. This file answers that question, and
-- it answers it by computing, not by storing.
--
-- There is deliberately no alerts table and no scheduled job. A stored alert is
-- wrong the moment the youth opens the app, and a pastor who learns the badge
-- lies stops looking at the badge. Every read here is fresh.
--
-- security definer, so the role test lives INSIDE the function. The definer
-- bypasses the daily_progress policies that would otherwise be the gate, which
-- is the point: progress_select_pastor already lets a pastor read their
-- church's rows one at a time, but aggregating across the church through RLS
-- would mean a scan per youth from the client.
--
-- church_admin is absent, for the same reason it lost journal reads in 0009:
-- administration is not pastoral care. app_admin is present because it is the
-- platform support role and is not scoped to a church of its own -- it sees
-- whatever church its profile row names.
--
-- What this function does NOT do is decide who is "at risk". It returns
-- numbers. The labelling lives in Dart (EngagementStatus), where it is a pure
-- function that can be unit tested and where changing the threshold does not
-- require a migration.
-- ============================================================================

create or replace function public.youth_engagement_overview(
  p_as_of date default current_date
)
returns table (
  profile_id     uuid,
  first_name     text,
  last_name      text,
  grade          int,
  last_active_on date,
  active_last_7  int,
  active_last_30 int,
  current_streak int,
  longest_streak int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role   public.user_role;
  v_church uuid;
begin
  select p.role, p.church_id into v_role, v_church
    from public.profiles p where p.id = (select auth.uid());

  if v_role is null or v_role not in ('youth_pastor', 'app_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  return query
  select p.id,
         p.first_name,
         p.last_name,
         p.grade,
         agg.last_active_on,
         coalesce(agg.active_last_7, 0),
         coalesce(agg.active_last_30, 0),
         s.current_streak,
         s.longest_streak
    from public.profiles p
    -- A left join, not an inner one: a youth with no daily_progress rows at all
    -- is the single most important row on this screen, and an inner join would
    -- drop exactly that person.
    left join lateral (
      select max(d.on_date) as last_active_on,
             count(*) filter (where d.on_date > p_as_of - 7 )::int as active_last_7,
             count(*) filter (where d.on_date > p_as_of - 30)::int as active_last_30
        from public.daily_progress d
       where d.profile_id = p.id
         and d.on_date <= p_as_of
         -- The same "engaged" rule 0011 uses: devotional OR Scripture.
         and (d.devotional_done or d.scripture_done)
    ) agg on true
    cross join lateral private.progress_streak(p.id, p_as_of) s
   where p.church_id = v_church
     and p.role = 'youth';
end;
$$;

revoke all on function public.youth_engagement_overview(date) from public, anon;
grant execute on function public.youth_engagement_overview(date) to authenticated;

comment on function public.youth_engagement_overview(date) is
  'Per-youth devotional engagement for the caller''s church. youth_pastor and '
  'app_admin only; raises NOT_AUTHORIZED otherwise. Computed on every read.';
