-- ============================================================================
-- TrueAnchor 0031 — per-person Community Admin, publishing (News + Parent
--                    Hub), voting, related discussions
--
-- 0. Community membership checks become adults-only (youth in a member
--    family no longer pass is_community_member).
-- 1. Community Admin moves from the family (is_admin) to one adult
--    (admin_user_id). New RPCs to pick that adult and to read "my" family's
--    membership (so every adult in the family, not just the head, sees it).
-- 2. News: optional link, tags, full-text search, search RPC, edit/delete
--    for community admins.
-- 3. Parent Hub resources become community-scoped and admin-authored:
--    body + optional link, tags, search RPC. Existing global resources are
--    copied into every community (with their tags).
-- 4. Voting: up/down on discussions, news and resources; "helpful" on
--    replies. Counts are denormalized by triggers. cast_vote /
--    toggle_reply_helpful RPCs. Discussion search gains votes + "top".
-- 5. related_discussions RPC: top discussions for a news post.
--
-- Note: security invoker functions below never call private.* directly
-- (authenticated has no usage on that schema); RLS policies do.
-- ============================================================================


-- ─── 0. Adults-only membership ─────────────────────────────────────────────

create or replace function private.is_community_member(p_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select private.current_app_role())::text, 'youth') <> 'youth'
     and exists (
       select 1 from public.community_memberships
       where community_id = p_community_id
         and family_id = (select private.current_family_id())
     )
$$;


-- ─── 1. Per-person Community Admin ─────────────────────────────────────────

alter table public.community_memberships
  add column admin_user_id uuid references public.profiles(id) on delete set null;

-- The head of household was the person elevated in practice.
update public.community_memberships
  set admin_user_id = joined_by
  where is_admin;

-- Only the chosen adult, and only while still in that family.
create or replace function private.is_community_admin(p_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.community_memberships
    where community_id = p_community_id
      and admin_user_id = (select auth.uid())
      and family_id = (select private.current_family_id())
  )
  and coalesce((select private.current_app_role())::text, 'youth') <> 'youth'
$$;

drop function if exists public.set_community_admin(uuid, boolean);

alter table public.community_memberships drop column is_admin;

-- Regional/app admin picks one adult of the member family (null revokes).
create or replace function public.set_community_admin(
  p_membership_id uuid,
  p_user_id       uuid
)
returns public.community_memberships
language plpgsql security definer set search_path = '' as $$
declare
  v_membership public.community_memberships%rowtype;
begin
  if coalesce((select private.current_app_role())::text, '')
       not in ('regional_admin', 'app_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select * into v_membership
  from public.community_memberships where id = p_membership_id;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;

  if p_user_id is not null and not exists (
    select 1 from public.profiles
    where id = p_user_id
      and family_id = v_membership.family_id
      and role <> 'youth'
  ) then
    raise exception 'NOT_AN_ADULT_IN_FAMILY';
  end if;

  update public.community_memberships
    set admin_user_id = p_user_id
    where id = p_membership_id
    returning * into v_membership;

  return v_membership;
end;
$$;

grant execute on function public.set_community_admin(uuid, uuid) to authenticated;

-- Every adult in every member family, for the regional admin's picker.
create or replace function public.list_community_admin_candidates(
  p_community_id uuid
)
returns table (
  membership_id uuid,
  family_id     uuid,
  family_name   text,
  user_id       uuid,
  first_name    text,
  last_name     text,
  is_admin      boolean
)
language sql stable security definer set search_path = '' as $$
  select m.id, m.family_id, f.name, p.id, p.first_name, p.last_name,
         m.admin_user_id is not distinct from p.id
  from public.community_memberships m
  join public.families f on f.id = m.family_id
  join public.profiles p on p.family_id = m.family_id and p.role <> 'youth'
  where m.community_id = p_community_id
    and (select private.current_app_role())::text in ('regional_admin', 'app_admin')
  order by f.name, p.first_name, p.last_name
$$;

grant execute on function public.list_community_admin_candidates(uuid)
  to authenticated;

-- The caller's family membership (any adult in the family, not just the
-- adult who joined). Returns no row for youth.
create or replace function public.my_community_membership()
returns setof public.community_memberships
language sql stable security definer set search_path = '' as $$
  select m.* from public.community_memberships m
  where m.family_id = (select private.current_family_id())
    and coalesce((select private.current_app_role())::text, 'youth') <> 'youth'
