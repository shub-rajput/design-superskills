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
| **6** | Create GitHub issues | With Figma links |
| **7** | Add screenshots (optional) | Export, user drag-drops, then label via edit |
| **8** | Update PM tool (optional) | Update Asana/PM task with issue links if provided |

## BEFORE YOU START: Create Tasks

**Use TaskCreate to create a task for each step.** Mark each as `in_progress` when starting and `completed` when done. This prevents skipping steps.

Tasks to create:
1. "Step 0: Check prerequisites"
2. "Step 1: Gather user input"
3. "Step 2: Read Figma structure"
4. "Step 3: Screenshot frames + read dev notes"
5. "Step 4: Organize into issues"
6. "Step 5: Ask clarifying questions — get user approval"
7. "Step 6: Create GitHub issues"
8. "Step 7: Add screenshots (optional)"
9. "Step 8: Update PM tool (optional)"

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

Ask the user directly in conversation — **do NOT use AskUserQuestion tool** for this.

**Pacing:** Start with the 3 required fields. Then ask optional questions as follow-ups — don't dump everything at once.

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

<HARD-GATE>
**You MUST get explicit user approval before proceeding to Step 6.** Do not create any issues until the user says the plan looks good. If you catch yourself about to run `gh issue create` without having asked questions and received approval — STOP.
</HARD-GATE>

**Ask questions as natural conversation, NOT via AskUserQuestion tool.**

### Part A: Present the plan in template format

Show each planned issue **using the exact template format from Step 4** — same headers, same structure. The preview should look identical to what will be created. Include:
- How many issues
- Title and type of each
- Which screens map to which issue

### Part B: Flag ambiguities

Scan the dev notes for these specific red flags and ask about each:
- **"Consult X" / "Check with X"** references — who decides?
- **"Placeholder" / "WIP" / "TBD"** labels — include or skip?
- **Open decisions** — e.g., provider choices, credit allotments, scope boundaries
- **Missing edge cases** — error states mentioned but not designed, empty states not shown
- **Dependencies between issues** — does one block another?

### Part C: Get approval

Ask: "Does this plan look good, or would you like to adjust anything?"

Iterate until the user approves. Only then proceed to Step 6.

## Step 6: Create GitHub Issues

### If gh CLI is available:

1. Create each issue with `gh issue create --repo <repo> --title "<title>" --body "$(cat <<'EOF' ... EOF)"`. Use HEREDOC to preserve markdown formatting.
2. Include Figma subsection links in the header table and Asana/PM link if provided.
3. Report all created issue URLs in a summary table.

**After each issue is created**, fetch it with `gh issue view` and verify the body rendered correctly (tables, links, formatting). Fix any issues with `gh issue edit --body-file`.

### If gh CLI is NOT available (markdown output mode):

Write markdown files as described in Step 0.

## Step 7: Add Screenshots (Optional)

After issues are created, ask: "Would you like to add screenshots to the issues?"

If no, done. If yes, check for `FIGMA_TOKEN`:
- **Not set:** Tell the user they need a Figma Personal Access Token. Skip screenshots.
- **Set:** Proceed below.

### Screenshot flow (one issue at a time):

1. **Export via Figma REST API** — batch all frames:
   ```bash
   curl -s "https://api.figma.com/v1/images/<fileKey>?ids=<node1>,<node2>,...&format=png&scale=2" \
     -H "X-Figma-Token: <token>"
   ```

2. **Download PNGs** to `./dev-handoff-issues/screenshots/`, organized per issue:
   ```
   screenshots/
     01-layout/
       disabled-state.png
       gmaps-not-connected.png
     02-zapier/
       not-connected.png
       connected.png
   ```

3. **For each issue:**
   - Open the screenshot folder: `open ./dev-handoff-issues/screenshots/01-layout/`
   - Tell the user: "Drag-drop these images into [issue link] and save."
   - Wait for the user to say done.
   - Fetch the updated body with `gh issue view`, then `gh issue edit --body-file` to label each screenshot under `### State Name` subheadings in the `## Screenshots` section.

## Step 8: Update Project Management Tool (Optional)

If the user provided an Asana/PM link in Step 1, offer to update it with the GitHub issue links and a summary. If Asana MCP tools are available, use them. Otherwise, output the update text for the user to paste manually.

Also ask: "Would you like me to create a review subtask in Asana for reviewing the designs and GitHub issues?" If yes, create a subtask on the parent task with a summary of what was created and links to the GitHub issues and Figma section.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `sed` to modify issue bodies with markdown tables | Pipe characters in tables break sed — use Python for string replacement |
| Embedding screenshots as comments instead of in the issue body | Edit the issue body directly with `gh issue edit --body-file` |
| Leaking FIGMA_TOKEN in env check output | Never echo the token — use the safe check in Step 0 |
| Screenshotting entire sections instead of individual frames | Sections are too small to read — always use individual frame node IDs |
| Forgetting to transcribe dev notes | Dev notes are the primary spec — screenshots alone miss edge cases |

## Notes

- **Cross-reference related issues** — if the user mentions something is handled in a separate issue, link to it.
