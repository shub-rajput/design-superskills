---
name: wp-plugin-ux-review
description: Use when capturing screenshots of WordPress plugins for UX review, comparing competitor plugin UIs, creating annotated HTML galleries for Figma import, or when the user mentions plugin UX review, competitor analysis, or screenshot galleries.
---

# WP Plugin UX Review

Automate screenshot capture of WordPress plugin UIs, generate annotated HTML galleries, and import to Figma for UX review.

## Step 0: Permissions (DO THIS FIRST)

This skill is **extremely command-heavy** — dozens of sequential bash commands for browser automation, WP-CLI, local server, and file operations. Without permission bypass, the user must manually approve every single one, which makes the workflow unusable.

**First, detect if bypass mode is already enabled** by running a quick test:
```bash
# If this runs without prompting, bypass is on
echo "bypass-check"
```
If the command executes immediately without a permission prompt, bypass is already active — skip straight to Step 1.

**If bypass is NOT detected**, show this message and use AskUserQuestion with three options:

1. **Already enabled** — "I already have bypass mode on" (proceed immediately)
2. **Restart with bypass (Recommended)** — user exits, restarts with `claude --dangerously-skip-permissions`, then re-invokes the skill
3. **Continue with manual approvals** — proceed but warn it will be slow (50+ approvals)

**If user chooses to continue without bypass:** Do NOT try to set up allowlists (they require a restart anyway and the patterns are too complex to cover all commands). Just proceed and let them approve each command.

**Only move to Step 1 after the user confirms they are ready to proceed.**

## CRITICAL: No Shell Variables in Bash Commands

Claude Code flags commands containing `$VARIABLE` syntax (like `$HOME`, `$PHP_BIN`, `$SOCKET`) as requiring **extra** manual approval for shell expansion — even in bypass mode this adds friction.

**Rule: Always use fully resolved, literal paths in every Bash command. Never use `$HOME`, `$PHP_BIN`, `$SOCKET`, `$WP_CLI`, `$WP_PATH`, or any other shell variable.**

```bash
# WRONG — triggers extra "shell expansion" approval prompt:
ls "$HOME/Library/Application Support/Local/lightning-services/"
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" "$WP_CLI" plugin list --path="$WP_PATH"

# CORRECT — uses resolved paths, minimal prompts:
ls "/Users/jane/Library/Application Support/Local/lightning-services/"
"/Users/jane/.../php" -d "mysqli.default_socket=/Users/jane/.../mysqld.sock" "/Users/jane/.local/bin/wp" plugin list --path="/Users/jane/Local Sites/my-site/app/public"
```

Discover paths in Step 1 (WP-CLI Setup), then inline the resolved values in every subsequent command. The examples in this skill use `$PHP_BIN` etc. for readability — always substitute actual paths when running commands.

Also avoid chaining commands with `||` and `&&` — these trigger "shell operators" approval. Use separate sequential Bash calls instead.

## Step 1: Prerequisites

Run these checks. All must pass before proceeding:

| Check | How | Fix |
|-------|-----|-----|
| **agent-browser** | `which agent-browser` | `npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser` |
| **Figma MCP** | Check for `mcp__figma__get_design_context` or `mcp__figma__generate_figma_design` in available tools | User must configure Figma MCP server |
| **Working directory** | Check for `wp-config.php` or `app/public/wp-config.php` | Must `cd` into the WordPress site directory |
| **WP-CLI** | See "WP-CLI Setup" section below | Install and configure |
| **Site is running** | `curl -s -o /dev/null -w "%{http_code}" "$SITE_URL"` | Start the Local site or web server |

### WP-CLI Setup

WP-CLI setup varies by environment. Detect and configure automatically:

**For Local by Flywheel sites:**

1. Find the site's ID and MySQL socket via Local's GraphQL API:
   ```bash
   # Read Local's connection info
   cat "$HOME/Library/Application Support/Local/graphql-connection-info.json"
   # Query for site details — match by path
   curl -s "http://127.0.0.1:4000/graphql" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $AUTH_TOKEN" \
     -d '{"query":"{ sites { id name path } }"}'
   ```