$$;

grant execute on function public.my_community_membership() to authenticated;


-- ─── Shared helpers ────────────────────────────────────────────────────────

-- updated_at only for real edits, not vote/counter bumps.
create or replace function private.touch_post_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.link_url is distinct from old.link_url then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

-- At most 3 tags per post. tg_argv[0] names the post id column.
create or replace function private.enforce_post_tag_limit()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_count int;
begin
  execute format('select count(*) from public.%I where %I = $1',
                 tg_table_name, tg_argv[0])
    into v_count
    using (to_jsonb(new) ->> tg_argv[0])::uuid;
  if v_count >= 3 then
    raise exception 'A post can have at most 3 tags.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;


-- ─── 2. News ───────────────────────────────────────────────────────────────

alter table public.community_news
  add column link_url  text check (link_url is null or link_url ~* '^https?://\S+$'),
  add column upvotes   int not null default 0,
  add column downvotes int not null default 0,
  add column search_tsv tsvector
    generated always as (to_tsvector('english', title || ' ' || body)) stored;

create index idx_community_news_search
  on public.community_news using gin (search_tsv);

drop trigger if exists trg_community_news_touch on public.community_news;
create trigger trg_community_news_touch before update on public.community_news
  for each row execute function private.touch_post_updated_at();

-- Community admins may now edit and delete any news in their community.
drop policy if exists community_news_update on public.community_news;
create policy community_news_update on public.community_news
  for update to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

drop policy if exists community_news_delete on public.community_news;
create policy community_news_delete on public.community_news
  for delete to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create table public.community_news_tags (
  news_id uuid not null references public.community_news(id) on delete cascade,
  tag_id  uuid not null references public.topic_tags(id) on delete cascade,
  primary key (news_id, tag_id)
);

create index idx_community_news_tags_tag on public.community_news_tags(tag_id);

alter table public.community_news_tags enable row level security;

-- Readable wherever the news item is (RLS on community_news applies).
create policy community_news_tags_select on public.community_news_tags
  for select to authenticated
  using (exists (select 1 from public.community_news n where n.id = news_id));

