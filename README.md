<p align="center">
  <img src="assets/icon.png" width="96" alt="design-superskills icon: a pixel pencil held up over a pixel Claude">
</p>

<h1 align="center">design-superskills</h1>

<p align="center">
  <b>Claude Code skills for designers.</b><br>
  Your agent handles the grunt work around design, so you get more time to actually design.
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#the-skills">The skills</a>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/8c48bc15-a6cc-46c3-9c0d-768d7145c6e0" width="720" alt="The design workflow is fun. But comes with a bunch of grunt work. Let your agent handle it!">
</p>

The design workflow is fun. But it comes with a bunch of grunt work: screenshotting competitors, pasting them into Figma and labelling every row, turning a wall of sticky notes into something you can share, tidying frames into sections, placing dev notes, writing a ticket for every screen.

design-superskills hands that work to Claude Code. It is semi-automated on purpose. **You** pick the references, write the notes and make the design calls. **Claude** does the capturing, sorting, writing up and filing.

| Skill | You | Claude |
|---|---|---|
| [design-research](#design-research) | Pick the references | Screenshots every screen into labelled Figma rows |
| [research-synthesis](#research-synthesis) | Leave notes on the refs | Turns them into a problem, objectives and directions |
| [design-first-draft](#design-first-draft) | Pick a direction and iterate | Drafts first screens for every direction |
| [design-organize](#design-organize) | Design the screens | Sorts them into labelled sections |
| [design-annotations](#design-annotations) | Drop dev notes anywhere | Places each one by its screen |
| [dev-handoff](#dev-handoff) | Point at a section | Turns screens and notes into GitHub issues |

---

## The skills

You don't call skills by name. Describe what you want in plain words and Claude picks the right one. They work on their own, or one after another from first reference to dev handoff.

### design-research

**You pick the references. Claude screenshots them into Figma.**

<img src="https://github.com/user-attachments/assets/a150bf80-bebf-43a5-876d-e97361f261c4" width="720" alt="Claude opens two reference sites, captures four onboarding screens and places them in a Refs row in Figma">

Name the sites or apps and the flow you care about. Claude opens them in a headless browser, walks the flow, captures each screen and places one labelled row per source in your Figma refs section, matching any rows you already arranged by hand.

If you want more than references, ask for:

- **Observations** next to each screen, through a UX lens (apps and admin UIs) or a marketing lens (public sites)
- **An annotated HTML gallery** with impact and opportunity scores
- **A comparison** across sources, with ratings and a verdict

> "Put screenshots of these three onboarding flows into my Figma refs section"<br>
> "Capture basecamp.com's pricing flow as references, and add your observations next to the screens"<br>
> "Compare the onboarding of these two apps"

<details>
<summary>Review lenses</summary>

**Apps and admin UIs (ux-reviewer):** General UX · First-time user experience · Upsell and monetization · Custom (you describe the focus)

**Public websites (marketing-reviewer):** Marketing effectiveness · Visual design · Conversion flow · Content strategy · Custom

</details>

Reviewing a WordPress plugin? [wp-plugin-research](https://github.com/shub-rajput/wp-plugin-research-skill) prepares the site (WP-CLI, a temporary admin user, first-run gates) and hands over to design-research.

### research-synthesis

**You leave notes on the refs. Claude turns them into directions.**

<img src="https://github.com/user-attachments/assets/f12f6a83-70e1-4916-bf5e-0a58c983d125" width="720" alt="Sticky notes land on four reference screens, then Claude writes a research board with problem, objectives and directions">

Stick notes on your references the way you already do. Claude reads every sticky, dev note and text note in the section (or observations gathered in chat) and writes one document: problem statement, objectives, shared patterns, current state, scope, directions and feature ideas.

You get an HTML page and a Markdown copy you can send to your team. Every claim links back to the note it came from. It summarises; it never ranks the directions or picks one for you.

> "Turn the notes in this refs section into a problem statement, objectives and directions"<br>
> "Synthesize my research into one doc I can send to my managers"

### design-first-draft

**Claude drafts each direction, so you never start from a blank canvas.**

<img src="https://github.com/user-attachments/assets/d9f5a3d5-f762-4a98-8d55-f5ea2aab8820" width="720" alt="Claude drafts a first screen for each direction on the research board, linked to its direction card">

A starting point to react to, not the final design. Claude takes a synthesis (or interviews you on a project brief until the problem, objectives and directions are clear) and builds three to five first-draft screens per direction, in Figma or as HTML.

It looks for your design system in Figma and in code and confirms it with you first. With none, it proposes a few visual styles and builds with the one you pick. Each run ends with a summary of what it built with, QA results and gaps in the design system.

> "Design first drafts for the four directions in this synthesis, in my Figma Designs section"<br>
> "Here is the project brief, help me shape directions and draft them in code"

### You take it from there

**The draft gets things started. Your judgement makes it good.** No skill here; this is the part you keep.

<img src="https://github.com/user-attachments/assets/bfa77f7e-c822-441b-9cc6-074d2144b33c" width="720" alt="The designer iterates on the picked draft: draws an email field and snaps the Continue button into place">

### design-organize

**Claude sorts your screens into labelled sections.**

<img src="https://github.com/user-attachments/assets/7f369af1-3d91-4e6d-8aaa-b9fc9b7bc2d6" width="720" alt="Claude sweeps through eight messy screens and settles them into labelled Signup and Settings sections">

Point at a messy page or section. Claude groups the screens by flow into labelled sections, names every screen and lays them out in clean rows. It can also re-format an existing layout or move screens between sections.

> "Organize this page into sections by flow"<br>
> "Clean up and label these screens in Figma"

### design-annotations

**You drop notes anywhere. Claude places each by its screen.**

<img src="https://github.com/user-attachments/assets/7c6b42e7-4aa4-418a-bac4-37c541d853d5" width="720" alt="Five dev notes dropped loosely on the canvas, then Claude makes room and places each note under its screen">

Write dev notes wherever is quickest. Claude makes room under each screen and moves every note next to the screen it belongs to, using your design system's note component or a default template. It can also tighten the copy of existing notes so developers get behaviour, states and data sources, not guesswork.

> "Place my dev notes by their screens"<br>
> "Add dev notes to the first 3 screens in this section"<br>
> "Improve the copy on existing dev notes"

### dev-handoff

**Claude turns each screen and its notes into a GitHub issue.**

<img src="https://github.com/user-attachments/assets/572e7f77-3175-49c6-98fd-5efc6035df7c" width="720" alt="A GitHub issues panel slides in beside the Signup section, with one issue per screen linked to its notes">

Point at a Figma section. Claude reads the screens and their dev notes, asks how you want the issues split, detects the issue type, and opens them on GitHub using your repo's issue templates (bug report, enhancement, new feature) and Figma links. Set `FIGMA_TOKEN` to attach frame PNGs too.

> "Hand off the Signup section as issues"<br>
> "Turn these designs into tickets for the frontend team"

---

<p align="center">
  <img src="https://github.com/user-attachments/assets/e89a0f67-e762-4b74-af68-23b82ca483c4" width="720" alt="Grunt work handled: each task on the to-do list ticked off by the skill that did it. More time to design what matters. Then the install command">
</p>

---

## Install

### Requirements

- **Claude Code** with plugin support
- **[agent-browser](https://github.com/vercel-labs/agent-browser)** for screenshot capture
- **Figma MCP** (remote server) for everything that reads or writes Figma (see [Figma setup](#figma-setup))

### Steps

1. Add the marketplace:

   ```
   /plugin marketplace add shub-rajput/design-superskills
   ```

2. Install the plugin:

   ```
   /plugin install design-superskills@design-superskills
   ```

3. Install agent-browser, if you don't have it:

   ```bash
   npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser
   ```

4. Restart Claude Code. The session-start hook warns you if agent-browser is missing. Then try:

   > "Put screenshots of stripe.com's pricing flow into my Figma refs section"

   Claude should pick up the **design-research** skill on its own.

### Figma setup

Needed for design-research, research-synthesis, design-first-draft (Figma mode), design-organize, design-annotations and dev-handoff. These skills use the **remote Figma MCP server**, not the built-in Claude AI Figma integration.

```bash
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Restart Claude Code after adding it.

**Optional for dev-handoff:** set `FIGMA_TOKEN` in your environment to attach frame PNGs via the Figma REST API. Without it, issues link to Figma instead.

### Permissions

The research skills run dozens of shell commands: browser screenshots, a local gallery server, Figma calls. Before the heavy steps, Claude asks how you want to handle them:

1. **Auto mode (recommended):** press **Shift+Tab** until the mode shows **auto mode**. Claude runs commands without asking each time. No settings file, no restart.
2. **Your own allowlist:** prefer to keep approvals on? Add `Bash(...)` rules to `.claude/settings.local.json` for the commands you trust.
3. **Manual approvals:** approve each command as it comes. Slow, but always works.

### Updating

**Auto-update (recommended):** run `/plugin marketplaces`, select **design-superskills** and choose **Enable auto-update**. It's off by default for third-party marketplaces. When an update lands, run `/reload-plugins`.

**Manual:** run `/plugin`, find **design-superskills** under **Installed**, select **Update now**, then run `/reload-plugins`.

---

<details>
<summary><b>What's inside</b></summary>

```
design-superskills/
├── skills/
│   ├── design-research/       # Capture any flow → Figma refs rows (+ optional observations, gallery, comparison)
│   │   ├── SKILL.md
│   │   ├── capture.md         # Login, capture notes, Figma placement recipe
│   │   └── review-layer.md    # Review brief, agents, placing observations, comparison
│   ├── research-synthesis/    # Canvas notes → problem, objectives, patterns, directions doc
│   ├── design-first-draft/    # Synthesis or brief → first-draft screens per direction (Figma or HTML)
│   ├── design-organize/       # Figma screen organization + labeling
│   ├── design-annotations/    # Dev note placement + copy improvement
│   └── dev-handoff/           # Figma designs → GitHub issues for dev handoff
├── agents/
│   ├── ux-reviewer.md         # UX analysis of app and admin UI screenshots
│   ├── ux-comparator.md       # Side-by-side app comparison
│   ├── marketing-reviewer.md  # Marketing/design analysis of public websites
│   └── marketing-comparator.md# Side-by-side website comparison
├── assets/                    # Icon
├── hooks/                     # SessionStart hook for agent-browser check
├── shared/
│   └── common-steps.md        # Shared steps: permissions, capture strategy, gallery, troubleshooting
├── templates/
│   └── gallery.html           # Figma-compatible HTML gallery template
└── CHANGELOG.md
```

</details>

## License

MIT — [Shubhang Haresh Rajput](https://github.com/shub-rajput)
