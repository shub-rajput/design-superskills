# Changelog

## 2.1.1

- `design-first-draft`, from a field test on the brief path:
  - Fewer gates: brief approval, including proposed directions, is the first question of the Step 3 ask; discovery runs alongside the interview.
  - Sections match the file's section style, or use a light parent with white direction cards instead of Figma's default dark grey. A size formula, and canvas labels only when the file already uses them.
  - Draft tokens get one collection per style (`Draft tokens · <Style>`, `Draft/<Style>/*` text styles), so a second run no longer collides with the first.
  - Draft kit recipe fixes: per-variant text after adding a text property, notices that hug their height, and matching box models across states.
  - Up to six frames per direction, one moment per frame, and states can be renamed when a direction's mechanism changes them.
  - Opus or Sonnet builders offered with time and token estimates. The brief is written to the scratchpad when the working directory is not the product. Works without a task tool.

## 2.1.0

- New `design-first-draft` skill: builds first-draft screens for every direction in a research synthesis, in Figma or as HTML. Accepts a project brief instead, interviewing until problem, objectives, scope and directions are clear (and proposing directions for approval when there are none). Discovers the design system in the Figma file, enabled libraries and the codebase before asking, confirms it with the user, and proposes shared visual styles (draft tokens plus a draft kit) only when none exists. Subagent or inline builds, orchestrator critique rounds, QA sweep, optional parity check when redesigning an existing screen. Never ranks directions.
- `research-synthesis`: direction cards can carry an optional visual direction line, and Scope an optional shared visual direction, written only when the user asks or the notes cover look and feel.
- README rewritten for designers: what each skill takes off your plate (you vs Claude), a GIF per skill cut from the showreel, and the app icon. GIFs are hosted as GitHub attachments, not in the repo.

## 2.0.1

- Removed the `mcp-optimize` skill. `design-organize` and `design-annotations` no longer offer it as a next step.

## 2.0.0

- New `design-research` skill replaces `website-research` and `wp-plugin-research`. One capture flow for public sites, logged-in web apps and local apps; screenshots land in a Figma refs section as labelled rows by default; observations, gallery and comparison are optional layers chosen up front.
- The visual refs recipe moved from `shared/figma-visual-refs.md` into `skills/design-research/capture.md`.
- `agents/ux-reviewer.md` and `agents/ux-comparator.md` are now generic (apps and admin UIs, not only WordPress plugins).
- `shared/common-steps.md` no longer carries WP-CLI content.
- WordPress-specific preparation (WP-CLI, temp user, plugin deactivation, first-run gates) lives in the separate `wp-plugin-research` skill, which hands over to `design-research`.
- Figma MCP is required for `design-research`.
- Breaking: the skill names `website-research` and `wp-plugin-research` no longer exist in this plugin. Run `/reload-plugins` after updating.

## 1.3.0

- New `research-synthesis` skill: turns observations on a refs section (stickies, dev notes, text notes, or observations gathered in chat) into a problem statement, objectives, shared patterns, current state, scope, directions, feature ideas and a collapsed inventory with deep links to every note. Audit voice, no ranking of directions.
