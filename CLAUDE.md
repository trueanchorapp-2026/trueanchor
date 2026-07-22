# TrueAnchor - CLAUDE.md

## Mission
TrueAnchor equips churches and parents with discipleship tools that help youth grow in their relationship with Christ. Parents are the primary disciple-makers, while churches equip, encourage, and support families.

## Product Vision
- Ministry-first, nonprofit Phase 1.
- Flutter application targeting Web first, then Android/iOS from the same codebase.
- Church-scoped multi-tenant architecture.
- Native discipleship content in V1.

## Target Users
- App Admin
- Church Admin
- Youth Pastor
- Parent
- Youth

## Core Principles
- Parents are primary disciple-makers.
- Churches strengthen families rather than replace them.
- Encourage Scripture engagement over app engagement.
- Privacy balanced with accountability.
- Keep UX simple, reliable, and accessible.

## MVP Features
- Authentication (Email/Password, Google)
- Family management
- Parent, Youth, Pastor profiles
- Daily devotionals
- Prayer journal
- Events
- Messaging
- Progress tracking
- Spiritual milestones
- Notifications
- Offline support with sync

## Future Roadmap
- Custom church curriculum
- Parent resource portal
- Outreach events
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

Feature-first organization.

## Multi-tenancy
Every church-owned record includes `church_id`.
Families belong to one church.
One family cannot belong to multiple churches.

## Data Ownership
- Global: native content.
- Church: users, families, events, messaging, progress.
- Family: parents and youth.
- Youth belong to exactly one family.

## Family Model
Head of Household creates/manages family.
Church Admin may override/manage.

## Youth Profile
- Name
- Age
- Grade
- Gender
- Baptized
- Prayer requests
- Journal
Sharing for journals/prayers is configurable.

## Content
Global native content:
- Articles
- Devotionals
- Discussion questions
- Activities

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
- Event reminders
- Memory verse reminders
- Youth Pastor alerts for disengagement

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

## Navigation
Role-specific navigation will be finalized later.

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
- Optimize for maintainability over cleverness.
