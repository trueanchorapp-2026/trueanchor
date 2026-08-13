# TrueAnchor - CLAUDE.md

## Mission
TrueAnchor equips churches, families, and communities with tools that help youth grow in their relationship with Christ and empower parents to impact their communities. Parents are the primary disciple-makers, while churches equip, encourage, and support families — and communities unite families for outward impact.

## Product Vision
- Ministry-first, nonprofit Phase 1.
- Flutter application targeting Web first, then Android/iOS from the same codebase.
- Dual-scoped architecture: church (discipleship) + community (outreach).
- Three growth directions: Upward (devotions), Inward (reflection), Outward (community impact).
- Native discipleship content in V1.

## Target Users
- App Admin
- Regional Admin (standalone role, manages regions and communities)
- Church Admin
- Youth Pastor
- Parent
- Youth
- Community Admin (contextual role within a community, not a standalone user_role)

## Roles

### User Roles (user_role enum)
- **App Admin** — Platform-level administration. Not church-scoped.
- **Regional Admin** — Standalone role. Creates and administers regions and communities. No church membership required.
- **Church Admin** — Manages church invites, families, events.
- **Youth Pastor** — Pastoral care, messaging, engagement dashboard.
- **Parent** — Household adult. Primary disciple-maker.
- **Youth** — Household minor. Discipleship participant.

### Contextual Roles
- **Community Admin** — A membership-level role within `community_memberships`. An existing parent (or other adult church member) elevated by a Regional Admin to manage a specific community. They retain their church role and gain community management privileges (create events, moderate posts, post news) for that community only.

### Family Roles (family_role enum)
Household labels assigned by head of household: parent, guardian, grandparent, youth. All adult labels grant `UserRole.parent` permissions; youth label grants `UserRole.youth` permissions.

## Core Principles
- Parents are primary disciple-makers.
- Churches strengthen families rather than replace them.
- Communities unite families for outward impact regardless of church affiliation.
- Encourage Scripture engagement over app engagement.
- Growth happens in three directions: Upward (toward God), Inward (self-reflection), Outward (loving action).
- Privacy balanced with accountability.
- Community features are adults-only; youth outward growth happens within church and school contexts.
- Keep UX simple, reliable, and accessible.

## Navigation
Four main sections, role-dependent visibility:

- **Home** — Primary updates, notifications, alerts.
- **Discipleship** — Devotionals, journal/prayer, progress, milestones, messaging, love-in-action.
- **Community** — Adults only. Community news, discussions, events, parent resources. Hidden from youth.
- **Profile** — User profile, settings, city/state of residence.

## MVP Features

### Implemented
- Authentication (Email/Password, Google)
- Family management (create, join, head of household, member roles)
- Profiles (parent, youth, pastor, church admin, app admin)
- Daily devotionals (global content)
- Prayer journal with configurable sharing/visibility
- Church-scoped events
- 1-on-1 pastor messaging (parent/youth ↔ youth pastor)
- Progress tracking (daily checkboxes, streaks)
- Spiritual milestones (manual + auto-logged)
- Youth engagement dashboard (youth pastor view)
- Church directory and invite codes

### New — Home
- Notifications feed (daily devotion reminder, prayer reminder, event reminders, disengagement alerts)
- Community updates summary for adults

### New — Discipleship
- **Devotional restructure**: Each devotional includes Verse of the Day, Upward Reflection (core teaching), Inward Reflection (the journal/prayer entry itself — users write their reflection and prayer inline as part of the devotional flow), and Outward action (youth: loving action opportunity; adults: community awareness).
- **Relational capital tracker** (youth Outward): Youth log and track ongoing relationships — befriending a lonely classmate, inviting someone to youth group, praying for a specific person. Each relationship can have multiple logged interactions over time with follow-up next steps, building a picture of sustained outward investment rather than one-off actions.
- **Youth group chat**: Youth pastor creates group, invites youth members from the same church. Supplements existing 1-on-1 messaging. Church-scoped (must be same church to join).

