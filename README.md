# design-superskills

Claude Code plugin for design research, Figma organization, and dev handoff — screenshots of any site or app flow placed into Figma as labelled reference rows, optional review observations and comparisons, research synthesis from canvas notes, Figma screen organization, dev annotations, and GitHub issue generation from Figma designs.

## How it works

Tell Claude Code what you want to reference or review — a competitor's onboarding, three booking apps' admin flows, a set of pricing pages. It launches a headless browser, walks the flow, captures screenshots, and places them into a Figma refs section as one labelled row per source, matching any row you already arranged by hand. If you ask for it, review agents read the screens and their observations land on the canvas next to each screen (or in an annotated HTML gallery), with a comparison table when there are several sources. When the notes are in place, a second skill turns them into a synthesis document.

Five skills power this:

- **design-research** — Capture any site, web app, or local app flow and place the screenshots into a Figma refs section as labelled rows. Optional layers: review observations next to the screens (marketing lens for public sites, UX lens for apps and admin UIs), an annotated HTML gallery, and a comparison across sources
- **research-synthesis** — The follow-up. Reads the observations on a refs section (sticky notes, dev notes, text notes, or observations gathered in chat) and turns them into one document: problem statement, objectives, shared patterns, current state, scope, directions, feature ideas, and a collapsed inventory linking back to every note
- **design-organize** — Organize scattered Figma screens into labeled layouts with optional sub-sections
- **design-annotations** — Add, reposition, or improve dev note components next to Figma screens
- **dev-handoff** — Turn Figma design sections into GitHub issues for developer handoff, with template-aware formatting

