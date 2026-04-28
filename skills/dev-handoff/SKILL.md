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
| **9** | Cleanup temp files | Offer to remove `./dev-handoff-issues/` and other handoff scratch |

## STEP 0a — HARD-GATE: Create Tasks BEFORE Anything Else

<HARD-GATE>
**You MUST invoke TaskCreate with the full task list below before any substantive work in this skill — before checking `gh`, before reading Figma metadata, before asking the user any clarifying question.**

The only tool calls allowed before TaskCreate are the unavoidable bootstrap ones: reading this SKILL.md and loading TaskCreate's schema if deferred. Nothing else. Not "just a quick `gh auth status`," not "just a quick Figma metadata read to confirm the URL." Those are Step 0 and Step 2 — they come after the task list exists.

This applies even when this skill is chained after another skill (e.g., after `design-organize` or `design-annotations`). Chained invocations are the most common place where task setup gets skipped because the early steps "feel small" — they are not. If you skip this gate and only create tasks retroactively, the user cannot see structured progress and the skill's later HARD-GATEs lose their force.

If you cannot invoke TaskCreate for any reason, STOP and explain why to the user before proceeding.
</HARD-GATE>

Create these tasks in a single TaskCreate batch:

1. "Step 0: Check prerequisites"
2. "Step 1: Gather user input"
3. "Step 2: Read Figma structure"
4. "Step 3: Screenshot frames + read dev notes"
5. "Step 4: Organize into issues"
6. "Step 5: Ask clarifying questions — get user approval"
7. "Step 6: Create GitHub issues"
8. "Step 7: Add screenshots (optional)"
9. "Step 8: Update PM tool (optional)"
10. "Step 9: Cleanup temp files"

Mark each `in_progress` when starting and `completed` when done. **Tasks ARE the early steps — do not treat the first few as too trivial to track.**

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

### Part B: Flag ambiguities (substance scan — NOT logistics)

<HARD-GATE>
**Do not proceed to Part C until you have produced an explicit red-flag scan output.** This is a substance scan of the dev notes, NOT logistics questions about Asana links / titles / screenshot hosts. Logistics ≠ substance — do not conflate them.
</HARD-GATE>

Scan every dev note for these red flags and produce explicit output of the form:

```
Red-flag scan:
- [dev note quote] → open question: ...
- [dev note quote] → open question: ...
(or: "No red flags found" with one-sentence reasoning per category)
```

Categories to scan:
- **"Consult X" / "Check with X"** references — who decides?
- **"Placeholder" / "WIP" / "TBD" / "or similar"** labels — include or skip?
- **Open decisions** — provider choices, URL fallbacks ("if there is none…"), credit allotments, scope boundaries ("we can look into having this on all pages")
- **Missing edge cases** — error states mentioned but not designed, empty states, fallback behavior when stored state is missing
- **Dismissal/trigger conditions** — ambiguous triggers like "any successful email" — does that include adjacent flows?
- **Dependencies between issues** — does one block another?

Quote the dev-note text verbatim for each finding so the user can confirm context.

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

## Step 9: Cleanup Temp Files

Once issues are created and (optionally) the PM tool is updated, list every scratch file/dir this run produced and offer to remove them. Common candidates:

- `./dev-handoff-issues/` (markdown drafts in markdown-output mode)
- `./dev-handoff-issues/screenshots/` (downloaded PNGs from Figma export)
- Any `/tmp/dev-handoff-*` files (issue body drafts, scan outputs, etc.)

Ask the user: "I created the following temp files during this handoff: [list paths]. Want me to delete them now, or keep them for reference?"

Only delete after explicit user confirmation. Use `rm` for files and `rm -rf` for directories — and only on paths you actually created in this run. Do not touch files you didn't create.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Skipping task setup because early steps look trivial | Tasks ARE the early steps; user can't see hidden progress. Always create the full list first. |
| Skipping task setup when chained from another skill | Chained invocations are the most common skip-point. Step 0a applies regardless of how the skill was invoked. |
| Conflating logistics questions with the Step 5 Part B substance scan | Asana link / title / hosting questions are not red-flag findings. Both must happen. |
| Using `sed` to modify issue bodies with markdown tables | Pipe characters in tables break sed — use Python for string replacement |
| Embedding screenshots as comments instead of in the issue body | Edit the issue body directly with `gh issue edit --body-file` |
| Embedding Handoff/HTML-wrapper URLs as `<img src>` in GitHub issue bodies | GitHub's Camo proxy fetches the URL and renders broken because Handoff returns HTML, not raw image bytes. Use drag-drop into `user-attachments.githubusercontent.com` or a host that returns `content-type: image/*`. Verify with `curl -I <url>`. |
| Guessing which `user-attachments/assets/<uuid>` URL is which screenshot | Those URLs 404 to unauthenticated curl. Ask the user to upload one screenshot at a time and label inline, OR confirm upload order against the numbered state list before labeling. |
| Drafting from stale dev notes after the user edited them mid-flow | If dev notes were empty when this skill started, or the user says they updated them, re-run the dev-note read before drafting. |
| Leaking FIGMA_TOKEN in env check output | Never echo the token — use the safe check in Step 0 |
| Screenshotting entire sections instead of individual frames | Sections are too small to read — always use individual frame node IDs |
| Forgetting to transcribe dev notes | Dev notes are the primary spec — screenshots alone miss edge cases |
| Forgetting to clean up `./dev-handoff-issues/` and other scratch | Step 9 exists for this — offer cleanup before declaring done. |

## Notes

- **Cross-reference related issues** — if the user mentions something is handled in a separate issue, link to it.
