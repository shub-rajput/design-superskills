---
name: design-research
description: Use when a designer wants screenshots of a website, web app, admin UI, or local app flow captured and placed into a Figma refs section as labelled rows, optionally with review observations next to the screens or a comparison across sources. Triggers include "screenshots into Figma", "visual references", "reference this flow", "capture these competitors", "add your observations next to them", "compare these three", or a Figma refs section link plus a request to add more screens.
---

# Design Research

Capture a flow with agent-browser and place the screenshots into a Figma refs section, one labelled row per source, matching whatever row already exists. Optionally layer observations next to the screens (review agents) and a comparison across sources. Ends by handing off to `research-synthesis`.

Sources can be public websites, logged-in web apps (a WordPress admin is one kind of logged-in app here), or apps running locally. This skill never modifies the target site: no CLI, no plugin or data changes. WordPress-specific setup (WP-CLI, temp users, plugin hygiene) lives in the separate `wp-plugin-research` skill, which calls back into this one for capture and placement.

**REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call.

**Supporting files:** `capture.md` (login, capture, Figma placement recipe), `review-layer.md` (review brief, agents, placing observations, gallery, comparison). `shared/common-steps.md` holds permissions, shell rules, capture strategy, gallery and troubleshooting.

## Quick Reference

| Step | What | Key decision |
|------|------|-------------|
| **0** | Permissions and prerequisites | Auto mode; agent-browser; Figma MCP |
| **1** | Gather all input in one question | Sources, flow, refs section, layers |
| **2** | Read the target section | Copy an existing row's layout if present |
| **3** | Login per source (if needed) | Generic form login; hand SSO or 2FA back |
| **4** | Capture and verify | One folder per source, flow order, journey notes |
| **5** | Place rows in Figma | `upload_assets`, verify IMAGE fills |
| **6** | Review layer (optional) | Agents, then observations on the canvas or gallery |
| **7** | Comparison (optional, 2+ sources) | Comparator agent |
| **8** | Verify, report, hand off | Section screenshot; point to `research-synthesis` |

## BEFORE YOU START: Create Tasks

Use TaskCreate for each step. Mark `in_progress` when starting and `completed` when done.

1. "Step 0: Permissions and prerequisites"
2. "Step 1: Gather input"
3. "Step 2: Read target section"
4. "Step 3: Login per source"
5. "Step 4: Capture and verify"
6. "Step 5: Place rows in Figma"
7. "Step 6: Review layer (if chosen)"
8. "Step 7: Comparison (if chosen)"
9. "Step 8: Verify, report, hand off"

## Step 0: Permissions and Prerequisites

Read `shared/common-steps.md`, "Permissions" and "No Shell Variables in Bash Commands". Recommend auto mode before the command-heavy steps.

| Check | How | Fix |
|-------|-----|-----|
| agent-browser | `which agent-browser` | `npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser` |
| Figma MCP (required) | `mcp__figma__use_figma` and `mcp__figma__upload_assets` present | `shared/common-steps.md`, "Figma MCP Setup" |
| figma-use skill | loaded via the Skill tool | load it now |

Figma is the default output, so the Figma MCP is required. If the user only wants PNGs on disk, stop after Step 4 and say so.

## Step 1: Gather Input (Single Interaction)

One AskUserQuestion. The user answers everything and walks away.

**Sources.** URLs, or a discovery query ("booking apps with an admin calendar") resolved with WebSearch into a numbered list the user picks from. For each source: is it public, needs a login (credentials, or the user will log in when asked), or runs locally?

**Flow.** Which screens, in order. Options: "homepage plus key pages", "this admin flow: <steps>", "let me explore and propose a list" (navigate, build the list, show it, then capture).

**Refs section.** The Figma URL of the section to place rows in, or the page to create one on. A `node-id=A-B` in the URL is node `A:B`.