**WordPress plugin research** (WP-CLI, temporary admin user, plugin deactivation, first-run gates) is a separate skill, [wp-plugin-research](https://github.com/shub-rajput/wp-plugin-research-skill), that prepares the site and hands over to `design-research` for capture and Figma placement.

---

## Installation

### Requirements

- **Claude Code** with plugin support
- **[agent-browser](https://github.com/vercel-labs/agent-browser)** — required for all screenshot capture
- **Figma MCP** (remote server) — required for design-research, since Figma is its default output, and for the Figma skills (see [Figma Setup](#figma-setup))

### Step 1: Add the marketplace

```
/plugin marketplace add shub-rajput/design-superskills
```

### Step 2: Install the plugin

```
/plugin install design-superskills@design-superskills
```

### Step 3: Install agent-browser

If not already installed:

```bash
npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser
```

### Step 4: Verify

Restart Claude Code. On launch, the session-start hook checks for agent-browser and shows a warning if it's missing. Then try:

> "Put screenshots of stripe.com's pricing flow into my Figma refs section"

Claude should automatically invoke the **design-research** skill.

---

## Updating

**Auto-update (recommended):** Claude Code can automatically update the marketplace and installed plugins at session startup. Since this is a third-party marketplace, auto-update is **disabled by default** — to enable it, run `/plugin marketplaces`, select **design-superskills**, and choose **Enable auto-update**. When an update is applied, you'll be prompted to run `/reload-plugins`.

**Manual update:** Run `/plugin`, find **design-superskills** under the **Installed** tab, and select **Update now**. Then run `/reload-plugins` to load the new version.

---

## The Basic Workflow

1. **Describe your intent** — "Reference the onboarding of these three apps in my Figma refs section" or "Compare the pricing pages of Mailchimp, ConvertKit, and Beehiiv"
2. **Answer one question** — sources, flow, the Figma section, and which layers you want (refs only, observations, gallery, comparison)
3. **Screenshots captured** — agent-browser walks the flow and captures PNGs, one folder per source
4. **Rows placed in Figma** — one labelled row per source, matching any row already there
5. **Observations placed** (optional) — review agents read the screens; their notes land next to each screen or in an annotated gallery
6. **Comparison** (optional, multi-source) — side-by-side ratings with a verdict
7. **Synthesis** — `research-synthesis` turns the notes into a problem statement, objectives and directions

## What's Inside

```
design-superskills/
├── skills/
│   ├── design-research/       # Capture any flow → Figma refs rows (+ optional observations, gallery, comparison)
│   │   ├── SKILL.md
│   │   ├── capture.md         # Login, capture notes, Figma placement recipe
│   │   └── review-layer.md    # Review brief, agents, placing observations, comparison
│   ├── research-synthesis/    # Canvas notes → problem, objectives, patterns, directions doc
│   ├── design-organize/       # Figma screen organization + labeling
│   ├── design-annotations/    # Dev note placement + copy improvement
│   └── dev-handoff/           # Figma designs → GitHub issues for dev handoff
├── agents/
│   ├── ux-reviewer.md         # UX analysis of app and admin UI screenshots
│   ├── ux-comparator.md       # Side-by-side app comparison
│   ├── marketing-reviewer.md  # Marketing/design analysis of public websites
│   └── marketing-comparator.md# Side-by-side website comparison
├── CHANGELOG.md
├── hooks/                     # SessionStart hook for agent-browser check
├── shared/
│   └── common-steps.md        # Shared steps: permissions, capture strategy, gallery, troubleshooting
└── templates/
    └── gallery.html           # Figma-compatible HTML gallery template
```

## What You Get

Each design-research run produces:

- **PNG screenshots** organized by source in `screenshots/`, with journey notes per screen
- **Figma refs rows** — one sub-section per source with labelled tiles, inside your refs section
- **Observations next to the screens** (optional) — one note per screen with typed annotations, or an annotated HTML gallery with Impact and Opportunity scores
- **Comparison table** (optional) when reviewing several sources

Each research-synthesis run produces an HTML page and a Markdown copy of the synthesis, with a chip on every claim linking back to its source note.

## Usage

Skills are invoked by describing your intent in natural language.

**Design research:**
> "Put screenshots of these three admin flows into my Figma refs section, one row each"
> "Capture basecamp.com's pricing flow as references, and add your observations next to the screens"
> "Compare the onboarding of these two apps"

**Research synthesis:**
> "Turn the notes in this refs section into a problem statement, objectives and directions"
> "Synthesize my research into one doc I can send to my managers"

**Design organize:**
> "Organize this section https://figma.com/design/..."
> "Clean up and label these screens in Figma"

**Design annotations:**
> "Add dev notes to the first 3 screens in this section"
> "Improve the copy on existing dev notes"

**Dev handoff:**
> "Hand off this Figma section to dev as GitHub issues"
> "Turn these designs into tickets for the frontend team"

## Review Lenses

When you choose the observations layer in design-research:

**Apps and admin UIs (ux-reviewer):**
- General UX
- First-Time User Experience
- Upsell & Monetization
- Custom (you describe the focus)

**Public websites (marketing-reviewer):**
- Marketing Effectiveness
- Visual Design
- Conversion Flow
- Content Strategy
- Custom

**research-synthesis** takes no lens. It works from the observations already on the canvas (or gathered in chat) and writes in an audit voice: it summarises, it does not rank directions or recommend one.

---

## Figma Setup

Required for **design-research**, **research-synthesis**, **design-organize**, **design-annotations**, and **dev-handoff**.

These skills require the **remote Figma MCP server** — not the built-in Claude AI Figma integration.

```bash
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Restart Claude Code after adding. design-research places screenshots with `upload_assets` and `use_figma`; the optional gallery import uses `generate_figma_design`.

**Optional for dev-handoff:** Set `FIGMA_TOKEN` in your environment to enable frame PNG export via the Figma REST API. Without it, dev-handoff still works and falls back to Figma links in GitHub issues.

---

## Permissions

The research skills run a large number of bash commands. On first use, Claude will ask how you want to handle permissions:

1. **Add to settings (recommended)** — Claude writes the required permissions to `.claude/settings.json` in your project. Restart Claude Code and re-invoke.
2. **Bypass mode** — Restart with `claude --dangerously-skip-permissions` and re-invoke.
3. **Already configured** — Proceed immediately.
4. **Manual approvals** — Approve each command individually (slow, but always works).

---

## License

MIT — [Shubhang Haresh Rajput](https://github.com/shub-rajput)
