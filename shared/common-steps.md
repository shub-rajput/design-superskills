# Common Steps Reference

Shared instructions referenced by both wp-plugin-research and website-research skills.

## Permissions (Step 0)

This skill is **extremely command-heavy** — dozens of sequential bash commands for browser automation, screenshots, local server, and file operations.

**You MUST use AskUserQuestion here and WAIT for the user's response. Do NOT proceed, do NOT run any Bash commands, do NOT explore the codebase, do NOT skip this step. No matter what mode you think you're in, always ask.**

Ask with these options:

> **Heads up:** This review involves 40-50+ bash commands (browser automation, screenshots, local servers). Each one needs manual approval unless permissions are configured.
>
> How would you like to proceed?

1. **Add permissions to settings (Recommended)** — I'll add the required tool permissions to this project's `.claude/settings.local.json`, then you restart Claude Code and re-invoke the skill
2. **Use bypass mode** — exit, restart with `claude --dangerously-skip-permissions`, then re-invoke the skill
3. **I've already set up permissions or bypass mode** — proceed immediately
4. **Continue with manual approvals** — I'll approve each command individually (slow but works)

**After the user responds:**

- **Option 1:** Read the project's `.claude/settings.local.json` (create if it doesn't exist). Merge the following permissions into the `permissions.allow` array, preserving any existing entries and all other settings.

### Permission pattern syntax

Use `Bash(command *)` with a **space** before the wildcard. The colon syntax (`Bash(command:*)`) is deprecated per Claude Code docs:

> The legacy `:*` suffix syntax is equivalent to ` *` but is deprecated.

Shell operator awareness (also from the docs):

> Claude Code is aware of shell operators (like `&&`) so a prefix match rule like `Bash(safe-cmd *)` won't give it permission to run the command `safe-cmd && other-cmd`.

This means commands with `&&`, `||`, `|`, `&`, or `$VARIABLE` will NOT match any wildcard permission rule. The skill already avoids these (see "No Shell Variables" section below), but a few edge cases remain — documented in the "Commands that will still prompt" table.

### Core permissions (both skills)

```json
{
  "permissions": {
    "allow": [
      "Bash(agent-browser *)",
      "Bash(agent-browser set viewport *)",
      "Bash(python3 -m http.server *)",
      "Bash(curl *)",
      "Bash(mkdir *)",
      "Bash(kill *)",
      "Bash(open http*)",
      "Bash(cat > screenshots*)",
      "Bash(which *)",
      "Bash(sleep *)",
      "Bash(rm *)",
      "Bash(lsof -i *)"
    ]
  }
}
```

### Additional permissions for wp-plugin-research

Also merge these when the user is running the wp-plugin-research skill:

```json
"Bash(chmod +x *)",
"Bash(screenshots/wp *)",
"Bash(wp *)"
```

### Commands that will still prompt (unavoidable)

These use shell operators and cannot be pre-approved — Claude Code blocks them by design:

| Command | Why it prompts | Skill workaround |
|---------|---------------|------------------|
| `python3 -m http.server 3000 &` | `&` is a shell operator | Use `run_in_background: true` on the Bash tool call instead of trailing `&` |
| `agent-browser snapshot -i 2>&1 \| grep "keyword"` | `\|` pipe operator | Run `agent-browser snapshot -i` alone and search the output directly |
| `cat > file <<'HEREDOC' ... HEREDOC` | Heredoc syntax | May still prompt — user approves once per session |

These local project permissions merge with whatever the user has in their global `~/.claude/settings.json`. Deny rules at any level override allow rules.

After writing, tell the user: "Permissions added. Please restart Claude Code (`/exit` then relaunch) and re-invoke the skill." **Stop here — do nothing else.**

- **Option 2:** Tell them to run `claude --dangerously-skip-permissions` and re-invoke the skill. **Stop here — do nothing else.**
- **Option 3:** Proceed to next step.
- **Option 4:** Proceed, but warn it will be slow (40-50+ individual approvals).

