# WP Plugin UX Review Skill

This repo contains a single Claude Code skill (`SKILL.md`) for automating WordPress plugin UX reviews.

## Structure

- `SKILL.md` — The skill definition. Contains all steps, templates, and guidelines.

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
