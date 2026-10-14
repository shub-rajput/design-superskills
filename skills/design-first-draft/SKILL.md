---
name: design-first-draft
description: 'Use when a research synthesis or a project brief exists and the user wants first-draft screens designed for each direction, in Figma or in code, using their design system or a chosen visual style. Triggers include "design a first draft", "build first passes for these directions", "make v1 to v4 in Figma", "turn the objectives and directions into screens", "draft the directions from my synthesis", "here is the brief, design some options", or a synthesis link plus a Figma section link.'
---

# Design First Draft

Turn a research synthesis (or a project brief, via a short interview) into first-draft screens: one draft per direction, built with the user's design system when one exists or with a visual style agreed up front when it does not, critiqued by the orchestrator against fixed criteria, and closed with a QA sweep. This is the follow-up to `research-synthesis`.

The orchestrator (you) owns the brief, the critique and the summary. Builders (subagents, or you when building inline) own one direction each and nothing else. Nobody ranks the directions; the user compares and decides.

**REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call (yours or a builder's).

**Supporting files:** `design-system-discovery.md` (what to probe in Figma and code, findings table), `visual-directions.md` (style proposals and draft tokens when there is no design system), `brief-template.md` (the brief every builder reads), `critique-checklist.md` (criteria, round shape, QA sweep, summary shape), `figma-gotchas.md` (paste into briefs), `code-mode.md` (HTML drafts, optional capture into Figma).

## Quick Reference

| Step | What | Key decision |
|------|------|-------------|
| **0** | Prerequisites | Figma MCP; figma-use |
| **1** | Get the input | Synthesis, or brief plus interview |
| **2** | Design-system discovery | You look first, in Figma and code |
| **3** | One input question | Approve the brief (brief path); confirm DS or pick a style; directions, mode, section, subagents or inline |
| **4** | Visual direction (no DS only) | Shared style, or the synthesis's per-direction lines |
| **5** | Parity check (optional) | Only when redesigning an existing screen |
| **6** | Brief and sections | Distinctness rule; one sample record |
| **7** | Build | Subagents two at a time, or inline one at a time |
| **8** | Critique rounds | You screenshot and judge; one numbered message per round |
| **9** | QA sweep and summary | No ranking, no recommendation |

## BEFORE YOU START: Create Tasks

Use the task tool if one is available (TaskCreate or TodoWrite): one task per step, marked `in_progress` when starting and `completed` when done. Without one, track the steps in your replies.

1. "Step 0: Prerequisites"
2. "Step 1: Get the input"
3. "Step 2: Design-system discovery"
4. "Step 3: Input question"
5. "Step 4: Visual direction (if no design system)"
6. "Step 5: Parity check (if redesigning)"
7. "Step 6: Brief and sections"
8. "Step 7: Build"
9. "Step 8: Critique rounds"
10. "Step 9: QA sweep and summary"

## Step 0: Prerequisites

| Check | How | If missing |
|---|---|---|
| Figma MCP (remote) | `mcp__figma__use_figma`, `get_screenshot`, `get_metadata` load via ToolSearch | `shared/common-steps.md`, "Figma MCP Setup". Code mode without Figma capture can run without it; say so |
| Figma reachable | A trivial read-only `use_figma` call on the target file | **"Looks like you don't have edit access to this file"** (on reads too) or **"Cannot write to node property in a read-only file or mode"** (on writes): the MCP session usually lost authorization. Ask the user to run `/mcp` and re-authenticate, then retry. Do not diagnose seats or sharing first. Until it is fixed, Step 2 covers the codebase only and says Figma was unreachable |
| figma-use skill | Loaded via the Skill tool | Load it now |

## Step 1: Get the Input

Accept whichever the user has:

| Input | Action |
|---|---|
| **Research synthesis** (artifact link, `.html`, `.md`) | Read it fully. Extract the problem, objectives (primary first), the "Keep in view while designing" list, proposed scope, out-of-scope items, patterns to avoid, open decisions, direction cards verbatim (tag, name, "After" references, summary, open questions) and any **Visual direction** lines (per direction card, or one shared line under Scope). Go to Step 2. |
| **Project brief** (pasted text, doc, PRD, ticket) | Run the brief interview below. |
| **Only reference screens or notes on a Figma canvas** | Stop and point to `research-synthesis`; it is built for that input. |

### Brief interview (brief path only)

Read the brief first, and start Step 2 in parallel: discovery is read-only, and what it finds (an existing system, an earlier run's draft tokens) can change what is worth asking. Ask only what the brief does not answer. Ask one question per message, multiple choice where possible, only for gaps that block writing the brief; everything else waits for the Step 3 question. Pin down:

1. **Problem**: three to four sentences; the first names the core friction, the last names what is out of scope.
2. **Objectives**: two to four, the user's primary objective first.
3. **Scope**: what v1 covers, what is deferred, patterns to avoid.
4. **Directions**: two to four. If the user has none, propose three or four that differ in their core mechanism (navigation model, information order, entry point), each with a name, one-line mechanism and reference products. No ranking. The user edits and approves the list.
5. **Visual direction** (optional): only if the user raises look and feel, or Step 2 later finds no design system.
6. **Platform**: where the screens live (phone, desktop web, inside an existing app shell) and the frame width (390, 1440, the app's content width).
7. **Existing product**: whether this replaces a screen that exists today (feeds Step 5).

Write `<slug>-brief.md` (in the product repo's `research/` folder when the working directory is the product, otherwise in the scratchpad; print the path) as Markdown with the `research-synthesis` section headings that apply: Problem, Objectives, Scope (v1, deferred, avoid), Directions (each with name, references, summary, open questions), Open decisions (platform first), Visual direction (if any). Leave out the sections that need canvas notes (shared patterns, current state, note inventory). Show it. Approving the brief, including any directions you proposed, is the first question of Step 3. Once approved, a synthesis and a brief are treated the same.

## Step 2: Design-System Discovery

Read `design-system-discovery.md`. Probe before asking anything: the target Figma file (local components, variables, text styles, existing product screens), enabled libraries, the product's codebase (token files, theme or Tailwind config, component folders, Storybook, UI libraries in `package.json`), and brand assets (logo, brand colours, fonts named in the input). Scan the working directory only when it is the product's code, or a repo path the user named; otherwise skip the codebase and say so. All read-only. Produce the short findings table described there.

## Step 3: Gather Input (Single Interaction)

One AskUserQuestion with up to four questions. Ask only what the request and the input did not answer; restate the rest in the plan.

- **Brief approval (brief path only).** "Build from this brief and these directions, in this order?" Options: approve / edit the directions or order / edit the brief. This replaces a separate approval round and the directions question below, so the total stays at four.
- **Design system or style.** If Step 2 found one: "I found `<name>` (N components, M colour variables, fonts `<fonts>`). Build with it?" Options: use it / use a different one (name or link) / ignore it and pick a style. If nothing was found: "No design system found in the file or the codebase. Is there a specific style you want me to try?" Options: propose two or three styles / match a reference (URL, Figma frame, screenshot) / neutral wireframe grade / I will describe it. If the synthesis carries visual direction lines (shared or per direction), offer those first.
- **Directions and priority (synthesis path).** Which to build, in what order. Priority decides dispatch order, not effort.
- **Mode, target and platform.** Figma (default; the target section URL) or Code first (`code-mode.md`; the output folder), with optional capture into Figma. Platform and frame width, unless the input already states them.
- **Execution.** Subagents (recommended: one builder per direction, two running at a time) or inline (you build one direction at a time; cheaper, slower). State the models and let the user pick: Opus builders (most polish, roughly 6 to 9 minutes and 110k to 130k tokens per direction) or Sonnet builders (draft grade, roughly 2 to 4 minutes and 80k to 95k tokens per direction). Sonnet for mechanical steps either way.

Fold in only when needed: the existing screen's repo path or frame link (Step 5), and sample content (the user's, or you propose one realistic record).

**Open decisions that change the screens** (full page or inside the app, login or guest, a step or a setting): when a direction's own text answers one, follow it; otherwise pick the answer the input leans toward and list it in the plan as an assumption. Directions may answer the same decision differently; that is often what makes them distinct.

Print the plan (directions in order, DS or style, mode, target, platform and frame width, sample content, assumed answers to open decisions, execution and models, estimated frames). The user can correct any line. If Step 4 applies, it is the only remaining gate before building; otherwise start.

**Figma:** once the plan stands, use the section the user linked, or create the empty parent section now in a clear spot on the target page (name it after the flow), so the style options and draft kit in Step 4 have something to sit next to. Style it as in Step 6.

## Step 4: Visual Direction (Only When There Is No Design System)

Skip when the user confirmed a design system or chose neutral wireframe grade. Otherwise read `visual-directions.md`:

- **Synthesis has per-direction visual lines and the user accepted them:** each direction keeps its own line. This is the only case where directions differ visually.
- **Synthesis has one shared visual line and the user accepted it:** turn it into one style card and confirm it.
- **Otherwise:** propose two or three shared styles as swatch cards, the user picks one, and every direction uses it. Directions then differ by layout, not by paint.
- **Match a reference:** extract palette, type, density and radius from it into one style card and confirm it.

Turn the chosen style into draft tokens (a local "Draft tokens · <Style name>" variable collection plus `Draft/<Style name>/*` text styles in Figma, or `first-drafts/tokens.css` in code), then build the small shared draft kit (buttons, inputs, card, nav item, badge, notice) outside every direction's section. Builders bind to the tokens, use kit instances, and never type raw hex.

## Step 5: Parity Check (Optional)

Run only when the directions redesign a screen that exists today and its code (repo path) or current screens (Figma frames) are available. Otherwise skip and say so in the summary.

1. One read-only inventory pass (a subagent with `model: "opus"`, or inline): every field and control with type, default, validation, conditional visibility and gating (free, paid tier, add-on); which features coexist and which are mutually exclusive; post-save behaviour. Write `<scratch>/inventory.md`; mark unverified items.
2. Derive `<scratch>/parity-checklist.md`: one row per feature, "what the product does today" and "what the design must show". Rules: essentials stay prominent; everything else gets a visible, non-blocking home; gated items show the product's badge or upsell pattern; nothing is dropped.
3. Look explicitly for: a multi-select drawn as a single dropdown; coexisting features drawn as exclusive modes (or the reverse); a free feature drawn as paid (or the reverse); options the product does not have.

## Step 6: Brief and Sections

Write `<scratch>/direction-brief.md` from `brief-template.md`: objectives with their on-screen meaning, out of scope, the parity rule (if Step 5 ran), the directions verbatim with the distinctness rule, one sample record, target facts, the component, style and token tables (from the design system or the draft tokens), build rules, report format, and the relevant lines of `figma-gotchas.md`.

**Figma:** one `use_figma` call creates one sub-section per direction inside the parent section, named by content and number ("Direction v2 · Side rail checklist"). Record the ids in the brief. Builders never write outside their own section.

- **Look.** Match the file's existing section style when it has one (fill, stroke, title font and colour). Otherwise give the parent a light neutral fill and each sub-section a white fill with a 1px light grey stroke, so directions read as cards. Figma's default section fill is dark grey: never leave it, and pick title and label colours that contrast with whichever fill is used. Record the fills and label colour in the brief.
- **Size.** Width = frames x frame width + (frames - 1) x 80 + 200; height = tallest expected frame + 300. Builders tighten their own sub-section; the orchestrator resizes the parent in Step 9.
- **Labels.** Figma shows frame names above frames inside a section, but exports and screenshots do not. Add TEXT labels above frames only when the file's existing frames have them; otherwise leave them out.

**Code:** one folder per direction, `first-drafts/<direction-slug>/`.

Frames per direction: three to six. Required: a start (empty) state, a filled state, the state that shows this direction's mechanism, and the finishing state (publish, confirm, share, done). Each objective that needs its own state (cancel, waitlist, error) adds a frame, up to six. A direction may rename the required states when its mechanism changes them (a remembered identity replaces the filled form; first visit and returning visit replace start). One moment per frame: a frame never shows a call to action next to the result of taking it.

## Step 7: Build

**Subagents (default).** One `general-purpose` agent per direction, two running at a time in priority order (when one reports, start the next and critique the one that reported). Always set `model` explicitly; an unset model inherits the parent's, which may be the most expensive. Separate sections isolate parallel writes to one file.

Each prompt: read the brief in full, load `figma:figma-use` and the Figma tool schemas (or read `code-mode.md`), the assigned section id or folder, the frames to build, the distinctness rule restated for this direction, "screenshot after each frame and fix before continuing", "never edit library components", "return node ids or file paths", and the report format. Builders report; they do not declare themselves done.

**Inline.** Build one direction at a time from the same brief, same frames, same report, then move to the next. Re-read the distinctness rule before each direction.

## Step 8: Critique Rounds

Read `critique-checklist.md`. For every report, screenshot every frame yourself and judge against the five criteria (objective fit, direction fidelity and distinctness, design-system or visual-direction adherence, parity when Step 5 ran, craft). Send one consolidated numbered message per direction with the fix for each item. Resume the same agent for the revision; it knows its nodes. Inline, apply the same message to yourself. Repeat until the criteria pass; two rounds is typical.

Mid-course feedback from the user that touches more than one direction becomes a dated Addendum at the end of the brief first, then a pointer message to each affected builder.

Resilience: an agent stopped by a rate limit is resumed with "continue where you stopped, do not redo completed work". An agent hitting the read-only error stops retrying and writes a pending list (frame id, node ids, exact change) to scratch; apply it after the user re-authenticates.

## Step 9: QA Sweep and Summary

Run the QA sweep from `critique-checklist.md` on each section or folder. Fix one-line stragglers yourself. Tighten each Figma sub-section to content plus 100px, then resize the parent section to its sub-sections plus 100px, and take one overview screenshot of the parent.

Final message in the shape given in `critique-checklist.md`: directions and frames, design system or draft tokens used, parity items applied (or "parity check skipped"), QA results, design-system gaps, open questions. No ranking, no recommendation. If the user asks which direction is best, answer in chat, never in the deliverable.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Asking the user which design system to use before looking | Step 2 first. Report what was found and ask for confirmation. |
| Inventing a visual style when a design system exists | Use the system. Styles are proposed only when nothing was found or the user declined it. |
| A different visual style per direction by default | One shared style, so directions compare by layout. Per-direction styles only when the synthesis defines them and the user accepts. |
| Building from an unapproved interview brief | Brief approval is the first question of Step 3; nothing is built before it. |
| Leaving sections in Figma's default dark grey | Match the file's section style, or light parent and white sub-sections (Step 6). |
| Launching builders without `model` | They inherit the parent model. Set it explicitly and state it in the plan. |
| Letting builders self-certify | The orchestrator screenshots and critiques. Builders report. |
| Building inside the user's stub frames or one shared area | One sub-section or folder per direction; builders never leave it. |
| Directions that share a navigation model or differ only in copy | Distinctness rule in the brief and in the critique. |
| Different sample content per direction | One record, identical everywhere. |
| Raw hex where a token exists (real or draft) | Bind to the variable or the CSS custom property. |
| Editing or detaching library components | Instances only. A missing component is drawn with tokens and listed as a gap. |
| Ranking directions or naming a winner | Facts per criterion only. |
| Em-dashes in copy or messages | Commas, full stops, colons. |

## Example Run

A rental marketplace's "create a new listing" flow. The synthesis listed four directions (guided wizard, one long sectioned form, current editor with fixes, preview-first editing). Discovery found a Figma library with 40 components and colour variables, so no style step. The parity pass on the current screen found that amenities are multi-select and that instant booking and request-to-book can both be on for one listing; both corrections went into the brief. Builders ran as two pairs, two critique rounds each, one Addendum when the user narrowed the fourth direction. Sixteen frames in four sections, three design-system gaps listed (no text property on the input label, the radio label, the notice message).

A second run from a project brief only: the interview pinned down the problem and three objectives, the user had no directions, so three were proposed and approved. No design system in the file or the codebase; the user picked one of three style cards, draft tokens and a draft kit were built, and every direction used them.

## Chaining

- **Before:** `research-synthesis` (directions from canvas notes). Without a synthesis, the brief interview in Step 1 produces an equivalent input.
- **After:** `design-organize` to restructure the sections, `design-annotations` for dev notes on the chosen direction, `dev-handoff` once a direction is picked and refined.
