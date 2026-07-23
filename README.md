# TrueAnchor

Discipleship tools for churches and parents. Parents are the primary
disciple-makers; churches equip, encourage, and support families.

Flutter (web first) on Supabase. See [CLAUDE.md](CLAUDE.md) for the product
brief and architecture rules.

## What V1 does

- Email/password registration and sign-in (Google auth comes later)
- Church-scoped signup by **invite code** — the code decides both the church
  and the role
- Profiles for App Admin, Church Admin, Youth Pastor, Parent, and Youth
- Families: a parent creates one and shares a 6-character join code; youth
  join with it
- Journal and prayer entries with per-entry sharing: **Private**, **Share with
  parents**, or **Share with parents and pastor**
- A church view for pastors and admins: households and their members, people who
  never finished setup, and the invite codes in circulation
- Role-aware navigation, responsive between a rail and a bottom bar

Out of scope for V1: Google OAuth, devotionals, events, messaging, progress
tracking, milestones, notifications, offline sync, avatar upload.

## The privacy boundary

Sharing is enforced by **Postgres Row Level Security, not by the UI**. A
`private` entry is unreadable by parents, youth pastors, church admins, and app
admins — even for someone calling the REST API directly with a valid token.
There is deliberately no policy granting anyone but the author read access to a
private entry.

Anything that changes what a role can read belongs in
[supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql), not in a
widget. The wording in `EntryVisibility`
([lib/features/journal/domain/journal_entry.dart](lib/features/journal/domain/journal_entry.dart))
is the user's only window onto those policies — if the two drift, the app is
lying about privacy.

Two more rules the database enforces on its own:

- **No self-promotion.** RLS restricts rows, not columns, so a
  `before update` trigger reverts any client attempt to change its own `role`,
  `church_id`, or `family_id`.
- **No forged tenancy.** A `before insert` trigger stamps `church_id` and
  `family_id` on journal entries from the author's profile, so a client cannot
  post into another church or household.

## Setup

### 1. Flutter

Requires Flutter 3.44+ / Dart 3.12+. Only the Chrome/web toolchain needs to be
green — Android/iOS warnings from `flutter doctor` are expected.

```powershell
flutter config --enable-web
flutter pub get
```

### 2. Supabase

Apply [supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql) in
the SQL Editor. It creates the schema, the RLS policies, the signup trigger, and
seeds one church with starter invite codes.

Then, in the dashboard:

- **Authentication → Sign In / Providers → Email → Confirm email** — off during
  development, **on before real users**.
- **Authentication → URL Configuration** — set Site URL and add a redirect URL
  of `http://localhost:5000`.

### 3. Keys

Configuration is passed at compile time, never hardcoded:

| Define | Value |
| --- | --- |
| `SUPABASE_URL` | your project URL |
| `SUPABASE_PUBLISHABLE_KEY` | the `sb_publishable_…` key |

The publishable key is designed to be public; RLS is what protects the data.

> **Never put a `service_role` / `sb_secret_…` key in this repo, a dart-define,
> or any file the app reads.** It bypasses RLS completely, and a Flutter web
> build ships its source to every visitor's browser.

Note that `supabase_flutter` takes this as `publishableKey:`, *not* `anonKey:` —
they are separate parameters and the latter is deprecated.

## Running

```powershell
.\scripts\run_web.ps1
```

Or from VS Code, the **TrueAnchor (web)** launch configuration. Either wraps:

