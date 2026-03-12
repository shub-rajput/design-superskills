# design-superskills

Claude Code plugin for design research — screenshot capture, annotated UX/marketing galleries, and Figma import.

## How it works

Tell Claude Code what you want to review — a WordPress plugin's admin UI, a competitor's marketing page, or a set of pricing pages to compare. It handles the rest.

The plugin launches a headless browser, navigates through pages you care about, and captures screenshots. Then it dispatches review agents that analyze each screenshot through lenses you choose (UX quality, first-time experience, monetization, marketing effectiveness, conversion flow, and more). Everything comes together in an annotated HTML gallery — screenshots grouped by section, with issue callouts, opportunity scores, and comparison tables when you're reviewing multiple subjects. If you use Figma, the gallery imports directly.

Two skills power this:

- **wp-plugin-research** — Screenshot and UX-review WordPress plugin admin UIs (local or remote)
- **website-research** — Screenshot and marketing-review any public website

---

## Installation

### Requirements

- **Claude Code** with plugin support
- **[agent-browser](https://github.com/vercel-labs/agent-browser)** — required for all screenshot capture

**For wp-plugin-research only:**
- Local WordPress site with WP-CLI, OR access credentials to a remote/staging site

**Optional:**
- **Figma MCP** — needed only if you want to import galleries into Figma (see [Figma Setup](#figma-setup))

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

> "Capture and review the marketing page for stripe.com"

Claude should automatically invoke the **website-research** skill.

---

## Updating

Run `/plugin`, find **design-superskills** under the **Installed** tab, and select **Update now**. Then restart Claude Code.

---

## The Basic Workflow

1. **Describe your intent** — "Review the WooCommerce plugin admin UI" or "Compare the pricing pages of Mailchimp, ConvertKit, and Beehiiv"
2. **Configure permissions** — One-time setup for bash command approvals (the skills run 40–50+ commands for browser automation)
3. **Screenshots captured** — Agent-browser navigates and captures PNGs, organized by subject
4. **Review agents dispatched** — Specialized subagents analyze each screenshot through your chosen lens
5. **Gallery generated** — Annotated HTML gallery with grouped sections, annotations, and scores
6. **Comparison table** (multi-subject only) — Side-by-side ratings across dimensions with a verdict
7. **Figma import** (optional) — Gallery pushed to Figma via MCP

## What's Inside

```
design-superskills/
├── skills/
│   ├── wp-plugin-research/    # WP plugin screenshot capture + UX review
│   └── website-research/      # Public website screenshot capture + marketing review
├── agents/
│   ├── ux-reviewer.md         # UX analysis of WP plugin admin screenshots
│   ├── ux-comparator.md       # Side-by-side plugin comparison
│   ├── marketing-reviewer.md  # Marketing/design analysis of public websites
│   └── marketing-comparator.md# Side-by-side website comparison
├── shared/
│   └── common-steps.md        # Shared steps: permissions, gallery, Figma, troubleshooting
└── templates/
    └── gallery.html           # Figma-compatible HTML gallery template
```

## What You Get

Each run produces:

- **PNG screenshots** organized by subject in `screenshots/`
- **Annotated HTML gallery** (`screenshots/gallery.html`) with:
  - Screenshots grouped by section (Onboarding, Settings, Core Feature, etc.)
  - UX or marketing annotations per screenshot (issues, opportunities, positives)
  - Impact & Opportunity scores
  - Comparison table when reviewing multiple subjects
- **Figma-ready import** via the HTML-to-design capture workflow

## Usage

Both skills are invoked by describing your intent in natural language. Claude Code detects the right skill automatically.

**WP plugin research:**
> "Review the WooCommerce plugin admin UI on my local site"
> "Compare the onboarding flows of three form plugins"

**Website research:**
> "Capture and review the marketing page for wpforms.com"
> "Compare the pricing pages of the top 3 email marketing tools"

## Review Objectives

Both skills support multiple review lenses:

**wp-plugin-research:**
- General UX
- First-Time User Experience
- Upsell & Monetization
- Custom (you describe the focus)

**website-research:**
- Marketing Effectiveness
- Visual Design
- Conversion Flow
- Content Strategy
- Custom

---

## Figma Setup

Only needed if you want to import galleries into Figma.

The skill requires the **remote Figma MCP server** — not the built-in Claude AI Figma integration. The remote MCP provides `generate_figma_design`, which handles the HTML-to-Figma capture workflow.

```bash
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Restart Claude Code after adding. When you reach the Figma import step during a skill run, Claude will use this tool automatically if it's available.

---

## Permissions

The skills run a large number of bash commands. On first use, Claude will ask how you want to handle permissions:

1. **Add to settings (recommended)** — Claude writes the required permissions to `.claude/settings.json` in your project. Restart Claude Code and re-invoke.
2. **Bypass mode** — Restart with `claude --dangerously-skip-permissions` and re-invoke.
3. **Already configured** — Proceed immediately.
4. **Manual approvals** — Approve each command individually (slow, but always works).

---

## License

MIT — [Shubhang Haresh Rajput](https://github.com/shub-rajput)