**Do NOT move to the next step until the user has explicitly chosen an option.**

## No Shell Variables in Bash Commands

Claude Code flags commands containing `$VARIABLE` syntax (like `$HOME`, `$SESSION`) as requiring **extra** manual approval for shell expansion — even with pre-configured permissions this adds friction.

**Rule: Always use fully resolved, literal paths in every Bash command. Never use `$HOME`, `$SESSION`, `$URL`, `$PHP_BIN`, `$SOCKET`, `$WP_CLI`, `$WP_PATH`, or any other shell variable.**

```bash
# WRONG — triggers extra "shell expansion" approval prompt:
agent-browser --session "$SESSION" open "$URL"

# CORRECT — uses resolved values, minimal prompts:
agent-browser --session ws-abc123 open "https://example.com"
```

The examples in these skills use placeholders like `<session>` and `<url>` for readability — always substitute actual values when running commands.

Also avoid chaining commands with `||` and `&&` — these trigger "shell operators" approval. Use separate sequential Bash calls instead.

## Figma MCP Setup

Only needed if user wants Figma import.

The skill requires the **remote Figma MCP server**, not the Claude AI built-in Figma integration. If the `mcp__figma__generate_figma_design` tool is not available, tell the user to run:

```
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Then restart Claude Code. The remote MCP provides `generate_figma_design` which is needed for the HTML-to-Figma capture workflow. The Claude AI built-in Figma tools (`mcp__claude_ai_Figma__*`) do NOT support this.

## agent-browser Click Syntax

**Clicking elements by ref:** Use bracket syntax `[ref=e21]`, NOT `@ref=e21`:
```bash
# CORRECT:
agent-browser --session <session> click "[ref=e21]"

# WRONG (will throw CSS parse error):
agent-browser --session <session> click "@ref=e21"
```

**When `text=` matches multiple elements:** Use `snapshot -i` to get specific `[ref=XX]` IDs, then click by ref.

**Always use `snapshot -i`** to discover the correct ref before clicking. Never guess selectors.

## Screenshot Capture Strategy

### Wait for Images to Load

Pages with lazy-loaded images, hero banners, or heavy assets need time to render before capture. **Always do this before taking any screenshot:**

1. **Scroll the entire page top-to-bottom first** — this triggers lazy-loaded images and deferred content:
```bash
agent-browser --session <session> eval "(async () => { const h = document.body.scrollHeight; const step = window.innerHeight; for (let y = 0; y < h; y += step) { window.scrollTo(0, y); await new Promise(r => setTimeout(r, 400)); } window.scrollTo(0, 0); })()"
```
**Note:** `agent-browser eval` does NOT support top-level `await`. Always wrap async code in `(async () => { ... })()`.

2. **Wait for all visible images to finish loading:**
```bash
agent-browser --session <session> eval "Promise.all(Array.from(document.images).filter(img => !img.complete).map(img => new Promise(r => { img.onload = img.onerror = r; })))"
```

3. **Then take the screenshot** (either single or chunked — see below).

If a page still shows placeholder images after this, add an extra fixed wait:
```bash
agent-browser --session <session> eval "await new Promise(r => setTimeout(r, 3000))"
```

### Chunked Capture for Long Pages

Full-page screenshots of long pages produce massive PNGs that are slow in the gallery and extremely slow in Figma. **Set a tall viewport and split long pages into chunks that stitch in the HTML gallery.**

**When to chunk:** If page height > 4× default viewport height (~2900px+), use chunked capture. Otherwise, use a single `--full` screenshot.

**Step 1 — Set a tall viewport:**

Double the viewport height before capturing. This makes each chunk cover more content (fewer chunks, faster Figma loading):
```bash
agent-browser set viewport 1280 1440 --session <session>
```
This sets the viewport to 1280×1440 (default is 1280×720). Verify with:
```bash
agent-browser --session <session> eval "window.innerHeight"
```

**Step 2 — Measure the page:**
```bash
agent-browser --session <session> eval "JSON.stringify({ scrollHeight: document.body.scrollHeight, viewportHeight: window.innerHeight })"
```

**Step 3 — Capture chunks:**

**Important:** Always use **absolute paths** for screenshot destinations. `agent-browser screenshot` saves relative to its own working directory, which may differ from Claude's working directory. Example: `/Users/jane/project/screenshots/slug/XX-desc-p1.png`.

Scroll to each position and take a viewport screenshot (no `--full` flag). Step size = viewport height (1440px). No overlap between chunks.

```bash
# Chunk 1: top of page
agent-browser --session <session> eval "window.scrollTo(0, 0)"
agent-browser --session <session> eval "(async () => { await new Promise(r => setTimeout(r, 300)); })()"
agent-browser --session <session> screenshot screenshots/<slug>/XX-description-p1.png