```powershell
flutter run -d chrome --web-port=5000 `
  --dart-define=SUPABASE_URL=... `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

`Env.assertConfigured()` fails fast at startup with the full command if either
define is missing.

## Testing

```powershell
flutter analyze   # must be zero issues -- Definition of Done
flutter test
```

Unit tests cover the business logic: error mapping, the auth controller, profile
and journal models (including the enum wire values that must stay byte-identical
to the Postgres enums), and the journal controller.

### Verifying the privacy boundary by hand

The tests above cover the client. The boundary itself lives in the database, so
check it there:

1. As a youth, write one `private` entry and one `parents` entry.
2. Sign in as that youth's parent — only the `parents` entry appears.
3. In the SQL Editor, run `select * from journal_entries` **as the parent**
   (Authentication → Users → impersonate). The private row must not come back.
   This proves the boundary holds at the API, not just in the UI.
4. As a youth pastor, confirm neither entry appears — only `parents_pastor` ones
   do.

Also worth re-running after any policy change: signed in as a parent, try
`update profiles set role = 'app_admin' where id = auth.uid()`. It will appear to
succeed; re-query and the role must still be `parent`.

## Architecture

Clean Architecture, organised feature-first. Each feature under `lib/features/`
has the same four layers:

```
domain/          models and abstract repository interfaces -- no Supabase
infrastructure/  Supabase implementations of those interfaces
application/     Riverpod providers and controllers
presentation/    widgets
```

Shared plumbing lives in `lib/core/` (config, router, theme, error mapping,
Supabase providers, reusable widgets).

No business logic in widgets: pages read providers, and every Supabase call sits
behind a `domain/` interface so it can be faked in a test.

State management is Riverpod 3. Dependencies are deliberately codegen-free —
no `freezed`, `build_runner`, or `riverpod_generator`.

## Invite codes

The seed migration creates these for the pilot church. **Rotate or delete them
before any real pilot** — anyone with a code can join that church in that role.

| Code | Role |
| --- | --- |
| `TAADMIN` | Church Admin |
| `TAPASTOR` | Youth Pastor |
| `TAPARENT` | Parent |
| `TAYOUTH` | Youth |

Codes are matched case-insensitively and are checked via the
`validate_invite_code` RPC *before* signup, so a bad code produces a clear
message instead of the opaque failure the aborting trigger would otherwise
return.

A church admin can issue new codes from the church view. Generated codes avoid
characters people misread aloud — no `O`/`0`, no `I`/`1`.

**Known gap:** `church_invites` has select and insert policies but no delete or
update, so there is no revoke button. A delete from the client would silently
affect zero rows and look like it had worked, which is worse than not offering
it. Retire a leaked code in the Supabase dashboard, or add a delete policy in a
follow-up migration. Setting a low use limit is the lever available in the app
today.

## TODO: harden onboarding before a real pilot

Accepted for the current testing stage, **not** acceptable with real families on
it. An invite code is a bearer credential: it carries which church, which role,
and permission to join, all in one string. Whoever holds it becomes a member,
and nobody on the church's side ever confirms them.

Blast radius today, if a code reaches the wrong person:

| Leaked code | What they get |
| --- | --- |
| Parent or Youth | Every profile in the church via `profiles_select_church` — names, emails, phones, birth dates, grades, gender, baptism status. A directory of minors. No journal content: `journal_select_parents` also requires a matching `family_id`, which needs the family's own code. |
| Youth Pastor | Every `parents_pastor` entry church-wide. |
| Church Admin | The above, plus `profiles_update_admin` — they can rewrite anyone's role in the church, including their own. |

The work, roughly in priority order:

1. **Approval queue.** A code gets you in as *pending*; a church admin approves
   before you can see anything. This is the only mechanism that survives a
   leaked code, and codes eventually leak. It must be enforced in RLS, not the
   UI — today `profiles_select_church` grants the whole directory on `church_id`
   alone, so a `status` column has to be threaded into that policy and every
   other church-scoped one. That re-audit is the bulk of the work and the part
   most likely to be got wrong.
2. **Email invites.** Bind an invitation to one address, single-use, expiring —
   no shared secret at all. Needs a `family_invites`/`church_invites` token
   table, an Edge Function to send mail (the client cannot: `inviteUserByEmail`
   requires the `service_role` key), and a signup route that accepts a token.
3. **Staff roles should not be self-service.** `issuableInviteRoles`
   ([church_providers.dart](lib/features/church/application/church_providers.dart))
   includes Church Admin and Youth Pastor. Given the blast radius above, those
   two should be invite-plus-approval only, never a code someone can type.
4. **Force strong codes.** The issue sheet pre-fills a random 8-character code
   but the field is editable and the validator accepts any 4+ characters, so an
   admin can type `CBCCS`. Combined with (5), that is guessable.
5. **Stop leaking church identity to `anon`.** `validate_invite_code` is granted
   to `anon` and returns the church *name*, with no rate limiting — so codes can
   be probed from a signed-out browser. Needed for the pre-signup check, so this
   is rate-limiting or a narrower return shape, not removal.
6. **Require an expiry.** The issue sheet has no `expires_at` field, so every
   code created in-app is permanent.
7. **Rotate the seed codes** (`TAADMIN`, `TAPASTOR`, `TAPARENT`, `TAYOUTH`) —
   they are in this repo, guessable, and never expire.

A separate church ID at signup is deliberately **not** on this list. It would be
a public identifier, and two factors only help when both are secret; it buys
typo-catching, which the "Joining *church* as *role*" confirmation already does.

## TODO: household roles

- `0002_family_roles.sql` needs applying to the Supabase project — it is written
  but not yet run, so none of the family-role behaviour is live.
- Guardian and Grandparent currently resolve to full parent permissions, which
  includes reading entries a youth shared with "parents". If either should be
  visible-but-limited, that is a third tier in `entry_visibility` and its policy
  — worth deciding before churches start using it, not after.