create policy community_news_tags_insert on public.community_news_tags
  for insert to authenticated
  with check (
    exists (
      select 1 from public.community_news n
      where n.id = news_id
        and (
          n.author_id = (select auth.uid())
          or (select private.is_community_admin(n.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

create policy community_news_tags_delete on public.community_news_tags
  for delete to authenticated
  using (
    exists (
      select 1 from public.community_news n
      where n.id = news_id
        and (
          n.author_id = (select auth.uid())
          or (select private.is_community_admin(n.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

create trigger trg_community_news_tags_limit
  before insert on public.community_news_tags
  for each row execute function private.enforce_post_tag_limit('news_id');


-- ─── 3. Parent Hub resources (community-scoped) ────────────────────────────

alter table public.parent_resources rename column url to link_url;

alter table public.parent_resources
  alter column link_url drop not null,
  add column community_id uuid references public.communities(id) on delete cascade,
  add column author_id    uuid references public.profiles(id) on delete set null,
  add column body         text not null default '',
  add column updated_at   timestamptz not null default now(),
  add column upvotes      int not null default 0,
  add column downvotes    int not null default 0;

-- Copy each global resource (and its tags) into every community.
-- (Plain temp table, dropped below: the SQL editor may not wrap the script
-- in one transaction, so "on commit drop" could vanish too early.)
create temporary table _resource_copies as
  select r.id as old_id, c.id as community_id, gen_random_uuid() as new_id
  from public.parent_resources r
  cross join public.communities c
  where r.community_id is null;

insert into public.parent_resources
  (id, community_id, title, link_url, body, sort_order, created_at, updated_at)
select x.new_id, x.community_id, r.title, r.link_url, r.body, r.sort_order,
       r.created_at, r.created_at
from _resource_copies x
join public.parent_resources r on r.id = x.old_id;

insert into public.parent_resource_tags (resource_id, tag_id)
select x.new_id, t.tag_id
from _resource_copies x
join public.parent_resource_tags t on t.resource_id = x.old_id;

-- Cascades to the originals' tags.
delete from public.parent_resources where community_id is null;

drop table _resource_copies;

alter table public.parent_resources
  alter column community_id set not null,
  add constraint parent_resources_link_url_format
    check (link_url is null or link_url ~* '^https?://\S+$'),
  add constraint parent_resources_has_content
    check (length(btrim(body)) > 0 or link_url is not null),
  add column search_tsv tsvector
    generated always as (to_tsvector('english', title || ' ' || body)) stored;

create index idx_parent_resources_community
  on public.parent_resources(community_id, created_at desc);

create index idx_parent_resources_search
  on public.parent_resources using gin (search_tsv);

create trigger trg_parent_resources_touch before update on public.parent_resources
  for each row execute function private.touch_post_updated_at();

drop policy if exists parent_resources_select on public.parent_resources;

create policy parent_resources_select on public.parent_resources
  for select to authenticated
  using (
    (select private.is_community_member(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy parent_resources_insert on public.parent_resources
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (
      (select private.is_community_admin(community_id))
      or (select private.current_app_role()) in ('regional_admin', 'app_admin')
    )
  );

create policy parent_resources_update on public.parent_resources
  for update to authenticated
  using (
    (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  )
  with check (
    (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

create policy parent_resources_delete on public.parent_resources
  for delete to authenticated
  using (
    (select private.is_community_admin(community_id))
    or (select private.current_app_role()) in ('regional_admin', 'app_admin')
  );

drop policy if exists parent_resource_tags_select on public.parent_resource_tags;

create policy parent_resource_tags_select on public.parent_resource_tags
  for select to authenticated
  using (exists (select 1 from public.parent_resources r where r.id = resource_id));

create policy parent_resource_tags_insert on public.parent_resource_tags
  for insert to authenticated
  with check (
    exists (
      select 1 from public.parent_resources r
      where r.id = resource_id
        and (
          (select private.is_community_admin(r.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

create policy parent_resource_tags_delete on public.parent_resource_tags
  for delete to authenticated
  using (
    exists (
      select 1 from public.parent_resources r
      where r.id = resource_id
        and (
          (select private.is_community_admin(r.community_id))
          or (select private.current_app_role()) in ('regional_admin', 'app_admin')
        )
    )
  );

create trigger trg_parent_resource_tags_limit
  before insert on public.parent_resource_tags
  for each row execute function private.enforce_post_tag_limit('resource_id');


-- ─── Set tags (news / resource) ────────────────────────────────────────────

-- security invoker: the tag tables' RLS decides who may (re)tag.
create or replace function public.set_post_tags(
  p_kind    text,
  p_post_id uuid,
  p_tag_ids uuid[]
)
returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if cardinality(coalesce(p_tag_ids, '{}')) > 3 then
    raise exception 'A post can have at most 3 tags.'
      using errcode = 'check_violation';
  end if;

  if p_kind = 'news' then
    delete from public.community_news_tags where news_id = p_post_id;
    insert into public.community_news_tags (news_id, tag_id)
      select p_post_id, t
      from (select distinct unnest(coalesce(p_tag_ids, '{}'))) as u(t);
  elsif p_kind = 'resource' then
    delete from public.parent_resource_tags where resource_id = p_post_id;
    insert into public.parent_resource_tags (resource_id, tag_id)
      select p_post_id, t
      from (select distinct unnest(coalesce(p_tag_ids, '{}'))) as u(t);
  else
    raise exception 'INVALID_KIND';
  end if;
end;
$$;

grant execute on function public.set_post_tags(text, uuid, uuid[]) to authenticated;


-- ─── 4. Voting ─────────────────────────────────────────────────────────────

alter table public.community_discussions
  add column upvotes   int not null default 0,
  add column downvotes int not null default 0;

alter table public.community_discussion_replies
  add column helpful_count int not null default 0;

create table public.community_discussion_votes (
  item_id    uuid not null references public.community_discussions(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (item_id, user_id)
);

create table public.community_news_votes (
  item_id    uuid not null references public.community_news(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (item_id, user_id)
);

create table public.parent_resource_votes (
  item_id    uuid not null references public.parent_resources(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (item_id, user_id)
);

-- Upvote only ("helpful").
create table public.community_reply_votes (
  item_id    uuid not null references public.community_discussion_replies(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (item_id, user_id)
);

-- RLS: each user sees and writes only their own votes, and only on items
-- they can read (the item tables' RLS — adults-only membership — applies
-- inside the exists()).
alter table public.community_discussion_votes enable row level security;
alter table public.community_news_votes       enable row level security;
alter table public.parent_resource_votes      enable row level security;
alter table public.community_reply_votes      enable row level security;

create policy community_discussion_votes_select on public.community_discussion_votes
  for select to authenticated using (user_id = (select auth.uid()));
create policy community_discussion_votes_insert on public.community_discussion_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.community_discussions d where d.id = item_id)
  );
create policy community_discussion_votes_update on public.community_discussion_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy community_discussion_votes_delete on public.community_discussion_votes
  for delete to authenticated using (user_id = (select auth.uid()));

create policy community_news_votes_select on public.community_news_votes
  for select to authenticated using (user_id = (select auth.uid()));
create policy community_news_votes_insert on public.community_news_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.community_news n where n.id = item_id)
  );
create policy community_news_votes_update on public.community_news_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy community_news_votes_delete on public.community_news_votes
  for delete to authenticated using (user_id = (select auth.uid()));

create policy parent_resource_votes_select on public.parent_resource_votes
  for select to authenticated using (user_id = (select auth.uid()));
create policy parent_resource_votes_insert on public.parent_resource_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.parent_resources r where r.id = item_id)
  );
create policy parent_resource_votes_update on public.parent_resource_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy parent_resource_votes_delete on public.parent_resource_votes
  for delete to authenticated using (user_id = (select auth.uid()));

create policy community_reply_votes_select on public.community_reply_votes
  for select to authenticated using (user_id = (select auth.uid()));
create policy community_reply_votes_insert on public.community_reply_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.community_discussion_replies r where r.id = item_id)
  );
create policy community_reply_votes_delete on public.community_reply_votes
  for delete to authenticated using (user_id = (select auth.uid()));

-- Recount an item's up/down votes. tg_argv[0] names the item table. Runs as
-- definer: voters can't UPDATE posts they didn't write.
create or replace function private.tally_votes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_item uuid;
begin
  if tg_op = 'DELETE' then
    v_item := old.item_id;
  else
    v_item := new.item_id;
  end if;

  execute format(
    'update public.%I set
       upvotes   = (select count(*) from public.%I where item_id = $1 and value = 1),
       downvotes = (select count(*) from public.%I where item_id = $1 and value = -1)
     where id = $1',
    tg_argv[0], tg_table_name, tg_table_name)
  using v_item;

  return null;
end;
$$;

create trigger trg_community_discussion_votes_tally
  after insert or update or delete on public.community_discussion_votes
  for each row execute function private.tally_votes('community_discussions');

create trigger trg_community_news_votes_tally
  after insert or update or delete on public.community_news_votes
  for each row execute function private.tally_votes('community_news');

create trigger trg_parent_resource_votes_tally
  after insert or update or delete on public.parent_resource_votes
  for each row execute function private.tally_votes('parent_resources');

create or replace function private.tally_reply_helpful()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_item uuid;
begin
  if tg_op = 'DELETE' then
    v_item := old.item_id;
  else
    v_item := new.item_id;
  end if;

  update public.community_discussion_replies
    set helpful_count = (select count(*) from public.community_reply_votes
                         where item_id = v_item)
    where id = v_item;

  return null;
end;
$$;

create trigger trg_community_reply_votes_tally
  after insert or delete on public.community_reply_votes
  for each row execute function private.tally_reply_helpful();

-- Cast (1 / -1) or clear (0) the caller's vote; returns the new tally.
create or replace function public.cast_vote(
  p_kind    text,
  p_item_id uuid,
  p_value   int
)
returns table (upvotes int, downvotes int, my_vote int)
language plpgsql security invoker set search_path = '' as $$
#variable_conflict use_column
declare
  v_votes text;
  v_items text;
begin
  if p_value not in (-1, 0, 1) then
    raise exception 'INVALID_VOTE' using errcode = 'check_violation';
  end if;

  case p_kind
    when 'discussion' then
      v_votes := 'community_discussion_votes'; v_items := 'community_discussions';
    when 'news' then
      v_votes := 'community_news_votes';       v_items := 'community_news';
    when 'resource' then
      v_votes := 'parent_resource_votes';      v_items := 'parent_resources';
    else
      raise exception 'INVALID_KIND';
  end case;

  if p_value = 0 then
    execute format(
      'delete from public.%I where item_id = $1 and user_id = auth.uid()',
      v_votes)
    using p_item_id;
  else
    execute format(
      'insert into public.%I (item_id, user_id, value)
         values ($1, auth.uid(), $2::smallint)
       on conflict (item_id, user_id) do update set value = excluded.value',
      v_votes)
    using p_item_id, p_value;
  end if;

  return query execute format(
    'select i.upvotes, i.downvotes,
            coalesce((select v.value::int from public.%I v
                      where v.item_id = i.id and v.user_id = auth.uid()), 0)
     from public.%I i where i.id = $1',
    v_votes, v_items)
  using p_item_id;
end;
$$;

grant execute on function public.cast_vote(text, uuid, int) to authenticated;

-- Toggle the caller's "helpful" on a reply; returns the new count.
create or replace function public.toggle_reply_helpful(p_reply_id uuid)
returns table (helpful_count int, liked_by_me boolean)
language plpgsql security invoker set search_path = '' as $$
#variable_conflict use_column
begin
  if exists (select 1 from public.community_reply_votes v
             where v.item_id = p_reply_id and v.user_id = auth.uid()) then
    delete from public.community_reply_votes v
      where v.item_id = p_reply_id and v.user_id = auth.uid();
  else
    insert into public.community_reply_votes (item_id, user_id)
      values (p_reply_id, auth.uid());
  end if;

  return query
    select r.helpful_count,
           exists (select 1 from public.community_reply_votes v
                   where v.item_id = r.id and v.user_id = auth.uid())
    from public.community_discussion_replies r
    where r.id = p_reply_id;
end;
$$;

grant execute on function public.toggle_reply_helpful(uuid) to authenticated;


-- ─── Search RPCs ───────────────────────────────────────────────────────────

-- Discussions: same as 0030 plus votes and a "top" sort. The return type
-- changes, so drop first.
drop function if exists public.search_community_discussions(uuid, uuid[], text, text);

create function public.search_community_discussions(
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
  upvotes           int,
  downvotes         int,
  my_vote           int,
  created_at        timestamptz,
  updated_at        timestamptz,
  author_first_name text,
  author_last_name  text,
  tag_ids           uuid[]
)
language sql stable security invoker set search_path = '' as $$
  select
    d.id, d.community_id, d.author_id, d.title, d.body, d.image_urls,
    d.reply_count, d.last_activity_at, d.upvotes, d.downvotes,
    coalesce((select v.value::int from public.community_discussion_votes v
              where v.item_id = d.id and v.user_id = (select auth.uid())), 0),
    d.created_at, d.updated_at,
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
    case when p_sort = 'activity' then d.last_activity_at       end desc nulls last,
    case when p_sort = 'replies'  then d.reply_count            end desc nulls last,
    case when p_sort = 'top'      then d.upvotes - d.downvotes  end desc nulls last,
    case when p_sort = 'oldest'   then d.created_at             end asc  nulls last,
    d.created_at desc
$$;

grant execute on function public.search_community_discussions(uuid, uuid[], text, text)
  to authenticated;

-- News and resources return the same shape so the app can share one model.
create or replace function public.search_community_news(
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
  link_url          text,
  upvotes           int,
  downvotes         int,
  my_vote           int,
  created_at        timestamptz,
  updated_at        timestamptz,
  author_first_name text,
  author_last_name  text,
  tag_ids           uuid[]
)
language sql stable security invoker set search_path = '' as $$
  select
    n.id, n.community_id, n.author_id, n.title, n.body, n.link_url,
    n.upvotes, n.downvotes,
    coalesce((select v.value::int from public.community_news_votes v
              where v.item_id = n.id and v.user_id = (select auth.uid())), 0),
    n.created_at, n.updated_at,
    p.first_name, p.last_name,
    coalesce(
      (select array_agg(t.tag_id) from public.community_news_tags t
       where t.news_id = n.id),
      '{}'::uuid[]
    )
  from public.community_news n
  left join public.profiles p on p.id = n.author_id
  where n.community_id = p_community_id
    and (
      p_tag_ids is null or cardinality(p_tag_ids) = 0
      or exists (
        select 1 from public.community_news_tags t
        where t.news_id = n.id and t.tag_id = any(p_tag_ids)
      )
    )
    and (
      p_query is null or btrim(p_query) = ''
      or n.search_tsv @@ websearch_to_tsquery('english', p_query)
      or n.title ilike '%' || btrim(p_query) || '%'
      or n.body  ilike '%' || btrim(p_query) || '%'
    )
  order by
    case when p_sort = 'top'    then n.upvotes - n.downvotes end desc nulls last,
    case when p_sort = 'oldest' then n.created_at            end asc  nulls last,
    n.created_at desc
$$;

grant execute on function public.search_community_news(uuid, uuid[], text, text)
  to authenticated;

create or replace function public.search_parent_resources(
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
  link_url          text,
  upvotes           int,
  downvotes         int,
  my_vote           int,
  created_at        timestamptz,
  updated_at        timestamptz,
  author_first_name text,
  author_last_name  text,
  tag_ids           uuid[]
)
language sql stable security invoker set search_path = '' as $$
  select
    r.id, r.community_id, r.author_id, r.title, r.body, r.link_url,
    r.upvotes, r.downvotes,
    coalesce((select v.value::int from public.parent_resource_votes v
              where v.item_id = r.id and v.user_id = (select auth.uid())), 0),
    r.created_at, r.updated_at,
    p.first_name, p.last_name,
    coalesce(
      (select array_agg(t.tag_id) from public.parent_resource_tags t
       where t.resource_id = r.id),
      '{}'::uuid[]
    )
  from public.parent_resources r
  left join public.profiles p on p.id = r.author_id
  where r.community_id = p_community_id
    and (
      p_tag_ids is null or cardinality(p_tag_ids) = 0
      or exists (
        select 1 from public.parent_resource_tags t
        where t.resource_id = r.id and t.tag_id = any(p_tag_ids)
      )
    )
    and (
      p_query is null or btrim(p_query) = ''
      or r.search_tsv @@ websearch_to_tsquery('english', p_query)
      or r.title ilike '%' || btrim(p_query) || '%'
      or r.body  ilike '%' || btrim(p_query) || '%'
    )
  order by
    case when p_sort = 'top'    then r.upvotes - r.downvotes end desc nulls last,
    case when p_sort = 'oldest' then r.created_at            end asc  nulls last,
    case when p_sort = 'title'  then lower(r.title)          end asc  nulls last,
    r.created_at desc
$$;

grant execute on function public.search_parent_resources(uuid, uuid[], text, text)
  to authenticated;


-- ─── 5. Related discussions ────────────────────────────────────────────────

-- Discussions in the news post's community, ranked by shared tags, then
-- text similarity to the news title/body (any word), then recent activity.
-- Only discussions sharing a tag or matching some text are returned.
create or replace function public.related_discussions(
  p_news_id uuid,
  p_limit   int default 5
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
  upvotes           int,
  downvotes         int,
  my_vote           int,
  created_at        timestamptz,
  updated_at        timestamptz,
  author_first_name text,
  author_last_name  text,
  tag_ids           uuid[]
)
language sql stable security invoker set search_path = '' as $$
  with news as (
    select
      n.community_id,
      coalesce(
        (select array_agg(t.tag_id) from public.community_news_tags t
         where t.news_id = n.id),
        '{}'::uuid[]
      ) as tags,
      -- plainto_tsquery ANDs the words; swap to OR so any shared word counts.
      replace(plainto_tsquery('english', n.title || ' ' || n.body)::text,
              ' & ', ' | ')::tsquery as q
    from public.community_news n
    where n.id = p_news_id
  ),
  scored as (
    select
      d.*,
      (select count(*) from public.community_discussion_tags t
       where t.discussion_id = d.id and t.tag_id = any(news.tags)) as shared,
      ts_rank(d.search_tsv, news.q) as rank,
      d.search_tsv @@ news.q as text_match
    from public.community_discussions d
    cross join news
    where d.community_id = news.community_id
  )
  select
    s.id, s.community_id, s.author_id, s.title, s.body, s.image_urls,
    s.reply_count, s.last_activity_at, s.upvotes, s.downvotes,
    coalesce((select v.value::int from public.community_discussion_votes v
              where v.item_id = s.id and v.user_id = (select auth.uid())), 0),
    s.created_at, s.updated_at,
    p.first_name, p.last_name,
    coalesce(
      (select array_agg(t.tag_id) from public.community_discussion_tags t
       where t.discussion_id = s.id),
      '{}'::uuid[]
    )
  from scored s
  left join public.profiles p on p.id = s.author_id
  where s.shared > 0 or s.text_match
  order by s.shared desc, s.rank desc, s.last_activity_at desc
  limit least(greatest(coalesce(p_limit, 5), 1), 20)
$$;

grant execute on function public.related_discussions(uuid, int) to authenticated;
