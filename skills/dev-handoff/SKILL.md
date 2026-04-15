---
name: dev-handoff
description: Use when handing off Figma designs to developers as GitHub issues. Triggers include "hand off to dev", "create issues from Figma", "turn designs into tickets", "dev handoff", or when user shares a Figma URL and asks for GitHub issues to be created from it.
---

# Dev Handoff

Turn Figma design sections into GitHub issues for developer handoff. Reads the Figma hierarchy, extracts Developer Note components, and creates issues with the user's templates.

## When to Use
- User shares a Figma URL and wants GitHub issues created from the designs
- User says "hand off", "create dev tickets", "turn designs into issues"
- User has a Figma section with multiple screens + dev notes ready for implementation

## When NOT to Use
- User wants to implement the design (use `figma:figma-implement-design`)
- User wants to organize/label Figma screens (use `design-superskills:design-organize`)
- User wants to add dev notes to Figma (use `design-superskills:design-annotations`)
- User just wants screenshots without issue creation

## Quick Reference

| Step | What | Key Decision |
|------|------|-------------|
| **0** | Prerequisites | Figma MCP required, gh CLI optional (fallback to markdown files) |
| **1** | Gather user input | Figma URL, repo, issue templates, context |
| **2** | Read Figma structure | Get metadata, identify sections, skip WIP |
| **3** | Screenshot frames + read dev notes | Individual frames, not sections |
| **4** | Organize into issues | Group by section, detect issue type |
| **5** | Ask clarifying questions | Before creating any issues |
| **6** | Export frame screenshots (optional) | Via Figma REST API if FIGMA_TOKEN is set |
| **7** | Create GitHub issues | With Figma links, and embedded screenshots if available |
| **8** | Update PM tool (optional) | Update Asana/PM task with issue links if provided |

## Step 0: Prerequisites

Check before gathering input:

| Check | How | Fallback |
|-------|-----|----------|
| **Figma MCP** | Check for `mcp__figma__get_metadata` in available tools | Cannot proceed without it — Figma MCP is required |
| **gh CLI** | `gh auth status` | If not available, offer the user a choice (see below) |
| **FIGMA_TOKEN** (optional) | `[ -n "$FIGMA_TOKEN" ] && echo "set" \|\| echo "not set"` | Skip screenshot embedding, use Figma links only |

### If gh CLI is missing or not authenticated

Ask the user which they prefer:

> **GitHub CLI isn't set up. Would you like to:**
> 1. **Set it up now** — I'll walk you through installing and authenticating `gh`
> 2. **Skip it** — I'll write the issues as markdown files you can copy-paste into GitHub

