---
name: research-synthesis
description: Use when a Figma section holds reference screenshots (competitors, current product, other references) with or without notes and the user wants them turned into one readable document: problem statement, objectives, shared patterns, current state, scope, directions. Triggers include "actionable pointers", "synthesize my research", "problem statement and objectives", "one place to look at all these notes", "turn my stickies into a doc", or a refs section link plus a request for directions.
---

# Research Synthesis

Turn a canvas of reference screenshots and observations into one document a manager can read in ten minutes: problem, objectives, shared patterns, current state, scope, directions, feature ideas, and a collapsed inventory of every source note. This is the follow-up to `design-research`: capture puts screens on the canvas, this skill turns what was noticed about them into a synthesis.

The document is the user's audit, written in their voice for their audience. Claude organises and compresses. Claude does not rank, recommend, or decide.

**REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call.

## Quick Reference

| Step | What | Key decision |
|------|------|-------------|
| **0** | Prerequisites | Figma MCP available |
| **1** | Inventory the section | Screens, sub-sections, notes of every kind |
| **2** | Gate on observations | Use existing notes, add more, or gather them |
| **3** | Gate on colour legend | Only if notes are colour coded |
| **4** | Read every note | Widgets need screenshots, not the plugin API |
| **5** | Map notes to screens | Nearest tile by x within the same sub-section |
| **6** | Draft the synthesis | One data structure, two outputs |
| **7** | Review pass with the user | Voice, facts, priorities |
| **8** | Publish | Artifact when available, files always |

## BEFORE YOU START: Create Tasks

Use TaskCreate for each step. Mark `in_progress` when starting and `completed` when done.

1. "Step 0: Prerequisites"
2. "Step 1: Inventory the section"
3. "Step 2: Gate on observations"
4. "Step 3: Gate on colour legend"
5. "Step 4: Read every note"
6. "Step 5: Map notes to screens"
7. "Step 6: Draft the synthesis"
8. "Step 7: Review pass"
9. "Step 8: Publish"

## Step 0: Prerequisites

1. **Figma MCP** (remote server): `mcp__figma__get_metadata`, `mcp__figma__use_figma`, `mcp__figma__get_screenshot` must be available. If not, see `shared/common-steps.md`, "Figma MCP Setup".
2. **figma-use skill** loaded before any `use_figma` call.
3. Extract `fileKey` and `nodeId` from the URL. `node-id=A-B` is node `A:B`.

## Step 1: Inventory the Section

One read-only `use_figma` call. Find the page that owns the node, switch to it, then collect:

- **Sub-sections** (one per source: a competitor, the current product, other references) with ids and bounds.
- **Screens**: rectangles with an `IMAGE` fill, or frames, directly inside each sub-section, with their label text (the TEXT node above each tile).
- **Notes of every kind**:
  - `WIDGET` nodes named "Sticky note" (or any widget) with position and size.
  - Instances whose component name contains "note" or "annotation" (dev-note components).
  - Loose `TEXT` nodes longer than about 25 characters that are not tile labels.
  - Direction or idea stubs: sections or frames whose names look like `v1`, `Option A`, `Direction`.
- **Comments**: if the file has comments on the section, note their count (read via `get_design_context` only if the user asks for them; they are optional input).

`get_metadata` on a large section can exceed the output limit. When it does, read the saved file in chunks or use `use_figma` with `findAllWithCriteria` and return only ids, names, types and bounds.

Report the inventory in one short block: N sources, N screens, N notes by kind, N direction stubs. Name the page.

## Step 2: Gate on Observations

Behaviour depends on what Step 1 found.

**Notes found.** Ask one question:

> I found N notes across M sources (K stickies, J dev notes, L text notes). Use these as the observations, or do you want to add more before I read them?
> - Use them as they are
> - I will add more on the canvas and come back
> - Use them, and I will add a few in chat now

**No notes found.** Ask one question with three paths:

> The section has N screens but no observations yet. How do you want to gather them?
> - I will add notes on the canvas and come back
> - I will dictate observations in chat, source by source
> - Review each screen yourself and draft observations for my approval before synthesising

If the user picks the third path: screenshot each tile, write two to four observations per screen as plain factual statements (what is on the screen, what is required, what is hidden, how many steps), present them grouped by source in a table, and wait for approval. Approved observations become the note set. Never move to Step 6 on unapproved drafts.

Stop after asking. Do not read notes or draft anything until the user answers.

## Step 3: Gate on Colour Legend

Only when stickies exist and they use more than one fill colour.

Ask once:

> Your stickies use these colours: [swatch list with counts]. What does each mean? (For example: observation, problem, strong idea, idea to explore.)

If the user already stated the legend in their request, record it and do not ask again. If there is one colour, or the user says colours carry no meaning, treat every note as an observation and infer sentiment from wording. Never assign a legend without asking.

## Step 4: Read Every Note

**Stickies are widgets. The plugin API cannot read their text.** `widgetSyncedState` returns `{}`, `findAllWithCriteria` does not descend into them, inner node ids from `get_metadata` resolve to `null`, and `get_design_context` on a widget returns "node type not supported". Read them visually:

