# design-superskills

Claude Code plugin for design research — screenshot capture, annotated UX/marketing galleries, and Figma import.

Two skills:
- **wp-plugin-research** — Screenshot and UX-review WordPress plugin admin UIs (local or remote)
- **website-research** — Screenshot and marketing-review any public website

Both skills generate annotated HTML galleries with grouped sections, UX/marketing annotations, and optional comparison tables across multiple subjects. Galleries can be imported directly into Figma.

---

## Requirements

- **Claude Code** with plugin support
- **[agent-browser](https://github.com/vercel-labs/agent-browser)** — required for all screenshot capture

**For wp-plugin-research only:**
- Local WordPress site with WP-CLI, OR access credentials to a remote/staging site

**Optional:**
- **Figma MCP** — needed only if you want to import galleries into Figma (see [Figma setup](#figma-setup))

---

## Installation

**1. Add the marketplace and install the plugin:**

```bash
/plugin marketplace add shub-rajput/design-superskills
/plugin install design-superskills@design-superskills
```

**2. Install agent-browser** (if not already installed):

```bash
npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser
```

**3. Restart Claude Code.**

On next launch, the session-start hook will confirm agent-browser is detected. If it's missing, you'll see a warning with the install command.

---

## Updating

```bash
/plugin update design-superskills@design-superskills
```

Then restart Claude Code.

---

## Usage

Both skills are invoked by describing your intent in natural language. Claude Code detects the right skill automatically.

**WP plugin research:**
> "Review the WooCommerce plugin admin UI on my local site"
> "Compare the onboarding flows of three form plugins"

**Website research:**
> "Capture and review the marketing page for wpforms.com"
> "Compare the pricing pages of the top 3 email marketing tools"

At the start of each skill, you'll be prompted to configure permissions (recommended) or choose manual approvals. The skills involve 40–50+ bash commands for browser automation, screenshots, and file operations.

---

## What You Get

Each run produces:

- **PNG screenshots** organized by subject in `screenshots/`
- **Annotated HTML gallery** (`screenshots/gallery.html`) with:
  - Screenshots grouped by section (Onboarding, Settings, Core Feature, etc.)
  - UX or marketing annotations per screenshot (issues, opportunities, positives)
  - Impact & Opportunity scores (optional)
  - Comparison table when reviewing multiple subjects
- **Figma-ready import** via the HTML-to-design capture workflow (optional)

---

## Review Objectives

Both skills support multiple lenses:

**wp-plugin-research:**
- General UX
- First-Time User experience
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
