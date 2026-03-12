# design-superskills

A Claude Code plugin for design research — screenshot capture, annotated galleries, and Figma import.

## Structure

```
design-superskills/
├── .claude-plugin/plugin.json        # Plugin metadata
├── skills/
│   ├── wp-plugin-research/SKILL.md   # WP plugin screenshot capture + UX review
│   └── website-research/SKILL.md     # Public website screenshot capture + marketing review
├── agents/
│   ├── ux-reviewer.md                # UX analysis of WP plugin admin screenshots
│   ├── ux-comparator.md              # Side-by-side plugin comparison
│   ├── marketing-reviewer.md         # Marketing/design analysis of public websites
│   └── marketing-comparator.md       # Side-by-side website comparison
├── shared/
│   └── common-steps.md              # Shared steps referenced by both skills (permissions, gallery, Figma, troubleshooting)
├── templates/
│   └── gallery.html                  # Shared Figma-compatible HTML gallery template
├── hooks/
│   ├── hooks.json                    # SessionStart hook config
│   └── session-start                 # Checks for agent-browser prerequisite
└── CLAUDE.md
```

## Skills

- **wp-plugin-research** — Captures screenshots of WordPress plugin admin UIs via agent-browser. Supports local sites (WP-CLI for plugin management, temp user creation) and remote/QA sites (read-only). Dispatches `ux-reviewer` and `ux-comparator` subagents for analysis.
- **website-research** — Captures screenshots of public websites for design reference. Supports direct URLs or discovery queries (e.g., "wpforms competitors"). Dispatches `marketing-reviewer` and `marketing-comparator` subagents for analysis.

## Agents

All agents are dispatched as `subagent_type: "general-purpose"` with the agent file's content inlined into the prompt. They return structured JSON for gallery generation.

- **ux-reviewer** — Analyzes WP plugin screenshots through UX lenses (general, first-time UX, monetization, custom). Returns annotations with manifest and status.
- **ux-comparator** — Compares multiple plugins. Text-only reasoning, dispatched with `model: "sonnet"`. Returns comparison table with ratings and verdict.
- **marketing-reviewer** — Analyzes public website screenshots through marketing/design lenses (marketing effectiveness, visual design, conversion flow, content strategy, custom). Same JSON format as ux-reviewer.
- **marketing-comparator** — Compares multiple websites. Same structure as ux-comparator with marketing-focused dimensions. Dispatched with `model: "sonnet"`.

## Git Rules

- Never commit without explicitly asking the user first.

## Editing Guidelines

- These are skill files, not application code. Changes are instructions for Claude Code to follow.
- Keep steps numbered and sequential — skills are designed to be followed top-to-bottom.
- The HTML gallery template lives in `templates/gallery.html` and must remain Figma-compatible (flexbox layout, inline styles, capture script).
- Shell command examples use placeholder paths (e.g., `<wp-root>`, `<wp-cli-command>`) for readability — the skill instructs Claude to resolve these to literal paths at runtime.
- Never use shell variables (`$HOME`, `$PHP_BIN`, etc.) in example commands — this is a deliberate rule to avoid extra permission prompts.
- Both reviewer agents must produce identical JSON schemas so the gallery template works for both skills.
- Both comparator agents must produce identical JSON schemas for the same reason.