2. Find the PHP binary and MySQL socket:
   ```bash
   # List available PHP versions
   ls "$HOME/Library/Application Support/Local/lightning-services/" | grep php
   # Find the PHP binary (use the latest version)
   find "$HOME/Library/Application Support/Local/lightning-services/php-VERSION/bin" -name "php" -type f
   # Socket is at:
   # $HOME/Library/Application Support/Local/run/$SITE_ID/mysql/mysqld.sock
   ```

3. Test the connection:
   ```bash
   "$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" option get siteurl --path="$WP_PATH"
   ```

4. **Define a shell function** to avoid repeating the long command. Set these variables and reuse throughout:
   ```bash
   PHP_BIN="<discovered path>"
   SOCKET="<discovered socket>"
   WP_CLI="$HOME/.local/bin/wp"  # or wherever wp-cli.phar is
   WP_PATH="<site>/app/public"
   ```
   Then every WP-CLI call becomes:
   ```bash
   "$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" <command> --path="$WP_PATH"
   ```

**If WP-CLI is not installed:**
```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mkdir -p "$HOME/.local/bin"
mv wp-cli.phar "$HOME/.local/bin/wp"
```

**For non-Local environments (standard server, MAMP, etc.):**
- Just use `wp` directly if it's in PATH
- Or use the PHP binary with wp-cli.phar

### Discover Site URL

Do NOT hardcode URLs. Discover from WP-CLI:
```bash
# Use the WP-CLI command pattern established above
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" option get siteurl --path="$WP_PATH"
```

### Create Automation User

Create a temporary admin user for browser automation so we don't need the user's credentials:
```bash
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" user create claude-reviewer claude@localhost.local --role=administrator --user_pass=claude-ux-review --path="$WP_PATH"
```

Store credentials in variables:
```bash
WP_USER="claude-reviewer"
WP_PASS="claude-ux-review"
```

**Clean up at the end of the workflow** (see Step 9).

## Step 2: Gather ALL User Input (Single Interaction)

Ask ALL questions in ONE AskUserQuestion call. The user should only need to answer once, then walk away.

**Questions to ask (use AskUserQuestion with up to 4 questions):**

**Question 1: Plugins to review**
- First, auto-detect installed plugins and show them as options
- Let the user select from installed plugins OR type custom ones
- If a plugin isn't installed, offer to install it

**Question 2: Review objective**
- Ask: "What's the objective for this review?"
- Options:
  - **General review** — capture all screens, note what's working and what isn't (default)
  - **First-time user experience** — "How quickly can a new user get started?" Focus on onboarding, empty states, discoverability, and first-run friction
  - **Upsell & monetization audit** — Focus on upsell density, upgrade prompts, dark patterns, and free-vs-pro boundaries
  - **Specific objective** — free text (e.g., "How easy is it to configure email settings?" or "Can a user set up their first event in under 2 minutes?")

The objective shapes what gets annotated. All annotations should be viewed through the lens of the chosen objective. For example, a "first-time user experience" review would focus annotations on discoverability and guidance, while a "monetization audit" would focus on upsell patterns and friction.

**Question 3: Figma import**
- Ask: "Do you have a Figma file URL for import?"
- Options: "Yes, I'll paste it" / "Skip Figma import"

**Question 4: Annotation depth**
- Ask: "How detailed should annotations be?"
- Options:
  - **None** — screenshots only, no annotations (fastest)
  - **Light** — brief colored callouts (positive/critical/observation) with 1-2 sentence descriptions. Points the designer in a direction without being prescriptive.
  - **Impact & Opportunity** — each annotation scored on Impact (1-5) and Opportunity (1-5). Highlights where the biggest business-value improvements are. Best for presenting findings to stakeholders.

If multiple plugins are selected, always generate a comparison table (no need to ask).

**After gathering input, print a summary:**

> **UX Review Plan:**
> - Plugin(s): Sugar Calendar Lite v3.10.1
> - Objective: General review
> - Annotations: Light
> - Figma import: Yes (fileKey: XXXXX)
> - Estimated screens: ~10-15
>
> I'll now work through the review autonomously. I'll check in when the HTML gallery is ready for your approval before importing to Figma.

This lets the user walk away while work happens.

## Step 3: Clean Slate

Deactivate ALL other plugins so there are no cross-plugin notices, banners, or conflicts:

