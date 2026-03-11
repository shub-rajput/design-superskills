# WP Plugin UX Review Skill

This repo contains a Claude Code skill and subagent for automating WordPress plugin UX reviews.

## Structure

- `SKILL.md` — The skill definition. Handles setup, screenshot capture, gallery generation, and Figma import.
- `agents/ux-reviewer.md` — Subagent dispatched after screenshot capture. Analyzes screenshots through the user's review objective and returns structured annotations for the gallery. Runs without Bash (reads images, writes JSON) so it needs no special permissions.
- `agents/ux-comparator.md` — Subagent dispatched after all ux-reviewer agents complete (multi-plugin reviews only). Receives each plugin's annotations and metadata, produces a structured comparison table with per-dimension ratings and a verdict. Only used when the user requests a comparison.

## Environment Paths

The skill supports two environment paths:

1. **Local site** — Local by Flywheel, MAMP, Valet, Docker, etc. Full WP-CLI access for plugin management and temp user creation.
2. **Remote/QA site** — Live or staging sites. Read-only (no WP-CLI, no site modifications).

Playground (wp-now) was intentionally removed — its SQLite backend breaks CSS/admin rendering for most real plugins, making screenshots unreliable for UX review.

## Editing Guidelines

- This is a skill file, not application code. Changes are instructions for Claude Code to follow.
- Keep steps numbered and sequential — the skill is designed to be followed top-to-bottom.
- The HTML gallery template in Step 8 must remain Figma-compatible (flexbox layout, inline styles, capture script).
- Shell command examples use placeholder paths (e.g., `<wp-root>`, `<wp-cli-command>`) for readability — the skill instructs Claude to resolve these to literal paths at runtime.
- Never use shell variables (`$HOME`, `$PHP_BIN`, etc.) in example commands — this is a deliberate rule to avoid extra permission prompts.
