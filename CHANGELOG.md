# Changelog

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