```bash
# List all active plugins except the target
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" plugin list --status=active --field=name --path="$WP_PATH"

# Deactivate all except target (use memory_limit to avoid Elementor OOM)
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" plugin deactivate $OTHER_PLUGINS --path="$WP_PATH"

# Ensure target is active
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" plugin activate $TARGET_PLUGIN --path="$WP_PATH"
```

**Important:** Always use `-d "memory_limit=512M"` — plugins like Elementor and WooCommerce can exhaust the default 128M during deactivation.

## Step 4: Login via agent-browser

Sessions expire frequently. Always re-login before each plugin:

```bash
agent-browser --session $SESSION open "$SITE_URL/wp-login.php"
agent-browser --session $SESSION fill "#user_login" "$WP_USER"
agent-browser --session $SESSION fill "#user_pass" "$WP_PASS"
agent-browser --session $SESSION click "#wp-submit"
```

**Verify login succeeded** — check the page title contains "Dashboard":
```bash
agent-browser --session $SESSION open "$SITE_URL/wp-admin/"
```

## Step 5: Discover Plugin Pages

Do NOT hardcode menu URLs. After login, use snapshot to find the plugin's menu:

```bash
agent-browser --session $SESSION open "$SITE_URL/wp-admin/"
agent-browser --session $SESSION snapshot -i 2>&1 | grep -i "plugin-keyword"
```

Click the main menu item, then snapshot again to find all sub-pages/tabs.

**Clicking elements by ref:** Use bracket syntax `[ref=e21]`, NOT `@ref=e21`:
```bash
# CORRECT:
agent-browser --session $SESSION click "[ref=e21]"

# WRONG (will throw CSS parse error):
agent-browser --session $SESSION click "@ref=e21"
```

**When `text=` matches multiple elements:** Use `snapshot -i` to get specific `[ref=XX]` IDs, then click by ref.

**Build a list of all pages/tabs to capture** before starting screenshots. Example:
```
1. Events list (main page)
2. Add New Event
3. Calendars
4. Tickets
5. Venues
6. Speakers
7. RSVP
8. Settings (+ each settings tab)
9. Tools
10. Addons
```

## Step 6: Handle Interruptions

Dismiss these BEFORE taking screenshots:

| Interruption | Solution |
|-------------|----------|
| Freemius opt-in | Find "Skip" link via `snapshot -i`, click by `[ref=XX]` |
| Email verification | Click `[ref=XX]` for "The email is correct" |
| Review nag banners | Click dismiss button by `[ref=XX]` |
| Import from other plugin | Click "Skip" or "Got it" by `[ref=XX]` |
| Update notices | Click dismiss by `[ref=XX]` |
| Upgrade/upsell banners | Dismiss or note for annotation |

**Always use `snapshot -i`** to discover the correct ref before clicking. Never guess selectors.

## Step 7: Capture Screenshots

Create the screenshots directory:
```bash
mkdir -p screenshots/$PLUGIN_SLUG
```

For each screen/tab:
```bash
agent-browser --session $SESSION screenshot screenshots/$PLUGIN_SLUG/XX-description.png --full
```

**Rules:**
- Use `--full` flag for full-page capture **UNLESS the page is a long scrollable list** (addons galleries, template libraries, integration lists, etc.). For those, use viewport-only (no `--full`) to avoid extremely tall screenshots that become unreadable at gallery scale.
- Naming: `XX-description.png` (01-events-list.png, 02-add-new-event.png, etc.)
- Save to `screenshots/<plugin-slug>/` directory
- After each screenshot, `Read` the PNG file to verify it captured correctly (Claude can view images). If the Read fails due to image dimensions exceeding limits, the screenshot is too tall — recapture without `--full`.
- If a page has tabs, capture each tab as a separate screenshot
- If a page has modals or dropdowns worth showing, open them and capture separately
- If focused on specific flows, only capture screens relevant to those flows

**If the user specified focus areas**, prioritize those screens and add more detail (e.g., capture different states, empty vs populated, error states).

## Step 8: Generate HTML Gallery

**Layout rules:**
- Sections (Onboarding, Settings, Events, etc.) stacked **vertically**
- Screenshots within each section laid out **horizontally** (side-by-side)
- All flexbox for Figma auto-layout compatibility
- Viewport `width=2200` for 3+ column sections
- Include Figma capture script
- Replace `$ACCENT_COLOR` with the plugin's actual brand color