**Layers.** Multi-select:
- **Refs only.** Screens on the canvas, nothing else. Default.
- **Observations next to the screens.** A review agent reads the screens (marketing lens for public sites, app-UX lens for admin UIs) and the observations are placed on the canvas beside each screen. Ask for the lens (General UX, First-time experience, Marketing effectiveness, Conversion flow, Upsell and monetization, or a sentence of their own) and the depth (Light, or Impact and Opportunity scores).
- **HTML gallery.** The annotated gallery as well as, or instead of, canvas notes.
- **Comparison.** Only with 2+ sources: a comparator agent rates sources across dimensions with a verdict.

Print a plan summary (sources, flow, section, layers, estimated screens) and start. No further gates before writing to Figma; this flow is for unattended runs. The final message carries a section screenshot so the user can check and undo.

## Step 2: Read the Target Section

Follow `capture.md`, "Layout rule". If the parent section already holds a row, read it and copy its numbers (tile size, gap, padding, label font, fill). If empty, use the defaults. Name the page and the row matched in the final message.

## Step 3: Login per Source

Follow `capture.md`, "Login". Generic form login only: open the login URL, fill the fields found with `snapshot -i`, submit, verify the landing page. SSO, 2FA, captcha, or a magic link: hand back to the user with one AskUserQuestion ("Log in in the agent-browser window, then tell me to continue"). Re-login before each source; sessions expire.

## Step 4: Capture and Verify

Follow `capture.md`, "Capture". One folder per source `screenshots/<source-slug>/`, files `NN-description.png` in flow order, chunked `-p1`, `-p2` for pages taller than one viewport. Read every PNG after capture. Drop near-duplicates. Keep a journey note per screen (one to three factual sentences) even in refs-only mode; the review layer and `research-synthesis` both use them.

## Step 5: Place Rows in Figma

Follow `capture.md`, "Place rows in Figma". One sub-section per source inside the parent, tiles as rectangles with IMAGE fills, labels above tiles from the filenames, uploaded with `upload_assets` in filename order. Grow the parent. Verify the IMAGE fill count equals the tile count before moving to the next source.

## Step 6: Review Layer (optional)

Follow `review-layer.md`. Write a review brief per source, dispatch `agents/marketing-reviewer.md` (public sites) or `agents/ux-reviewer.md` (apps and admin UIs) as general-purpose subagents, validate the manifest counts, then place the observations:

- **On the canvas** (default when chosen): one note per screen beside its tile, using a design-system note component if the user has one or the default note template from `design-annotations`. Each observation is one line with its type (positive, observation, critical) and, for Impact and Opportunity depth, its scores.
- **HTML gallery**: `shared/common-steps.md`, "Generate HTML Gallery" and "Local Server & Gallery Verification". Ask for approval before importing the gallery to Figma.

## Step 7: Comparison (optional)

Only with 2+ sources and the layer chosen. Follow `review-layer.md`, "Comparison". Place the comparison table as a text frame under the rows, or as the comparison gallery.

## Step 8: Verify, Report, Hand Off

`get_screenshot` of the parent section. Final message: the page and row matched, sources and tile counts, where observations landed, the section screenshot, and:

> Next step: when the observations are in place, `research-synthesis` turns them into a problem statement, objectives, shared patterns and directions.

Cleanup: kill any local gallery server. Nothing else; the targets were not modified.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Building an HTML gallery to import refs | `upload_assets` places PNGs directly. The gallery is a review-layer output, not an import step. |
| Applying default layout when a row exists | Read the row first. The user's arrangement wins. |
| Running a CLI against the target site | Out of scope here. WordPress setup belongs to `wp-plugin-research`. |
| Retrying SSO or 2FA by script | Hand back to the user once, wait, continue. |
| `nodeIds` in a different order than the files | Both arrays in filename order or images land on the wrong tiles. |
| Letting upload URLs expire | Request slots only when files are ready; POST within 10 minutes. |
| Trusting HTTP 200 alone | Re-read the tiles; every fill must be `IMAGE`. |
| Placing notes over screens | Reposition per `design-annotations` (note at `screen.x + screen.width + 50`) before placing. |
| Analysing screens yourself | Dispatch the reviewer agent. The main agent captures and places. |
| Labels sized for full screens (70pt) | Tiles are compact; 20pt reads. Match the existing row. |