# Chunk 2: scroll down by viewport height
agent-browser --session <session> eval "window.scrollTo(0, 1440)"
agent-browser --session <session> eval "(async () => { await new Promise(r => setTimeout(r, 300)); })()"
agent-browser --session <session> screenshot screenshots/<slug>/XX-description-p2.png

# Chunk 3: scroll down another step
agent-browser --session <session> eval "window.scrollTo(0, 2880)"
agent-browser --session <session> eval "(async () => { await new Promise(r => setTimeout(r, 300)); })()"
agent-browser --session <session> screenshot screenshots/<slug>/XX-description-p3.png

# Continue: scrollTo(0, 1440 * chunkIndex) until scrollY + viewportHeight >= scrollHeight
```

**No overlap between chunks.** Overlapping causes visible text/image duplication at seam boundaries. Clean cuts at viewport boundaries are preferable — most page sections have natural whitespace that absorbs the seam.

**Naming convention:** Append `-p1`, `-p2`, `-p3` etc. to the base filename. E.g., `03-settings-p1.png`, `03-settings-p2.png`.

For the **last chunk**, scroll to the very bottom to capture the footer:
```bash
agent-browser --session <session> eval "window.scrollTo(0, document.body.scrollHeight - window.innerHeight)"
```

**Step 3 — Verify each chunk:** `Read` each PNG to confirm it captured correctly.

### Gallery HTML for Chunked Screenshots

In the gallery, stack all chunks for a screen inside a single `.screenshot-card`. The template's `line-height: 0` on `.screenshot-card` and `display: block` on `img` ensure zero gap between parts:

```html
<div class="screenshot-card">
  <img src="slug/03-settings-p1.png" alt="Settings (1/3)">
  <img src="slug/03-settings-p2.png" alt="Settings (2/3)">
  <img src="slug/03-settings-p3.png" alt="Settings (3/3)">
</div>
```

This renders as one continuous image. Annotations (`.ux-notes`) go after the card as usual — they apply to the full screen, not individual chunks.

**In the review brief and subagent prompt:** List chunked screenshots grouped together so the reviewer knows they form one logical screen:
```markdown
### 03-settings (3 parts)
**Screen:** Plugin settings page
**Parts:** 03-settings-p1.png, 03-settings-p2.png, 03-settings-p3.png
**Journey:** Settings page is very long — required scrolling through 4 sections...
```

The reviewer subagent should Read all parts for a screen and analyze them as one continuous page.

## Generate HTML Gallery

Read the template at `templates/gallery.html` (relative to this skill's repo root). Copy it to `screenshots/gallery-<slug>.html` and customize:

- Replace `Plugin Name` with the subject name in the header `<h1>`
- Replace `Author`, `vX.X`, `Description` in the header `<p>` with metadata
- Replace `/* ACCENT_COLOR */` with a brand-appropriate color (for `.step-num` background and `.flow-label` border)
- Populate sections from the reviewer JSON: one `.flow-group` per section, one `.screen-item` per screenshot
- Add `.ux-note` callouts from annotations (use `.critical`, `.positive`, or default orange for observations)
- For Impact & Opportunity depth, add `.score` spans inside `.ux-note`
- For comparisons, uncomment the `.comparison-section` block and populate from comparator output
- Fill the `.ux-summary` banner from the reviewer's summary bullets

**Critical layout rules:**
- Do NOT add `flex-wrap: wrap` to `.screenshots-row` — screenshots extend horizontally, Figma handles overflow
- Keep `width=2200` viewport for 3+ column sections
- The Figma capture script (`capture.js`) is already in the template — do not remove it

## Local Server & Gallery Verification

Start the local server **once** before the first gallery verification. Keep it alive through Figma import — only kill it in cleanup.

```bash
# Start server (only if not already running)
python3 -m http.server 3000 --directory screenshots/ &

