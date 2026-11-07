-- ============================================================================
-- TrueAnchor 0030 — topic tags, discussion search & sorting
--
-- 1. topic_tags: a curated, global set of topics (managed by regional/app
--    admins, seeded here).
-- 2. community_discussion_tags: up to 3 tags per discussion.
-- 3. parent_resource_tags: tags on Parent Hub resources (manual SQL, like
--    the resources themselves).
-- 4. reply_count / last_activity_at on discussions, kept current by a
--    trigger on replies, for the "Most replies" and "Recent activity" sorts.
-- 5. A full-text search column over title + body.
-- 6. search_community_discussions RPC: filter by tags/text, four sorts.
-- 7. set_discussion_tags RPC: replace a discussion's tags atomically.
-- ============================================================================


-- ─── 1. Topic tags ─────────────────────────────────────────────────────────

create table public.topic_tags (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label      text not null check (length(btrim(label)) > 0),
  sort_order int  not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.topic_tags enable row level security;

create policy topic_tags_select on public.topic_tags
  for select to authenticated using (true);

create policy topic_tags_write on public.topic_tags
  for all to authenticated
  using ((select private.current_app_role()) in ('regional_admin', 'app_admin'))
  with check ((select private.current_app_role()) in ('regional_admin', 'app_admin'));

insert into public.topic_tags (slug, label, sort_order) values
  ('school-board',       'School Board',       10),
  ('curriculum',         'Curriculum',         20),
  ('biblical-worldview', 'Biblical Worldview', 30),
  ('identity',           'Identity',           40),
  ('media-technology',   'Media & Technology', 50),
  ('parenting',          'Parenting',          60),
  ('prayer',             'Prayer',             70),
  ('service-outreach',   'Service & Outreach', 80),
  ('local-issues',       'Local Issues',       90);


-- ─── 2. Discussion tags ────────────────────────────────────────────────────

create table public.community_discussion_tags (
  discussion_id uuid not null references public.community_discussions(id) on delete cascade,
  tag_id        uuid not null references public.topic_tags(id) on delete cascade,
  primary key (discussion_id, tag_id)
);

create index idx_community_discussion_tags_tag
  on public.community_discussion_tags(tag_id);

alter table public.community_discussion_tags enable row level security;

-- Readable wherever the discussion is readable (adults-only via membership).
create policy community_discussion_tags_select on public.community_discussion_tags
  for select to authenticated
  using (
    exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          (select private.is_community_member(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

-- Whoever may edit the discussion may tag it.
create policy community_discussion_tags_insert on public.community_discussion_tags
  for insert to authenticated
  with check (
    exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          d.author_id = (select auth.uid())
          or (select private.is_community_admin(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

create policy community_discussion_tags_delete on public.community_discussion_tags
  for delete to authenticated
  using (
    exists (
      select 1 from public.community_discussions d
      where d.id = discussion_id
        and (
          d.author_id = (select auth.uid())
          or (select private.is_community_admin(d.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

-- At most 3 tags per discussion (matches DiscussionQuery.maxTagsPerPost).
create or replace function private.enforce_discussion_tag_limit()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.community_discussion_tags
      where discussion_id = new.discussion_id) >= 3 then
    raise exception 'A discussion can have at most 3 tags.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger trg_community_discussion_tags_limit
  before insert on public.community_discussion_tags
  for each row execute function private.enforce_discussion_tag_limit();


-- ─── 3. Parent resource tags ───────────────────────────────────────────────

create table public.parent_resource_tags (
  resource_id uuid not null references public.parent_resources(id) on delete cascade,
  tag_id      uuid not null references public.topic_tags(id) on delete cascade,
  primary key (resource_id, tag_id)
);

create index idx_parent_resource_tags_tag
  on public.parent_resource_tags(tag_id);

alter table public.parent_resource_tags enable row level security;

create policy parent_resource_tags_select on public.parent_resource_tags
  for select to authenticated using (true);


-- ─── 4. Reply count & last activity ────────────────────────────────────────

alter table public.community_discussions
  add column reply_count      int not null default 0,
  add column last_activity_at timestamptz not null default now();

update public.community_discussions d
  set reply_count = r.n,
      last_activity_at = greatest(d.created_at, r.latest)
  from (
    select discussion_id, count(*)::int as n, max(created_at) as latest
    from public.community_discussion_replies
    group by discussion_id
  ) r
  where r.discussion_id = d.id;

update public.community_discussions
  set last_activity_at = created_at
  where reply_count = 0;

create index idx_community_discussions_activity
  on public.community_discussions(community_id, last_activity_at desc);

create index idx_community_discussions_replies
  on public.community_discussions(community_id, reply_count desc);

-- Repliers can't UPDATE someone else's discussion under RLS, so this runs
-- as definer. It only touches the counter columns.
create or replace function private.bump_discussion_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.community_discussions
      set reply_count = reply_count + 1,
          last_activity_at = greatest(last_activity_at, new.created_at)
      where id = new.discussion_id;
  else
    update public.community_discussions
      set reply_count = greatest(reply_count - 1, 0)
      where id = old.discussion_id;
  end if;
  return null;
end;
$$;

create trigger trg_community_replies_activity
  after insert or delete on public.community_discussion_replies
  for each row execute function private.bump_discussion_activity();

-- Counter bumps aren't edits: keep updated_at for real title/body changes.
create or replace function private.touch_discussion_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.image_urls is distinct from old.image_urls then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_community_discussions_touch on public.community_discussions;

create trigger trg_community_discussions_touch before update on public.community_discussions
  for each row execute function private.touch_discussion_updated_at();


-- ─── 5. Full-text search ───────────────────────────────────────────────────

alter table public.community_discussions
  add column search_tsv tsvector
    generated always as (to_tsvector('english', title || ' ' || body)) stored;

create index idx_community_discussions_search
  on public.community_discussions using gin (search_tsv);


-- ─── 6. Search RPC ─────────────────────────────────────────────────────────

-- security invoker: RLS on discussions/tags still decides what is visible.
create or replace function public.search_community_discussions(
  p_community_id uuid,
  p_tag_ids      uuid[] default null,
  p_query        text   default null,
  p_sort         text   default 'newest'
)
returns table (
  id                uuid,
  community_id      uuid,
  author_id         uuid,
  title             text,
  body              text,
  image_urls        text[],
  reply_count       int,
  last_activity_at  timestamptz,
  created_at        timestamptz,
  updated_at        timestamptz,
  author_first_name text,
  author_last_name  text,
  tag_ids           uuid[]
)
language sql stable security invoker set search_path = '' as $$
  select
    d.id, d.community_id, d.author_id, d.title, d.body, d.image_urls,
    d.reply_count, d.last_activity_at, d.created_at, d.updated_at,
    p.first_name, p.last_name,
    coalesce(
      (select array_agg(t.tag_id) from public.community_discussion_tags t
       where t.discussion_id = d.id),
      '{}'::uuid[]
    )
  from public.community_discussions d
  left join public.profiles p on p.id = d.author_id
  where d.community_id = p_community_id
    and (
      p_tag_ids is null or cardinality(p_tag_ids) = 0
      or exists (
        select 1 from public.community_discussion_tags t
        where t.discussion_id = d.id and t.tag_id = any(p_tag_ids)
      )
    )
    and (
      p_query is null or btrim(p_query) = ''
      or d.search_tsv @@ websearch_to_tsquery('english', p_query)
      or d.title ilike '%' || btrim(p_query) || '%'
      or d.body  ilike '%' || btrim(p_query) || '%'
    )
  order by
    case when p_sort = 'activity' then d.last_activity_at end desc nulls last,
    case when p_sort = 'replies'  then d.reply_count      end desc nulls last,
    case when p_sort = 'oldest'   then d.created_at       end asc  nulls last,
    d.created_at desc
$$;

grant execute on function public.search_community_discussions(uuid, uuid[], text, text)
  to authenticated;


-- ─── 7. Set tags RPC ───────────────────────────────────────────────────────

-- security invoker: the tag table's RLS decides who may (re)tag.
create or replace function public.set_discussion_tags(
  p_discussion_id uuid,
  p_tag_ids       uuid[]
)
returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if cardinality(coalesce(p_tag_ids, '{}')) > 3 then
    raise exception 'A discussion can have at most 3 tags.'
      using errcode = 'check_violation';
  end if;

  delete from public.community_discussion_tags
    where discussion_id = p_discussion_id;

  insert into public.community_discussion_tags (discussion_id, tag_id)
    select p_discussion_id, t
    from (select distinct unnest(coalesce(p_tag_ids, '{}'))) as u(t);
end;
$$;

grant execute on function public.set_discussion_tags(uuid, uuid[])
  to authenticated;