**HTML template:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=2200">
<title>Plugin Name — UX Review</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #F5F5F5; font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 60px; }

  /* Outer wrapper: hug content width */
  .gallery-wrapper { display: inline-flex; flex-direction: column; gap: 12px; }

  /* Header: fills wrapper width */
  .section-header { background: #1E1E1E; color: white; padding: 24px 32px; border-radius: 12px; align-self: stretch; }
  .section-header h1 { font-size: 28px; font-weight: 700; }
  .section-header p { font-size: 14px; color: #999; margin-top: 4px; }

  /* Optional: UX summary banner */
  .ux-summary { background: #FFF8E1; border: 1px solid #FFD54F; border-radius: 8px; padding: 16px 20px; margin-bottom: 20px; font-size: 13px; color: #5D4037; line-height: 1.6; align-self: stretch; }

  /* Sections stack vertically, fill wrapper width */
  .sections-container { display: flex; flex-direction: column; gap: 48px; align-self: stretch; }

  .flow-group { }
  .flow-label { font-size: 18px; font-weight: 600; color: #333; margin-bottom: 16px; border-left: 4px solid /* ACCENT_COLOR */; padding: 4px 0 4px 12px; }

  /* Screenshots within section: horizontal */
  .screenshots-row { display: flex; gap: 24px; align-items: flex-start; }

  .screen-item { width: 420px; flex-shrink: 0; }

  /* Title ABOVE screenshot */
  .screen-title { padding: 10px 4px 8px; font-size: 13px; font-weight: 500; color: #555; }
  .step-num { display: inline-block; background: /* ACCENT_COLOR */; color: white; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 4px; margin-right: 8px; }

  .screenshot-card { background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); overflow: hidden; }
  .screenshot-card img { width: 100%; display: block; }

  /* UX annotation callouts — vertically stacked label + description */
  .ux-notes { display: flex; flex-direction: column; gap: 10px; margin-top: 10px; }
  .ux-note { display: flex; flex-direction: column; gap: 3px; background: #FFF3E0; border-left: 3px solid #FB8C00; border-radius: 0 6px 6px 0; padding: 8px 10px; font-size: 11px; line-height: 1.45; color: #4E342E; }
  .ux-note.positive { background: #E8F5E9; border-left-color: #43A047; color: #1B5E20; }
  .ux-note.critical { background: #FFEBEE; border-left-color: #E53935; color: #B71C1C; }
  .ux-note .tag { font-weight: 700; font-size: 10px; text-transform: uppercase; letter-spacing: 0.3px; }

  /* Comparison conclusion section (optional) */
  .comparison-section { background: white; border-radius: 12px; padding: 32px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); align-self: stretch; }
  .comparison-section h2 { font-size: 22px; font-weight: 700; margin-bottom: 16px; }
  .comparison-table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .comparison-table th { text-align: left; padding: 10px 12px; background: #F5F5F5; font-weight: 600; border-bottom: 2px solid #ddd; }
  .comparison-table td { padding: 10px 12px; border-bottom: 1px solid #eee; vertical-align: top; }
  /* Rating labels — stacked above description text, never inline */
  .rating { display: block; font-size: 11px; font-weight: 700; margin-bottom: 4px; }
  .rating.excellent { color: #2E7D32; }
  .rating.good { color: #1565C0; }
  .rating.fair { color: #F57F17; }
  .rating.poor { color: #C62828; }

  /* Impact/Opportunity annotation variant */
  .ux-note .score { font-weight: 700; font-size: 10px; color: #555; margin-top: 2px; }
  .ux-note .score .high { color: #2E7D32; }
  .ux-note .score .low { color: #999; }
</style>
<script src="https://mcp.figma.com/mcp/html-to-design/capture.js" async></script>
</head>
<body>

<div class="gallery-wrapper">

<div class="section-header">
  <h1>Plugin Name — UX Review</h1>
  <p>by Author &bull; vX.X &bull; Description</p>
</div>

<!-- Optional UX summary -->
<div class="ux-summary"><strong>Overall:</strong> Summary here.</div>

<div class="sections-container">

  <div class="flow-group">
    <div class="flow-label">Section Name</div>
    <div class="screenshots-row">
      <div class="screen-item">
        <div class="screen-title"><span class="step-num">1</span>Screen Title</div>
        <div class="screenshot-card">
          <img src="plugin-slug/01-screen.png" alt="Screen">
        </div>
        <!-- Optional UX notes -->
        <div class="ux-notes">
          <div class="ux-note critical">
            <span class="tag">Issue</span>
            Description of the issue here.
          </div>
          <div class="ux-note positive">
            <span class="tag">Good</span>
            Description of what works well.
          </div>
        </div>
      </div>
      <!-- More screen-items horizontally -->
    </div>
  </div>

  <!-- More flow-groups stacked vertically -->

</div>

<!-- Optional: Comparison Conclusion (when reviewing multiple plugins) -->
<!--
<div class="comparison-section">
  <h2>Comparison Conclusion</h2>
  <table class="comparison-table">
    <tr><th>Aspect</th><th>Plugin A</th><th>Plugin B</th><th>Plugin C</th></tr>
    <tr><td>Onboarding</td><td>...</td><td>...</td><td>...</td></tr>
    <tr><td>Settings UX</td><td>...</td><td>...</td><td>...</td></tr>
    <tr><td>Email Logs</td><td>...</td><td>...</td><td>...</td></tr>
    <tr><td>Upsell Approach</td><td>...</td><td>...</td><td>...</td></tr>
    <tr><td>Overall Score</td><td>...</td><td>...</td><td>...</td></tr>
  </table>
</div>
-->

</div><!-- /gallery-wrapper -->

</body>
</html>
```

**Accent colors** — pick a unique color per plugin based on their brand. Use the plugin's primary brand color for `.step-num` background and `.flow-label` border.

### Verify HTML Before Figma Import

**Do NOT skip this step.** Open the gallery in agent-browser, screenshot it, and show to user:

```bash
# Start a local server for the screenshots directory
python3 -m http.server 3000 --directory screenshots/ &

# Verify server is running
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/gallery-$PLUGIN_SLUG.html

# Open and screenshot the gallery
agent-browser --session verify open "http://localhost:3000/gallery-$PLUGIN_SLUG.html"
agent-browser --session verify screenshot /tmp/gallery-preview-$PLUGIN_SLUG.png --full
```

Read the screenshot and show to user. **Ask for approval before Figma import.**

## Step 9: Import to Figma

Only if user provided a Figma file URL.

1. Extract `fileKey` from URL: `figma.com/design/:fileKey/:fileName`
2. Call `mcp__figma__generate_figma_design` with `outputMode: "existingFile"` and `fileKey`
3. Open the gallery URL with capture hash:
   ```bash
   open "http://localhost:3000/gallery-$PLUGIN_SLUG.html#figmacapture=$CAPTURE_ID&figmaendpoint=...&figmadelay=3000"
   ```
4. Wait 6 seconds for images to load
5. Poll with captureId until status is "completed"
6. Report the Figma node URL to user

Use `figmadelay=3000` to ensure images load before capture.

## Step 10: Cleanup

After all plugins are reviewed:

```bash
# Delete the temporary automation user
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" user delete claude-reviewer --reassign=1 --path="$WP_PATH"

# Reactivate the plugins that were originally active
"$PHP_BIN" -d "mysqli.default_socket=$SOCKET" -d "memory_limit=512M" "$WP_CLI" plugin activate $ORIGINALLY_ACTIVE_PLUGINS --path="$WP_PATH"

# Kill local server if started
kill %1 2>/dev/null
```

## UX Annotation Guide

The primary deliverable is screenshots. Annotations are supplementary — they point the designer in a direction, not prescribe solutions.

### Annotation Principles

- **Write for designers, not developers.** Focus on what the user experiences, not how to fix it.
- **Be brief.** 1-2 sentences max per note. If you need more, the observation is too complex — split it.
- **Filter through the objective.** If the user chose "first-time user experience", don't annotate advanced settings quirks. Stay on-topic.
- **Don't annotate everything.** 2-4 annotations per screenshot is plenty. Zero is fine for straightforward screens.

### Light Annotations

Color-coded callouts with a tag and brief description:

| Type | Class | Color | Use For |
|------|-------|-------|---------|
| Critical | `.critical` | Red | Blockers, dark patterns, data-loss risk |
| Observation | (default) | Orange | Friction, copy issues, layout concerns |
| Positive | `.positive` | Green | Good patterns worth noting |

**Tag** (1-2 words): `Friction`, `Overload`, `Copy`, `CTA`, `Layout`, `Upsell`, `Clean`, `Good`, `Navigation`, `Empty State`

### Impact & Opportunity Annotations

Same color-coded callouts, plus a score line. Scores follow these rubrics:

**Impact — How much does this affect the business?**

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Critical | Directly loses users, revenue, or trust. Users abandon or churn. |
| 4 | High | Hurts activation or conversion. Users get stuck or frustrated enough to seek alternatives. |
| 3 | Moderate | Creates friction that increases support load or slows adoption. Users notice but push through. |
| 2 | Low | Minor annoyance. Doesn't change behavior but leaves a negative impression. |
| 1 | Cosmetic | Polish item. No measurable business effect. |

**Opportunity — How much value can be captured with how little effort?**

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Quick win | Copy change, add a link, CSS fix. Hours of work, immediate user benefit. |
| 4 | Easy | Small UI addition or restructure. A day or two, clear ROI. |
| 3 | Moderate | New component or flow change. A sprint, measurable improvement expected. |
| 2 | Heavy | Significant rebuild or new feature. Multiple sprints, ROI less certain. |
| 1 | Major | Architecture change or external dependency. Quarter+, speculative payoff. |

Only annotate items where **Impact + Opportunity >= 7** — these are the high-value improvements worth presenting to stakeholders.

Include the rubric tables as a legend at the top of the gallery (inside `.ux-summary`) so anyone reading the review understands what the scores mean.

```html
<div class="ux-note critical">
  <span class="tag">Friction</span>
  Onboarding modal has no close button — users who want to explore first are blocked.
  <span class="score">Impact: <span class="high">4</span> · Opportunity: <span class="high">5</span></span>
</div>
```

## Comparison Conclusion (Multi-Plugin Reviews)

When the user opts for comparison, generate a separate HTML page **after all plugins are captured**:

- File: `screenshots/gallery-comparison.html`
- Include a comparison table rating each plugin across key UX dimensions
- Dimensions: Onboarding, Settings Organization, Core Feature UX, Empty States, Upsell Approach, Visual Polish, Navigation, Overall Score
- Use a 1-5 scale or qualitative labels (Poor / Fair / Good / Excellent)
- Add a brief written summary highlighting the winner per category and overall
- Import to Figma alongside the individual galleries

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Session expired mid-capture | Re-login before each plugin |
| Other plugin notices in screenshots | Deactivate ALL others first |
| `text=X` matches multiple elements | Use `snapshot -i` to get `[ref=XX]` IDs |
| Using `@ref=e21` syntax | Use `[ref=e21]` bracket syntax instead |
| Squished columns in Figma | Use `width=2200` viewport, `min-width` on columns |
| Images not loaded in Figma capture | Use `figmadelay=3000` or higher |
| Local server not running | Check with `curl` before opening capture URL |
| Gallery layout broken | Verify with agent-browser screenshot BEFORE Figma import |
| WP-CLI memory exhaustion | Always use `-d "memory_limit=512M"` |
| Asking user questions across multiple interactions | Gather ALL input in Step 2 in a single AskUserQuestion |
| Not cleaning up temp user | Always delete claude-reviewer user in Step 10 |
| Allowlist doesn't take effect | Requires restart — recommend bypass mode instead |
| Guessed tab URL slug from visible label | Extract actual `href` from DOM — slugs often differ from display names (e.g. "Smart Routing" → `tab=routing`, "Email Controls" → `tab=control`). Use `eval` to extract: `agent-browser --session $SESSION eval "Array.from(document.querySelectorAll('[class*=nav-menu] a, .nav-tab-wrapper a')).map(a => a.textContent.trim() + ' → ' + a.href).join('\\n')"` |
| Full-page screenshot extremely tall (addons, templates, integrations) | Use viewport-only capture (no `--full`) for pages with long scrollable lists. If `Read` fails on the PNG due to dimension limits, recapture without `--full`. |
| Comparison table rating badges overlap text | Use `display: block` on `.rating` so labels stack above description text. Never use `display: inline-block` for ratings in table cells. |