```javascript
// One use_figma call. Max 5 ids per call: only the first 5 inline images are returned.
const page = await figma.getNodeByIdAsync('<pageId>');
await figma.setCurrentPageAsync(page);
const ids = ['<widgetId1>','<widgetId2>','<widgetId3>','<widgetId4>','<widgetId5>'];
for (const id of ids) { const n = await figma.getNodeByIdAsync(id); await n.screenshot({ scale: 1.5 }); }
return { order: ids };   // images arrive in this order; map by index
```

- Fan the calls out: emit all batches in one message so they run in parallel.
- Transcribe each note verbatim, including typos. Fix nothing in the inventory. Record the fill colour from the image.
- Dev-note instances and loose TEXT nodes are readable through `characters`; read them in one call.
- Keep the transcript in a local data file (`research/<slug>-notes.json` or inline in the generator script). Every later step reads from it.

Verify the count: notes transcribed must equal notes inventoried. Report any note that could not be read.

## Step 5: Map Notes to Screens

A note belongs to the sub-section that contains it (or whose bounds contain its position if it sits at the parent level). Within that sub-section, the nearest tile by x position is its screen. Record `screen` as the tile's label text. When a note sits between two tiles, record both labels.

Close-up crops the user added next to a full screen count as screens too.

## Step 6: Draft the Synthesis

Build one data structure (notes, patterns, findings, scope, directions, ideas, questions, gaps) and generate both outputs from it: an HTML page and a Markdown copy. Re-runs after the user adds notes are then a data edit and a rebuild, not a rewrite. The output contract and voice rules are in `synthesis-template.md`. Read it before drafting.

Section order:

1. Problem (three to four sentences)
2. Objectives (two to four, the user's own priority first)
3. Shared patterns (table: pattern, who does it, current product today, neutral status)
4. Current state (one line per finding, each with a source chip)
5. Scope: proposed v1, patterns to avoid
6. Directions (one card per direction stub: summary from the user's text, source references, open questions, optional schematic wireframe)
7. Open decisions
8. Feature ideas, separate track (grouped; enhancements and new features, not flow work)
9. All notes (collapsed by default, grouped by source, verbatim text, screen label, deep link)
10. Coverage and gaps (sources without notes, duplicates, unreadable notes)

Every claim carries a chip that deep-links to the source note: `https://www.figma.com/design/<fileKey>/<fileName>?node-id=<A-B>`.

**Statuses for shared patterns.** Use only: `Not present`, `Present, weaker`, `Present`, `Open question`, `Deferred`. A pattern the current product has in some form is `Present, weaker`, never `Not present`.

**Directions.** Summarise each from the user's own stub text. List the open questions the stub raises. A schematic wireframe (rectangles only, drawn inline as SVG using the page's theme tokens) is optional and must be labelled schematic. No scores, no bars, no fit matrix, no recommendation, no ordering by preference.

**Claims about the current product.** Notes are the user's impressions and can be wrong. Where a note asserts something about the product's behaviour, phrase it as the note's observation, and flag it in the review pass if the screens contradict it.

## Step 7: Review Pass

Present the draft and ask for corrections in one message. Expect, and apply without argument, feedback of these kinds:

- **Voice**: less negative about the product, no second person, no Claude opinions.
- **Facts**: a note was wrong, a competitor does or does not do something, a status is too harsh.
- **Priorities**: which objective is primary, what is out of scope, what belongs on a separate track.
- **Order**: sections the audience cares about move up.

After each round, edit the data structure, rebuild both outputs, republish to the same URL. Keep a one-line changelog in the reply.

## Step 8: Publish

- Write `research/<slug>-research-board.html` and `.md` into the user's project (or the directory they name).
- If the Artifact tool is available, publish the HTML there and reuse the same file path on every republish so the URL stays stable. Load `artifact-design` before the first publish.
- Reply with the link, then a short list of what changed. No summary of the document itself; the document is the summary.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Calling `get_design_context` on a sticky widget | Unsupported node type. Screenshot the widget inside `use_figma`, five per call. |
| Requesting 10+ widget screenshots in one call | Only the first five inline images come back. Batch by five, fan out in parallel. |
| Inventing a colour legend | Ask once. Colours are personal conventions and differ per user. |
| Drafting before the observation gate | Stop after the question in Step 2. The user may want to add notes first. |
| Scoring or ranking directions | Directions are the user's options for their managers. Summarise, list open questions, stop. |
| "Everyone does X" | Count. Name who does it. Note who takes the same approach as the current product. |
| Marking a weaker version as `Not present` | If the product has any form of it, status is `Present, weaker`. |
| Second person in the document ("your note", "you asked") | Audit voice. "The note on <screen> states…" or drop the attribution. |
| Reasoning paragraphs explaining why a section exists | Delete them. Lists, tables, chips. The reader is skimming. |
| Recommending which direction to take | Out of scope. Even when asked "what do you think", answer in chat, not in the document. |
| Correcting a user's note silently | Keep the verbatim text in the inventory; add a bracketed correction after it once the user confirms. |
| Em-dashes anywhere in the output | Use commas, full stops or colons. |

## Chaining

- **Before:** `design-research` (screens on the canvas, optional observations next to them), `design-annotations` (if the user wants dev-note style observations placed next to screens instead of stickies).
- **After:** the directions section is the brief for design exploration; the feature ideas section is a backlog seed for the user's task tracker.