**Option 1 — Setup gh CLI:**
- If `gh` is not installed: `brew install gh` (macOS) or point to [cli.github.com](https://cli.github.com)
- If installed but not authenticated: ask user to run `! gh auth login` in the prompt (the `!` prefix runs it interactively in this session)
- After auth succeeds, re-check with `gh auth status` and continue normally

**Option 2 — Markdown output mode:**
- Run the full workflow (Steps 1–6) as normal
- In Step 7, write each issue as a markdown file to `./dev-handoff-issues/`
- Name files: `01-update-integration-layout.md`, `02-zapier-integration.md`, etc.
- Each file contains the full issue body ready to copy-paste into GitHub

## Step 1: Gather User Input

Ask the user directly in conversation — **do NOT use AskUserQuestion tool** for this. Have a natural back-and-forth to collect:

**Required — ask for each explicitly, never guess or assume:**
- **Figma URL** — link to the parent section/page containing all design screens
- **GitHub repo** — ask the user to paste the repo link or `owner/repo`. **Never guess repo names** — naming conventions vary and guessing wastes time
- **Overall context** — what is this feature/update about?

**Optional (ask if not provided):**
- **Issue templates** — does the team use specific templates? (Bug Report, Enhancement, New Feature, or custom)
- **Asana/project management link** — to include in issue headers and for optional PM updates in Step 8
- **Sections to skip** — any WIP or irrelevant sections?
- **How to split issues** — one per section? grouped? single mega-issue?

**Issue templates:** Ask the user: "Do you have specific GitHub issue templates you'd like me to follow, or should I use the default ones?" If they provide templates, use them exactly. If not, use the skill's built-in defaults in Step 4.

## Step 2: Read Figma Structure

Use `mcp__figma__get_metadata` on the provided node to discover the hierarchy.

Parse the metadata to identify:
- **Sections** — top-level groupings (e.g., "Zapier", "Google Calendar", "Credit Use")
- **Frames** — individual screen designs within each section (e.g., "Not Connected", "Connected")
- **Developer Note instances** — components named "Developer Note" containing implementation context
- **Labels/text nodes** — screen labels at the section level (e.g., "Not Connected", "Connected > Error")

**Skip sections** whose names contain "(WIP)" or that the user explicitly excluded.

Present the discovered structure to the user for confirmation before proceeding:
```
Found N sections (skipping M WIP):
1. Section Name — X screens, Y dev notes
2. Section Name — X screens, Y dev notes
...
```

## Step 3: Screenshot Frames + Read Dev Notes

For each non-WIP section:

1. **Get screenshots of individual frames** using `mcp__figma__get_screenshot` — capture each screen state separately (e.g., "Not Connected", "Connected", "Error"), NOT the entire section.
2. **Get screenshots of Developer Note instances** to read their content — these contain implementation details, edge cases, and behavioral specs written by the designer.

Record all information per section:
- Frame name, node ID, and visual content
- Dev note content (transcribe from screenshot)
- Screen labels from text nodes

## Step 4: Organize Into Issues

Based on user preferences from Step 1, organize the captured data into issues.

### Templates, Detection & Extraction

**If the user provided their own templates, use them exactly.** Map the extracted information into their template fields. Do not improvise.

**If using the skill's defaults**, read `issue-templates.md` in this skill directory. It contains:
- 3 templates (Bug Report, Enhancement, New Feature)
- Issue type detection logic with keywords
- Information extraction rules for each template field
- Title generation guidelines

When the issue type is unclear, default to **New Feature** for new integrations/features or **Enhancement** for updates to existing functionality.

### Figma Links

Always link to the **specific subsection** in Figma, not the parent section. Convert node IDs to URL format: `node-id=XXXX-YYYY` (replace `:` with `-`).

## Step 5: Ask Clarifying Questions

**Before creating any issues**, present the planned issue structure and ask clarifying questions. This is critical — don't skip this step.

**Ask questions as natural conversation, NOT via AskUserQuestion tool.** The tool forces rigid multiple-choice options that prevent nuance and follow-up. Instead, write your questions directly in your response so the user can answer freely and you can have a back-and-forth.

Show the user:
1. How many issues you plan to create
2. The title and type of each issue
3. Which sections/screens map to which issue
4. Any ambiguities in the dev notes

Ask about:
- Anything unclear in the dev notes
- Whether the issue grouping makes sense
- Any missing context or dependencies between issues
- Whether any issues should be combined or split differently

Iterate on the plan until the user approves.

## Step 6: Export Frame Screenshots (Optional)

This step is **optional** — it requires a `FIGMA_TOKEN` environment variable set with a Figma Personal Access Token. Check for it at the start of this step.

**If `FIGMA_TOKEN` is NOT set:**
- Skip this step entirely — no error, no warning beyond a brief note
- Issues will use Figma links in the Screenshots section instead of embedded images
- The skill works fully without it

**If `FIGMA_TOKEN` IS set:**

Ask the user: "FIGMA_TOKEN is available — would you like embedded screenshots in the issues, or just Figma links?" Only proceed with export if they want embedded screenshots.

Use the Figma REST API to export frame PNGs for embedding in GitHub issues.

```bash
# Batch export all frames at once (comma-separated node IDs)
curl -s "https://api.figma.com/v1/images/<fileKey>?ids=<node1>,<node2>,...&format=png&scale=2" \
  -H "X-Figma-Token: <token>"
```

This returns temporary S3 URLs for each frame. Embed the URLs directly in the GitHub issue body as markdown images. GitHub caches them via their camo proxy.

## Step 7: Create GitHub Issues

### If gh CLI is available:

Use `gh issue create` to create each issue on the target repo.

1. Build the full issue body with all sections, dev notes, and screenshots
2. Create with `gh issue create --repo <repo> --title "<title>" --body "$(cat <<'EOF' ... EOF)"`
3. Report all created issue URLs in a summary table:

```
| # | Issue | Link |
|---|-------|------|
| 1 | Title | #NNN |
| 2 | Title | #NNN |
```

### If gh CLI is NOT available (markdown output mode):

Write markdown files as described in Step 0.

### Formatting rules (both modes):
- Use HEREDOC for body to preserve markdown formatting
- Embed screenshots as `![Label](url)` under `## Screenshots` with `### State Name` subheadings
- Include Figma subsection links in the header table
- Always include the Asana/project management link if provided

## Step 8: Update Project Management Tool (Optional)

If the user provided an Asana/PM link in Step 1, offer to update it with the GitHub issue links and a summary. If Asana MCP tools are available, use them. Otherwise, output the update text for the user to paste manually.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `sed` to modify issue bodies with markdown tables | Pipe characters in tables break sed — use Python for string replacement |
| Embedding screenshots as comments instead of in the issue body | Edit the issue body directly with `gh issue edit --body-file` |
| Leaking FIGMA_TOKEN in env check output | Never echo the token — use the safe check in Step 0 |
| Screenshotting entire sections instead of individual frames | Sections are too small to read — always use individual frame node IDs |
| Forgetting to transcribe dev notes | Dev notes are the primary spec — screenshots alone miss edge cases |

## Notes

- **Figma export URLs are temporary** — ~14 days, but GitHub caches via camo proxy. If permanent hosting is needed later, commit to `.github/design-assets/` in the repo.
- **Cross-reference related issues** — if the user mentions something is handled in a separate issue, link to it.