### New — Community (adults only)
- **Regions**: County-level entity created by Regional Admin (e.g., Broward County).
- **Communities**: City-level entity within a region, created by Regional Admin (e.g., Boca Raton, Coral Springs, Weston). Based on physical location.
- **Community membership**: Head of household joins a community for the family. One community per family. Any family can join any community regardless of church affiliation.
- **Community news/updates**: Regional Admin or Community Admin posts news and updates (e.g., school board decisions, curriculum concerns).
- **School information hub**: Local district insights, policy summaries, and parent engagement guidance — surfaced within the Community tab as community-scoped content.
- **Discussion posts**: Adult community members create and interact with discussion threads about community issues.
- **Community events**: Separate from church events. Created by Regional Admin or Community Admin. Outreach-focused.
- **Parent resource portal**: Curated links and content for parents — biblical worldview resources, media literacy guides, identity conversation starters, practical parenting tools (content provided later).

### New — Profile
- City/state of residence (used for community matching so families join the right community).

### Cross-cutting
- Offline support with local-first sync (journals, devotions, activities)

## Future Roadmap
- Custom church curriculum
- AI features
- Mobile store subscriptions

## Tech Stack
- Flutter
- Material 3
- Supabase
- GitHub
- Claude Code

## Architecture
Clean Architecture:
- Presentation
- Application
- Domain
- Infrastructure

Feature-first organization. New feature slices for community, regions, group chat, love-in-action, and notifications.

## Multi-tenancy
Dual scoping:
- **Church scope**: Every church-owned record includes `church_id`. Families belong to one church. Messaging, events, progress, milestones, and engagement are church-scoped.
- **Community scope**: Community-owned records include `community_id`. Regions contain communities. Communities are independent of churches. A family optionally belongs to one community.

## Data Ownership
- **Global**: Native devotional content (shared across all churches).
- **Region**: Communities within the region.
- **Community**: Memberships, news/updates, discussion posts, community events, parent resources.
- **Church**: Users, families, church events, messaging, progress, milestones, engagement.
- **Family**: Parents and youth. Family belongs to one church and optionally one community.
- **Youth**: Belong to exactly one family.

## Community Model
- A **Region** is a geographic area (e.g., county) created and managed by a Regional Admin.
- A **Community** is a location-based group within a region (e.g., city) created by a Regional Admin.
- **Community membership** is per-family: head of household joins. Only adults in the family see community features.
- **Community Admin** is a contextual role — a Regional Admin elevates an existing community member to manage that specific community (create events, moderate discussions, post news).
- Communities are independent of churches: families from different churches can be in the same community.

## Family Model
Head of Household creates/manages family.
Church Admin may override/manage.
Family belongs to one church and optionally one community (joined by head of household).

## Youth Profile
- Name
- Age
- Grade
- Gender
- Baptized
- Prayer requests
- Journal
- Relational capital tracker (ongoing relationship logs)
Sharing for journals/prayers is configurable.

## Content
Global native devotional content, structured per devotional:
- Verse of the Day
- Upward Reflection (core devotional teaching)
- Inward Reflection (the journal/prayer section — user writes their reflection and prayer inline)
- Outward action (youth: loving action opportunity; adults: community awareness)

## Spiritual Milestones
Track achievements such as:
- Accepted Christ
- Baptized
- Scripture memory
- Devotion consistency
- Ministry/service milestones

## Notifications
- Daily devotion reminder
- Prayer reminder
- Event reminders (church and community)
- Memory verse reminders
- Youth Pastor alerts for disengagement
- Community news alerts (adults only)

## Offline
Local-first:
- Journals
- Devotions
- Activities
Sync automatically.

## UI/UX
- Material 3
- Light mode initially
- Consistent spacing
- Reusable widgets
- Loading indicators
- Never block UI
- Confirm destructive actions
- Pull-to-refresh
- Offline sync indicator

## Coding Standards
- Modular code
- No business logic in UI
- Follow Flutter best practices
- Reusable widgets
- Favor composition
- Keep business logic in services/use cases

## Testing
Manual feature testing during development.
Unit tests required for business logic and non-trivial services.

## Security
Privacy policy later.
Role-based access control throughout.
Community features enforce adults-only access at both UI and database (RLS) levels.

## Definition of Done
- Feature implemented
- Business logic unit tested
- Manual verification complete
- Responsive on Web
- No analyzer warnings
- No debug code

## Claude Guidelines
- Respect architecture.
- Never place business logic in widgets.
- Prefer reusable components.
- Preserve church multi-tenancy.
- Preserve community scoping alongside church scoping.
- Community features must enforce adults-only access.
- Devotional content must include all sections: verse, upward, inward, outward, prayer.
- Optimize for maintainability over cleverness.
- Be concise in responses.