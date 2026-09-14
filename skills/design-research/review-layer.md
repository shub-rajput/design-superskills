# Review Layer

Supporting file for `design-research` Steps 6 and 7. Only runs when the user chose observations, a gallery, or a comparison in Step 1.

## Review brief (one per source)

File: `screenshots/<source-slug>/review-brief.md`

```markdown
# Review Brief: <Source name>

## Objective
<Exact lens text from Step 1>

## Annotation Depth
<"light" or "impact-opportunity">

## Source
- **Name:** <name>
- **URL:** <base URL>
- **Kind:** public site | logged-in app | local app
- **Description:** <one line>

## Flow Captured
<Numbered list of screens in order; note anything skipped or unreachable>

## Screenshots & Journey Notes

### 01-bookings-list.png
**Screen:** <what it shows>
**Journey:** <1-3 factual sentences from journey.md>

### 02-new-booking (2 parts)
**Parts:** 02-new-booking-p1.png, 02-new-booking-p2.png
**Journey:** <…>
```

## Reviewer agents

Dispatch one general-purpose subagent per source, in parallel. Do not analyse screens yourself.

| Source kind | Agent prompt | Lens defaults |
|---|---|---|
| Public site | `agents/marketing-reviewer.md` | Marketing effectiveness, Visual design, Conversion flow, Content strategy |
| Logged-in or local app, admin UI | `agents/ux-reviewer.md` | General UX, First-time experience, Upsell and monetization |

Prompt: paste the agent file, then tell the agent to read the brief, Read every PNG listed, and return annotations per the agent instructions. Tell the user once: "Dispatching review agents. No action needed until the notes are placed."

Agent returns `DONE | DONE_WITH_CONCERNS | BLOCKED`, a JSON array of screens with annotations grouped into sections, a summary, and a `manifest` with `screenshots_reviewed` and `screenshots_with_annotations`.

Validate: `screenshots_reviewed` equals the PNG count for that source; re-dispatch for any missing screens. Spot-check two annotations against the lens. On `BLOCKED`, Read the PNGs yourself to confirm they are readable, then re-dispatch with more context.

## Placing observations on the canvas

Default when the user chose observations. Follow the placement rules from `design-annotations` (note width, reposition before placing, note at `screen.x + screen.width + 50`).

1. **Note format.** If the user's file has a note component (search the design system for "note" or "annotation"), list its variants and use the one the user picks. Otherwise use the default note template from `design-annotations` (400px wide, auto height, vertical layout, named "Dev Note"). Rename the frame "Observation".
2. **Content.** One note per screen. Heading: the screen label. Body: one line per annotation, prefixed with its type in brackets: `[positive]`, `[observation]`, `[critical]`. For Impact and Opportunity depth append `I4 O5`. Keep the reviewer's wording.
3. **Reposition first.** Widen gaps between tiles in that row to `tile.width + 50 + noteWidth + 200`, move labels with their tiles, verify with `get_screenshot`, then place notes. Grow the sub-section and the parent.
4. **Verify.** `get_screenshot` the row. Notes must not overlap tiles or each other.

Alternative the user may prefer: sticky notes are widgets and cannot be created by the plugin API; if the user wants stickies, place text callouts and say so.

## HTML gallery (optional)

`shared/common-steps.md`, "Generate HTML Gallery", "Local Server & Gallery Verification", "Import to Figma". File `screenshots/gallery-<source-slug>.html`. Show the gallery screenshot and ask for approval before importing it to Figma. Kill the server in cleanup.

## Comparison (optional, 2+ sources)

After all reviewers return, dispatch one general-purpose subagent (`model: "sonnet"`) with `agents/marketing-comparator.md` or `agents/ux-comparator.md` pasted in, followed by: every source's validated annotation JSON, the brief paths, the lens text, the depth. Do not tell it to read the agent file; inline everything.

Output: dimensions chosen by the comparator, qualitative ratings (Poor, Fair, Good, Excellent) with justification, a verdict (overall, per dimension, top three differentiators). Place it as a text frame under the rows in the parent section, or build `screenshots/gallery-comparison.html` per `shared/common-steps.md`, "Comparison Gallery". Never invent ratings yourself.
