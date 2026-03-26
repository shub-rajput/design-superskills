---
name: design-annotations
description: Use when adding, repositioning, or improving dev note components next to Figma design screens. Triggers include requests to add dev notes, place annotations, improve dev note copy, or update existing notes.
---

# Design Annotations

Add, reposition, or improve dev note components next to design screens in Figma. Works with design system components or a default note template. Chains from design-organize but also works standalone.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification.

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Ask preferences: which screens, format, content |
| **2** | Read container, classify children, find existing labels |
| **3** | Version safety |
| **4** | Determine note width → reposition screens/labels → place notes |
| **5** | Validate and present result |

## Step 0: Prerequisites

1. **Figma MCP server** — check if `mcp__figma__use_figma` tool is available. If not, tell the user to install it and restart.

2. **figma-use skill** — load `figma:figma-use` via the Skill tool before any `use_figma` call.

3. **Figma Section gotchas** — these are critical and cause silent failures:
   - **Page discovery:** `getNodeById()` works cross-page — it will find nodes on ANY loaded page, giving false positives. Use `figma.currentPage.findOne(n => n.id === "<nodeId>")` instead, which only returns nodes that actually live on the current page.
   - **Page-level TEXT:** Figma stores TEXT nodes placed inside SECTIONs as page-level children — they won't appear in `section.children`. Scan `figma.currentPage.children` for TEXT nodes whose `absoluteBoundingBox` falls within the section bounds. These are existing labels. Their x/y are canvas-absolute — use `section.absoluteBoundingBox` to convert.
   - **Overlapping children:** SECTION nodes may silently discard children that overlap existing frames between script executions. Position new nodes to avoid overlaps.
   - **Stop on repeated failure:** If the same operation fails twice, STOP and read back children before retrying.

## Step 1: Ask Preferences

Extract `fileKey` and `nodeId` from the user's Figma URL (convert `-` to `:` in nodeId).

**Detect intent** from the message — "add dev notes" vs "improve copy" vs ambiguous. Then **always confirm preferences** before proceeding (skip only what the user already specified):

> **Which screens get dev notes?**
> - A) All screens
> - B) Let me pick (I'll list them)
>
> **Format:**
> - A) Use a design system component (I'll search for it)
> - B) Use a default note template
>
> **Content:**
> - A) Pre-fill with AI-generated descriptions
> - B) Leave empty for manual editing

For "improve copy" intent, skip format/screen questions — go straight to Step 2 → Path C.

## Step 2: Read Container and Classify Children

Use a single `use_figma` call to find the correct page and classify all children:

1. **Page discovery:** Iterate all pages, switch to each, use `figma.currentPage.findOne(n => n.id === "<nodeId>")` to find the page that owns the node. Do NOT use `getNodeById()` — it returns nodes cross-page. Mention which page you found (e.g., "Working on page **[page name]**") so the user can catch wrong-page issues early.

2. **Classify section children:** screens (everything visible that isn't a label or note), labels (`TEXT` nodes), notes (`INSTANCE` ≤ 450px or `FRAME` named "Dev Note" ≤ 450px).

3. **Scan page-level TEXT:** Check `figma.currentPage.children` for TEXT nodes within the section's `absoluteBoundingBox`. Flag these as `pageLevel: true` (canvas-absolute coords).

4. **Validation:** If design-organize was used (expect labels) but 0 labels found — you're on the wrong page. Re-run discovery.

5. **If user chose "let me pick":** List screens with names and dimensions for selection.

Store one FRAME screen ID as `<childId>` for subsequent page-switch preambles.

## Step 3: Version Safety

Ask the user to save a named version in Figma before proceeding. Wait for confirmation.

## Step 4: Determine Width → Reposition → Place Notes

This is the core step. The order is critical — **reposition BEFORE placing notes** to prevent overlaps.

### 4a: Determine note width

- **Component path:** Search design system → import → **list all variants, ask user which one** (don't auto-pick default). Create ONE test instance, confirm dimensions. Record `noteWidth`.
- **Default template:** `noteWidth = 400px`.
- **Improve copy (Path C):** Skip to 4d.

### 4b: Reposition screens and labels

Widen gaps between screens to fit notes. For each screen left-to-right:
- Screens WITH notes: gap = `screen.width + 50 (noteGap) + noteWidth + 200 (nextScreenGap)`
- Screens WITHOUT notes: gap = `screen.width + 200 (standard gap)`

Move each screen's label to follow it. **Page-level labels** need canvas-absolute coordinates: `sectionAbsBounds.x + screenRelativeX`.

Verify with `get_screenshot` that gaps are visible.

### 4c: Place notes

For each selected screen, place a note at `screen.x + screen.width + 50`, `screen.y`.

**Component notes:** Import chosen variant, `createInstance()` per screen, append to container.

**Default template notes:** Create template frame (400px wide, auto-height, vertical layout, "Dev Note" name, Inter fonts, warm fill `{1, 0.98, 0.94}`), clone per screen, remove template. **Must run in a single `use_figma` call** (template reference doesn't persist).

Verify with `get_screenshot`.

### 4d: Improve existing copy (Path C)

1. Read all existing notes via `use_figma` — walk each note's children to extract text nodes with their IDs and content
2. Match notes to screens by x-proximity (note.x near screen.x + screen.width)
3. Screenshot each screen for visual context
4. Generate improved copy — focus on what devs need: component behavior, state, data sources, interactions
5. Present suggestions in a table for confirmation:

> | Screen | Current | Suggested |
> |--------|---------|-----------|
> | Dashboard | "Add notes here..." | "Main dashboard. Stats row: real-time metrics..." |

6. Bulk-update confirmed notes in one `use_figma` call — load each text node's exact font before changing `.characters`

## Step 5: Validate and Present

Screenshot the section. Verify notes are positioned correctly, not overlapping, readable.

> **Done.** Added/updated X dev notes across Y screens.
>
> Want to adjust anything?
>
> **Next step:** Want me to optimize these screens for MCP? (I can invoke mcp-optimize)