# Before EACH gallery operation, verify it's still alive:
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/gallery-<slug>.html
# If server died, restart it before proceeding
```

**Do NOT skip verification.** Open the gallery in agent-browser, screenshot it, Read the screenshot, and show to the user. **Ask for approval before Figma import.**

## Import to Figma

Only if user provided a Figma file URL.

1. Extract `fileKey` from URL: `figma.com/design/:fileKey/:fileName`
2. Call `mcp__figma__generate_figma_design` with `outputMode: "existingFile"` and `fileKey`
3. Open the gallery URL with capture hash:
   ```bash
   open "http://localhost:3000/gallery-<slug>.html#figmacapture=<captureId>&figmaendpoint=...&figmadelay=3000"
   ```
4. Wait 6 seconds for images to load
5. Poll with captureId until status is "completed"
6. Report the Figma node URL to user

Use `figmadelay=3000` to ensure images load before capture.

## Annotation Reference (for HTML generation)

The reviewer subagent handles annotation logic and rubrics. This section covers only what you need for building the gallery HTML.

**Annotation classes** — map the subagent's `type` field to CSS:

| type | Class | Color |
|------|-------|-------|
| `critical` | `.critical` | Red |
| `observation` | (default) | Orange |
| `positive` | `.positive` | Green |

**For Impact & Opportunity depth**, add score spans and include the rubric legend in `.ux-summary`:

```html
<div class="ux-note critical">
  <span class="tag">Friction</span>
  Onboarding modal has no close button — users who want to explore first are blocked.
  <span class="score">Impact: <span class="high">4</span> · Opportunity: <span class="high">5</span></span>
</div>
```

## Comparison Gallery (Multi-Subject Reviews)

**Only generate if the user requested a comparison.**

After the comparator subagent returns its output, generate a separate HTML page:

- File: `screenshots/gallery-comparison.html`
- Use the comparator's JSON output to populate the comparison table — do NOT invent ratings yourself
- Dimensions come from the comparator (which selects them based on the review objective)
- Ratings use qualitative labels (Poor / Fair / Good / Excellent) with justification text
- Include the comparator's verdict: overall winner, winner per dimension, and top 3 differentiators
- Import to Figma alongside the individual galleries

## Common Mistakes & Troubleshooting

| Mistake | Fix |
|---------|-----|
| Squished columns in Figma | Use `width=2200` viewport, `min-width` on columns |
| Images not loaded in Figma capture | Use `figmadelay=3000` or higher |
| Comparison table rating badges overlap text | Use `display: block` on `.rating` so labels stack above description. Never `display: inline-block`. |
| Full-page screenshot extremely tall | Use chunked capture — see "Screenshot Capture Strategy" section above. Scroll by 2× viewport per chunk, no overlap, stitch in gallery HTML. |
| Images not loaded in screenshots | Always run the scroll-to-bottom + wait-for-images sequence before capturing — see "Wait for Images to Load" above. |
| agent-browser click runs in background/times out | The page likely navigated. Use `open` to navigate to the expected URL instead of waiting for the click. |
| Gallery shows broken image paths | Verify the `src` paths in the HTML match the actual screenshot filenames in the screenshots directory. |
