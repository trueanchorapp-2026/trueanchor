# Devotional content

One JSON file per publication date. The filename **must** be the `publish_on`
date it contains: `2026-08-01.json`. That rule is what makes a duplicate date
visible in a directory listing instead of at the end of a failed import.

Every church reads the same devotional on the same date — devotionals are
global platform content, not church-scoped.

## Writing a devotional

```json
{
  "publish_on": "2026-08-01",
  "title": "An Anchor for the Soul",
  "scripture_reference": "Hebrews 6:19-20",
  "scripture_text": "This hope we have as an anchor of the soul, a hope both sure and steadfast...",
  "translation": "WEB",
  "copyright_notice": null,
  "body": "Plain text.\n\nA blank line starts a new paragraph.",
  "discussion_questions": [
    "Where do you feel unsteady this week?",
    "What does it mean that hope can hold you still?"
  ],
  "activity": "Write one sentence in your journal naming the storm you are in."
}
```

| Field | Required | Notes |
|---|---|---|
| `publish_on` | yes | `yyyy-MM-dd`. Must equal the filename. Unique across all files. |
| `title` | yes | Short. It is the page heading. |
| `scripture_reference` | yes | Book, chapter and verse, e.g. `Hebrews 6:19-20`. |
| `scripture_text` | yes | The verse itself, quoted in full. |
| `translation` | yes | Abbreviation only, e.g. `WEB`. Shown as `Hebrews 6:19 (WEB)`. |
| `copyright_notice` | no | `null` for public-domain translations. See licensing below. |
| `body` | yes | The devotional. Plain text — **Markdown is not rendered.** Separate paragraphs with a blank line (`\n\n`). |
| `discussion_questions` | yes | 1 to 5 questions. These are what a parent asks at the dinner table, so write them to be spoken aloud. |
| `activity` | no | One concrete thing to do. Omit or `null` if there isn't one. |

Unknown fields are rejected, so a typo like `"sciprture_text"` fails the import
instead of silently publishing a devotional with no verse.

Text may not contain the literal sequence `$ta$` — the seed generator uses it as
a quote delimiter. Apostrophes, quotation marks, newlines and backslashes are
all fine and need no escaping.

## Audience

Youth, with their parents reading over their shoulder. Aim for 200–350 words in
`body`. Concrete over abstract. The mission is Scripture engagement, not app
engagement: the passage should carry the weight, and the devotional should send
the reader back to it.

## Scripture licensing — read before writing at volume

The samples here use the **World English Bible (WEB)**, which is public domain
and needs no notice. That is a placeholder, not a decision.

If TrueAnchor adopts NIV, ESV, NLT or similar, each requires a licence *and* a
specific attribution notice displayed wherever the verse text appears. Put that
notice in `copyright_notice` and the app renders it beneath the devotional.

**Settle the translation before writing a full quarter.** Re-licensing ninety
finished devotionals is expensive; changing a placeholder is not.

## Publishing

```powershell
.\scripts\build_devotionals.ps1
```

This validates every file and regenerates `supabase/seed/devotionals_seed.sql`.
If anything is wrong it prints all of the problems and writes nothing.

Paste the generated SQL into the Supabase SQL Editor to apply it. It is
idempotent on `publish_on`: re-running updates existing devotionals in place
rather than duplicating them, so fixing a typo is just an edit and a re-paste.

Never edit `devotionals_seed.sql` by hand — it is overwritten wholesale on every
run. Edit the JSON.
