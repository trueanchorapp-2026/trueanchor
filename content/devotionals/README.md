# Devotional content

Devotionals are written **one week at a time**, under a shared theme. One JSON
file holds a whole week:

```
content/devotionals/
  youth/2026-11-16-courage.json     ← one file per week, per audience
  adult/...                         ← adult track (optional, same format)
  _archive/                         ← pre-weekly daily files; never read
```

The filename **must** start with the week's `starts_on` date, followed by a
short slug: `2026-11-30-faithfulness.json`. The folder **must** match the
file's `audience`.

Devotionals are global — every church reads the same one on the same date.

## Audiences

- **youth** — read by youth and youth pastors.
- **adult** — read by parents and other adults. When no adult devotional
  exists for a date, adults read the youth one, so the adult track is
  optional.

## Writing a week

```json
{
  "audience": "youth",
  "theme": "Courage",
  "theme_summary": null,
  "starts_on": "2026-11-16",
  "translation": "NIV",
  "copyright_notice": "Scripture quotations taken from ...",
  "days": [
    {
      "day": 1,
      "title": "Courage Rooted in God’s Presence and Promises",
      "scripture_reference": "Joshua 1:9",
      "scripture_text": "Have I not commanded you? ...",
      "context": "Line one.\nLine two.\n\nNew paragraph.\n• A bullet",
      "deeper_reference": "Joshua 1:1-9",
      "deeper_text": "After the death of Moses ...",
      "summary": "...",
      "upward": "...",
      "upward_questions": ["..."],
      "inward": "...",
      "inward_questions": ["...", "..."],
      "outward": "...",
      "outward_questions": ["..."],
      "prayer": "...",
      "self_application": ["...", "...", "..."],
      "love_in_action": "...",
      "love_in_action_questions": ["..."]
    }
  ]
}
```

### Week fields

| Field | Required | Notes |
|---|---|---|
| `audience` | yes | `youth` or `adult`. Must match the folder. |
| `theme` | yes | Short, e.g. `Courage`. Shown as "This week: Courage · Day 2". |
| `theme_summary` | no | Optional intro for the week. |
| `starts_on` | yes | `yyyy-MM-dd` of day 1. Day N publishes on `starts_on + (N − 1)`. |
| `translation` | yes | Default translation abbreviation for every day, e.g. `NIV`. |
| `copyright_notice` | no | Default notice for every day. Required for licensed translations. |
| `days` | yes | 1 to 7 days. Weeks with fewer than 7 days are fine: the app shows the most recent devotional on days with nothing published. |

### Day fields

Every field below is required unless marked optional.

| Field | Section |
|---|---|
| `day` | 1–7, unique within the week |
| `title` | Page heading |
| `scripture_reference`, `scripture_text` | Verse of the Day |
| `context` | "<Theme> in Context" |
| `deeper_reference`, `deeper_text` | Go Deeper (collapsed by default) |
| `summary` | Summary |
| `upward`, `upward_questions` | Upward + Reflect |
| `inward`, `inward_questions` | Inward + Reflect (these questions are the prompts for the inline journal entry) |
| `outward`, `outward_questions` | Outward + Reflect |
| `prayer` | Prayer |
| `self_application` | Self-Application questions |
| `love_in_action`, `love_in_action_questions` | Love in Action + Reflect (the "Log Love in Action" button appears here) |
| `translation` *(optional)* | Overrides the week's translation for this day |
| `copyright_notice` *(optional)* | Overrides the week's notice, e.g. when a day also quotes ESV |
| `deeper_translation` *(optional)* | Set it when the Go Deeper passage uses a different translation from the verse |

Each question list holds 1 to 5 entries.

### Text formatting

Plain text. **Markdown is not rendered.**

- `\n\n` (blank line) starts a new paragraph.
- `\n` is a line break.
- A line starting with `• ` is shown as a bullet.

Use curly quotes (“ ” ’) in prose. A straight `"` inside a JSON string has to
be escaped as `\"`, which is easy to get wrong. Text must not contain the
literal `$ta$`, which the generator uses as a quote delimiter.

Unknown fields are rejected, so a typo like `"sciprture_text"` fails the build
instead of silently publishing an empty section.

Leave out screen labels such as "Youth Mode | Daily Biblical Discipleship" and
"Write it here:". The app supplies those.

## Scripture licensing

NIV and ESV each require their notice wherever their text appears. Put the
notice in `copyright_notice`. When a day quotes both, include both notices
separated by a blank line (see day 6 of the Courage week). Public domain texts
(WEB, KJV) need no notice: use `null`.

## Publishing

1. Add or edit the week's JSON file.
2. Run:
   ```powershell
   .\scripts\build_devotionals.ps1
   ```
   The script checks every file. If anything is wrong, it lists every problem
   and writes nothing. Otherwise it regenerates
   `supabase/seed/devotionals_seed.sql`.
3. Open Supabase → **SQL Editor**, paste the whole generated file, and click
   **Run**.

The seed updates existing rows instead of duplicating them: themes are matched
on audience + start date, and devotionals on audience + date. To fix a typo,
edit the JSON, re-run, and re-paste. Journal entries and progress stay linked,
because the devotional ids don't change.

The seed never deletes anything. If you **move a week to different dates**,
the rows on the old dates stay. Delete them in the SQL Editor:

```sql
delete from public.devotional_themes
 where audience = 'youth' and starts_on = '2026-11-23';      -- old start
delete from public.devotionals
 where audience = 'youth' and publish_on between '2026-11-23' and '2026-11-29'
   and theme_id is null;
```

Never edit `devotionals_seed.sql` by hand. It is rewritten in full on every
run.
