---
name: wp-plugin-ux-review
description: Use when capturing screenshots of WordPress plugins for UX review, comparing competitor plugin UIs, creating annotated HTML galleries for Figma import, or when the user mentions plugin UX review, competitor analysis, or screenshot galleries.
---

# WP Plugin UX Review

Automate screenshot capture of WordPress plugin UIs, generate annotated HTML galleries, and import to Figma for UX review.

## Quick Reference

| Step | What | Key Decision |
|------|------|-------------|
| **0** | Permissions check | Bypass mode recommended |
| **1** | Choose environment (local vs remote) | Determines WP-CLI availability |
| **2** | Gather ALL user input in one interaction | Objective, plugins, annotations, Figma |
| **3** | Clean slate — deactivate other plugins | Local only |
| **4** | Login via agent-browser | Re-login before each plugin |
| **5** | Discover pages → filter by objective → show user | Filtering happens before any screenshots |
| **6** | Handle interruptions & blockers | First-run gates, wizards, banners |
| **7** | Capture screenshots + journey notes | Deduplicate before dispatching reviewer |
| **7a** | Write review brief | One per plugin |
| **7b** | Dispatch ux-reviewer subagent(s) | Validate manifest counts after |
| **7c** | Dispatch ux-comparator subagent | Multi-plugin only |
| **8** | Generate HTML gallery, verify, get approval | Start server once, keep alive |
| **9** | Import to Figma | Optional |
| **10** | Cleanup | Restore plugins, delete temp user, kill server |

## Step 0: Permissions (DO THIS FIRST — MANDATORY)

This skill is **extremely command-heavy** — dozens of sequential bash commands for browser automation, WP-CLI, local server, and file operations.

**You MUST use AskUserQuestion here and WAIT for the user's response. Do NOT proceed, do NOT run any Bash commands, do NOT explore the codebase, do NOT skip this step. No matter what mode you think you're in, always ask.**

Ask with these three options:

> **Heads up:** This review involves 50+ bash commands (browser automation, WP-CLI, screenshots, local servers). Each one needs manual approval unless you're in bypass mode.
>
> How would you like to proceed?

1. **I've already enabled bypass mode** — proceed immediately
2. **Let me enable it first (Recommended)** — exit, restart with `claude --dangerously-skip-permissions`, then re-invoke the skill
3. **Continue with manual approvals** — I'll approve each command individually (slow but works)

**After the user responds:**
- **Option 1:** Proceed to Step 1.
- **Option 2:** Tell them to run `claude --dangerously-skip-permissions` and re-invoke the skill. **Stop here — do nothing else.**
- **Option 3:** Proceed to Step 1, but warn it will be slow (50+ individual approvals). Do NOT try to set up allowlists.

**Do NOT move to Step 1 until the user has explicitly chosen an option.**

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

## Step 1: Choose Environment

Use AskUserQuestion to determine where the WordPress site lives. This is the **first question** — everything else depends on it.

> **Where is the WordPress site you want to review?**

Options:
1. **Local site** — "I have a local WordPress setup (Local by Flywheel, MAMP, Valet, Docker, etc.)"
2. **Remote/QA site** — "I have a live or staging site with a URL and credentials"

### Path A: Local Site

Ask the user (can be combined with Step 2 questions):

> **Local site details:**
> - Directory path? (e.g., `/Users/jane/Local Sites/my-site` or leave blank if current directory)
> - Do you have admin credentials, or should I create a temporary user?
>   - "Here are my credentials: `username` / `password`"
>   - "Create a temporary user for me" (requires WP-CLI)

Then run prerequisites:

| Check | How | Fix |
|-------|-----|-----|
| **agent-browser** | `which agent-browser` | `npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser` |
| **Figma MCP** | Check for `mcp__figma__get_design_context` or `mcp__figma__generate_figma_design` in available tools (must be the remote Figma MCP, not the Claude AI built-in one) | See install instructions below |
| **Working directory** | Check for `wp-config.php` or `app/public/wp-config.php` in the given path | Ask user for correct path |
| **WP-CLI** | See "WP-CLI Setup" section below | Only needed if creating temp user or managing plugins |
| **Site is running** | `curl -s -o /dev/null -w "%{http_code}" <site-url>` | User must start their local server |

#### Figma MCP Setup (Only if user wants Figma import)

The skill requires the **remote Figma MCP server**, not the Claude AI built-in Figma integration. If the `mcp__figma__generate_figma_design` tool is not available, tell the user to run:

```
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Then restart Claude Code. The remote MCP provides `generate_figma_design` which is needed for the HTML-to-Figma capture workflow. The Claude AI built-in Figma tools (`mcp__claude_ai_Figma__*`) do NOT support this.

#### WP-CLI Setup (Local Sites Only)

WP-CLI setup varies by environment. Detect and configure automatically:

**Try direct WP-CLI first** — works on most setups (Valet, Docker, standard):
```bash
wp option get siteurl --path="<wp-root>"
```
If this works, use `wp` directly for all commands.

**If direct WP-CLI fails, detect the environment:**

**Local by Flywheel:**
1. Read `~/Library/Application Support/Local/graphql-connection-info.json` for auth token
2. Query Local's GraphQL API to find the site ID matching the path
3. Find PHP binary under `~/Library/Application Support/Local/lightning-services/`
4. Find MySQL socket at `~/Library/Application Support/Local/run/<site-id>/mysql/mysqld.sock`
5. WP-CLI command pattern: `"<php-path>" -d "mysqli.default_socket=<socket>" -d "memory_limit=512M" "<wp-cli-path>" <command> --path="<wp-root>"`

**MAMP:**
- PHP at `/Applications/MAMP/bin/php/phpX.X.X/bin/php`
- MySQL socket at `/Applications/MAMP/tmp/mysql/mysql.sock`

**If WP-CLI is not installed:** Download the phar from `https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar`, make it executable, and move to `~/.local/bin/wp`.

#### WP-CLI Wrapper Script (Local Sites Only)

After resolving the WP-CLI command (with PHP path, socket, etc.), write a wrapper script to avoid repeating 200+ character commands:

```bash
# Write wrapper script with resolved paths
cat > screenshots/wp <<'WRAPPER'
#!/bin/bash
"<resolved-php-path>" -d "mysqli.default_socket=<resolved-socket>" -d "memory_limit=512M" "<resolved-wp-cli-path>" "$@" --path="<resolved-wp-root>"
WRAPPER
chmod +x screenshots/wp
```

Test it: `screenshots/wp option get siteurl`. Use `screenshots/wp` for ALL subsequent WP-CLI commands.

#### Discover Site URL (if user didn't provide one)

```bash
<wp-cli-command> option get siteurl --path="<wp-root>"
```

#### Create Automation User (if user chose this option)

```bash
<wp-cli-command> user create claude-reviewer claude@localhost.local --role=administrator --user_pass=claude-ux-review --path="<wp-root>"
```

Credentials: `claude-reviewer` / `claude-ux-review`. Clean up in Step 10.

### Path B: Remote/QA Site

Ask the user (combine with Step 2 questions):

> **Remote site details:**
> - Site URL? (e.g., `https://qa.example.com`)
> - Admin credentials? (username and password)
> - Is the login page at `/wp-login.php` or a custom URL?

**No WP-CLI setup needed.** For remote sites:
- Skip WP-CLI detection entirely
- Skip temp user creation (use their credentials)
- Skip plugin activation/deactivation (the site is already configured how they want it)
- Use agent-browser only for login, navigation, and screenshots
- Do NOT modify anything on the site (no plugin changes, no user creation, no settings changes)

**Important for remote sites:**
- The user's credentials may use 2FA, custom login pages, or SSO — be prepared to handle non-standard login flows via agent-browser
- Some pages may require specific roles/permissions — if a page is inaccessible, note it and move on
- Plugin list comes from the admin UI (Plugins page), not WP-CLI

## Step 2: Gather Remaining User Input (Single Interaction)

Combine these with the environment questions from Step 1 whenever possible. The user should answer everything in **one interaction**, then walk away.

**Question: Plugins to review**
- For **local sites with WP-CLI**: auto-detect installed plugins, show as options
- For **remote sites**: ask the user which plugins to review (they know what's installed)
- Let the user type custom plugin names if not in the list
- For local sites: if a plugin isn't installed, offer to install it via WP-CLI

**Question: Comparison (only if 2+ plugins selected)**
- Ask: "Would you like a side-by-side comparison of these plugins?"
- Options: "Yes — include a comparison table" / "No — just individual reviews"
- If yes, a comparison gallery will be generated after individual reviews using the ux-comparator subagent

**Question: Review objective**
- Ask: "What's the objective for this review?"
- Options:
  - **General review** — capture all screens, note what's working and what isn't (default)
  - **First-time user experience** — "How quickly can a new user get started?" Focus on onboarding, empty states, discoverability, and first-run friction
  - **Upsell & monetization audit** — Focus on upsell density, upgrade prompts, dark patterns, and free-vs-pro boundaries
  - **Specific objective** — free text (e.g., "How easy is it to configure email settings?" or "Can a user set up their first event in under 2 minutes?")

The objective shapes what gets annotated. All annotations should be viewed through the lens of the chosen objective. For example, a "first-time user experience" review would focus annotations on discoverability and guidance, while a "monetization audit" would focus on upsell patterns and friction.

**Question: Figma import**
- Ask: "Do you have a Figma file URL for import?"
- Options: "Yes, I'll paste it" / "Skip Figma import"

**Question: Annotation depth**
- Ask: "How detailed should annotations be?"
- Options:
  - **None** — screenshots only, no annotations (fastest)
  - **Light** — brief colored callouts (positive/critical/observation) with 1-2 sentence descriptions. Points the designer in a direction without being prescriptive.
  - **Impact & Opportunity** — each annotation scored on Impact (1-5) and Opportunity (1-5). Highlights where the biggest business-value improvements are. Best for presenting findings to stakeholders.

**After gathering input, print a summary:**

> **UX Review Plan:**
> - Plugin(s): WPForms, Sugar Calendar Bookings
> - Objective: General review
> - Comparison: Yes
> - Annotations: Light
> - Figma import: Yes (fileKey: XXXXX)
> - Estimated screens: ~10-15 per plugin
>
> I'll now work through the review autonomously. I'll check in when the HTML gallery is ready for your approval before importing to Figma.

This lets the user walk away while work happens.

## Step 3: Clean Slate (Local Sites Only)

**Skip this step for remote/QA sites** — do not modify plugins on remote sites.

For local sites, deactivate ALL other plugins so there are no cross-plugin notices, banners, or conflicts:

```bash
# List all active plugins except the target
<wp-cli-command> plugin list --status=active --field=name --path="<wp-root>"

# Deactivate all except target (use memory_limit to avoid Elementor OOM)
<wp-cli-command> plugin deactivate <other-plugins> --path="<wp-root>"

# Ensure target is active
<wp-cli-command> plugin activate <target-plugin> --path="<wp-root>"
```

**Important:** Always use `-d "memory_limit=512M"` with WP-CLI commands — plugins like Elementor and WooCommerce can exhaust the default 128M during deactivation.

## Step 4: Login via agent-browser

Sessions expire frequently. Always re-login before each plugin.

**Standard WordPress login (`/wp-login.php`):**
```bash
agent-browser --session <session> open "<site-url>/wp-login.php"
agent-browser --session <session> fill "#user_login" "<username>"
agent-browser --session <session> fill "#user_pass" "<password>"
agent-browser --session <session> click "#wp-submit"
```

**For remote sites with custom login:**
- If the user specified a custom login URL, use that instead of `/wp-login.php`
- If the login page looks different (custom theme, SSO redirect), use `snapshot -i` to find the correct form fields and submit button
- If 2FA is required, ask the user to provide the code via AskUserQuestion

**Verify login succeeded** — open the dashboard and check it loads:
```bash
agent-browser --session <session> open "<site-url>/wp-admin/"
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

### Filter by Objective (Non-General Only)

**Skip if the objective is "General review."** Otherwise, review the page list and **remove pages NOT directly relevant to the objective:**

- **"Setting up mailer connections"** — Keep: onboarding, mailer selection, config forms, connection testing, success/failure. Remove: alerts, reporting, tools, about, logs.
- **"First-time user experience"** — Keep: onboarding, wizard, first-run, empty states, dashboard (first view), core feature entry. Remove: advanced settings, tools, addons, about.
- **"Upsell & monetization audit"** — Keep all pages (upsells appear anywhere), but only annotate upsell-related elements.

**Show the filtered list to the user** in the Step 2 summary before any screenshots begin. Aim for **3-5 screenshots per section** — each showing a distinct journey step, not every variation of the same screen.

## Step 5b: Collect Plugin Metadata

Gather metadata for each plugin **before** taking screenshots. This goes into gallery headers and provides context to the ux-reviewer subagent.

**For local sites (WP-CLI available):**
```bash
<wp-cli-command> plugin list --fields=name,version,author,description,status --format=json --path="<wp-root>"
```
Extract the target plugin's version, author, and description from the output.

**For remote sites (no WP-CLI):**
1. Navigate to the Plugins page: `agent-browser --session <session> open "<site-url>/wp-admin/plugins.php"`
2. Use `snapshot -i` to find each target plugin's row
3. Extract version, author, and description from the plugin row text
4. If the Plugins page is inaccessible (permissions), ask the user for plugin versions or note "version unknown"

**Store metadata** for use in:
- Gallery header (`<p>` tag under `<h1>`: "by Author &bull; vX.X &bull; Description")
- Subagent prompt context (passed to both ux-reviewer and ux-comparator)

## Step 6: Handle Interruptions & Blockers

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

### First-Run Gates

Some plugins gate their entire UI behind a welcome/setup screen that won't dismiss via normal clicks. Try these in order:

1. **Direct URL navigation** — Skip the gate by navigating to a known admin page: `agent-browser --session $SESSION open "<site-url>/wp-admin/admin.php?page=<plugin-slug>-settings"`
2. **JS dismiss** — Use `eval` to find and click hidden dismiss/skip elements: `agent-browser --session $SESSION eval "document.querySelector('[class*=skip], [class*=dismiss], [class*=close]')?.click()"`
3. **WP-CLI option bypass** — Set the plugin's "setup complete" flag directly: `screenshots/wp option update <plugin_slug>_setup_complete 1` (check the plugin's options table for the exact key)
4. **Capture as UX observation** — If none of the above work, capture the gate screen itself. A first-run screen that blocks access is a legitimate UX finding.

### Wizard Progression

Wizards that validate fields before advancing (e.g., requiring SMTP credentials):

1. **Fill dummy values** — Use plausible-looking test data (e.g., `smtp.example.com`, port `587`, `test@example.com`). The goal is to reach subsequent screens, not to configure a working connection.
2. **WP-CLI option bypass** — Set the wizard's step/completion option directly to jump past validation: `screenshots/wp option update <plugin_slug>_wizard_step 99`
3. **Capture the validation state** — If the wizard won't advance, capture the error/validation state as a UX observation. A wizard that demands real credentials before letting users explore is itself a UX finding worth annotating.

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

**Journey notes:** As you capture each screenshot, write a brief journey note describing what you observed while navigating to and interacting with that screen. These notes capture experiential context that static screenshots cannot — the subagent hasn't used the product, so these notes are its only window into the navigation experience. Record things like:
- How many clicks/steps to reach this screen
- Modals, banners, or interruptions you had to dismiss
- Elements that didn't work as expected (broken clicks, JS workarounds needed)
- Missing feedback (no success message after save, no loading indicator)
- Confusing navigation (tab label doesn't match URL, feature buried in unexpected place)
- Load time issues or rendering problems
- What you expected to see vs. what actually appeared

Keep each note to 1-3 sentences. Factual observations, not analysis — the subagent does the analysis.

### Deduplicate Screenshots

Before writing the review brief, list all captured screenshots and Read any with similar names or sequential numbers that might be duplicates (e.g., `06-welcome.png` and `07-welcome-retry.png`). Delete near-duplicates — keep the cleanest capture. This prevents the reviewer subagent from annotating the same screen multiple times.

## Step 7a: Write Review Brief

After all screenshots are captured for a plugin, write a **review brief** markdown file that consolidates everything the subagent needs. This file is the primary context document — it pairs the screenshots with the experiential knowledge you gained from navigating the product.

**File:** `screenshots/<plugin-slug>/review-brief.md`

**Template:**

```markdown
# Review Brief: <Plugin Name> v<Version>

## Objective
<Exact objective text from Step 2>

## Annotation Depth
<"light" or "impact-opportunity">

## Plugin Metadata
- **Name:** <name>
- **Author:** <author>
- **Version:** <version>
- **Description:** <description>

## Environment
- **Type:** <local or remote>
- **Site URL:** <url>

## Navigation Structure (Full)
<Numbered list of ALL pages/tabs discovered in Step 5>

## Filtered Scope
<If Step 5c filtered pages, list only the pages kept and briefly note why others were excluded. If "General review", write "No filtering — all pages captured.">

## Screenshots & Journey Notes

### 01-mailer-selection.png
**Screen:** <What this screen shows>
**Journey:** <1-3 sentences of what you observed navigating to/interacting with this screen>

### 02-sendgrid-config.png
**Screen:** <What this screen shows>
**Journey:** <1-3 sentences>

<!-- Continue for every screenshot -->
```

**This file serves three purposes:**
1. **Subagent context** — the subagent reads this before analyzing screenshots, so it understands the navigation experience
2. **User review** — the user can skim it to verify scope before the subagent runs
3. **Audit trail** — documents what was captured and why, useful if the review is revisited later

## Step 7b: UX Review (Subagent)

After all screenshots are captured for a plugin, dispatch a **general-purpose** subagent to analyze them using the ux-reviewer prompt template. Do NOT analyze screenshots yourself — delegate to the agent.

**Before dispatching, inform the user:**

> Dispatching UX review agents now. No action needed on your side — I'll check in when the galleries are ready for your approval.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"` (there is no custom ux-reviewer type)
- **Prompt:** Paste the full content of `agents/ux-reviewer.md` into the prompt, then tell the agent to:
  1. **Read the review brief** at `screenshots/<plugin-slug>/review-brief.md` (written in Step 7a) — this contains the objective, metadata, navigation structure, and journey notes per screenshot
  2. **Read each screenshot PNG** listed in the review brief using the Read tool
  3. **Analyze and return annotations** per the ux-reviewer instructions

The review brief is the subagent's primary context document. It contains everything the subagent needs to understand the plugin beyond what the screenshots show — the navigation experience, the objective, the scope decisions, and per-screen observations from actually using the product.

**For multi-plugin reviews:** Dispatch one agent per plugin in parallel. Each agent analyzes one plugin's screenshots independently.

The agent returns:
- **Status:** `DONE | DONE_WITH_CONCERNS | BLOCKED` (see agents/ux-reviewer.md for details)
- A JSON array of screenshots with annotations, grouped into sections
- An overall summary for the gallery banner (3-5 bullet executive summary covering: key strengths, key weaknesses, and recommended priorities)

**Handling agent status:**
- **DONE:** Proceed to validation below.
- **DONE_WITH_CONCERNS:** Read the concerns. If screenshots appeared irrelevant to the objective, that's a signal Step 5 filtering was incomplete — note it but proceed. If the agent couldn't read images, re-dispatch.
- **BLOCKED:** The agent couldn't complete analysis. Check if screenshots are readable (Read the PNGs yourself). If images are fine, re-dispatch with more context.

**Post-subagent validation:** The reviewer returns a `manifest` object with `screenshots_reviewed` and `screenshots_with_annotations` counts. Before using the output:
1. **Check manifest counts** — `screenshots_reviewed` must equal the number of PNGs captured. If not, re-dispatch for the missing screenshots.
2. Spot-check 2-3 annotations for objective relevance
3. Verify section groupings make sense for the gallery layout
4. If annotations reference off-topic screens, remove those entries

Use the validated output to populate annotations in the HTML gallery (Step 8).

**If annotation depth is "none":** Skip this step entirely — go straight to Step 8 with screenshots only.

## Step 7c: UX Comparison (Subagent — Multi-Plugin Only)

**Only run this step if the user requested a comparison in Step 2.**

After ALL ux-reviewer agents have completed, dispatch a **general-purpose** subagent using the ux-comparator prompt template. This agent does text reasoning on structured JSON — no vision needed, so it can use a faster model.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"` (there is no custom ux-comparator type)
- `model`: `"sonnet"` (comparator is text-only reasoning on structured JSON — doesn't need the most capable model)
- **Prompt:** Paste the full content of `agents/ux-comparator.md` into the prompt, followed by all context below. Do NOT tell the agent to read the file — inline everything.
- Provide in the prompt:
  1. **All plugin annotations** — the full validated JSON output from each ux-reviewer agent
  2. **Review brief paths** — tell the agent to read each plugin's `screenshots/<plugin-slug>/review-brief.md` for metadata, navigation structure, and journey notes
  3. **Review objective** — the exact objective text from Step 2
  4. **Annotation depth** — from Step 2

The agent returns:
- A comparison table with per-dimension ratings and justifications
- A verdict with winner-per-dimension, overall winner, and top differentiators

Use this output to build the comparison gallery in Step 8.

## Step 8: Generate HTML Gallery

Read the template at `templates/gallery.html` (relative to this skill's repo root). Copy it to `screenshots/gallery-<plugin-slug>.html` and customize:

- Replace `Plugin Name`, `Author`, `vX.X`, `Description` in the header
- Replace `/* ACCENT_COLOR */` with the plugin's brand color (for `.step-num` background and `.flow-label` border)
- Populate sections from the ux-reviewer JSON: one `.flow-group` per section, one `.screen-item` per screenshot
- Add `.ux-note` callouts from annotations (use `.critical`, `.positive`, or default orange for observations)
- For Impact & Opportunity depth, add `.score` spans inside `.ux-note`
- For comparisons, uncomment the `.comparison-section` block and populate from ux-comparator output
- Fill the `.ux-summary` banner from the reviewer's summary bullets

**Critical layout rules:**
- Do NOT add `flex-wrap: wrap` to `.screenshots-row` — screenshots extend horizontally, Figma handles overflow
- Keep `width=2200` viewport for 3+ column sections
- The Figma capture script (`capture.js`) is already in the template — do not remove it

### Local Server & Gallery Verification

Start the local server **once** before the first gallery verification. Keep it alive through Figma import — only kill it in Step 10.

```bash
# Start server (only if not already running)
python3 -m http.server 3000 --directory screenshots/ &

# Before EACH gallery operation, verify it's still alive:
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/gallery-$PLUGIN_SLUG.html
# If server died, restart it before proceeding
```

**Do NOT skip verification.** Open the gallery in agent-browser, screenshot it, Read the screenshot, and show to the user. **Ask for approval before Figma import.**

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

Cleanup depends on the environment chosen in Step 1.

**Local site:**
```bash
# Delete temp user (only if we created one)
<wp-cli-command> user delete claude-reviewer --reassign=1 --path="<wp-root>"

# Reactivate originally active plugins
<wp-cli-command> plugin activate <originally-active-plugins> --path="<wp-root>"

# Kill local HTTP server if started for gallery preview
kill %1 2>/dev/null
```

**Remote/QA site:**
```bash
# Nothing to clean up — we didn't modify the site
# Just kill the local HTTP server if started for gallery preview
kill %1 2>/dev/null
```

## UX Annotation Reference (for HTML generation)

The ux-reviewer subagent handles annotation logic and rubrics. This section covers only what you need for building the gallery HTML.

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

## Comparison Conclusion (Multi-Plugin Reviews)

**Only generate if the user requested a comparison in Step 2.**

After the ux-comparator subagent returns its output (Step 7c), generate a separate HTML page:

- File: `screenshots/gallery-comparison.html`
- Use the ux-comparator's JSON output to populate the comparison table — do NOT invent ratings yourself
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
| Guessed tab URL slug from visible label | Extract actual `href` from DOM — slugs often differ from display names. Use `eval`: `agent-browser --session $SESSION eval "Array.from(document.querySelectorAll('[class*=nav-menu] a, .nav-tab-wrapper a')).map(a => a.textContent.trim() + ' → ' + a.href).join('\\n')"` |
| Full-page screenshot extremely tall | Use viewport-only capture (no `--full`) for long scrollable lists. If `Read` fails on the PNG, recapture without `--full`. |
| agent-browser click runs in background/times out | The page likely navigated. Use `open` to navigate to the expected URL instead of waiting for the click. |
| Subagent annotates off-topic screens | Objective filtering missed pages. Re-check Step 5 filtering and that the review brief includes the exact objective. |

### SPA / JavaScript Framework Troubleshooting

Plugins built with Vue (Element UI, Fluent UI), React, or other SPA frameworks often break standard agent-browser interactions:

| Problem | Solution |
|---------|----------|
| `click` on Vue/React elements times out or does nothing | Use `eval` to click via JS: `agent-browser --session $SESSION eval "document.querySelector('.target-selector').click()"` |
| `fill` doesn't trigger Vue reactivity | Use `eval` with `dispatchEvent`: `agent-browser --session $SESSION eval "const el = document.querySelector('input'); el.value = 'test'; el.dispatchEvent(new Event('input', {bubbles: true}))"` |
| Element UI radio buttons / custom controls | Target the inner clickable element: `eval "document.querySelector('.el-radio-button__inner').click()"` |
| Hash-based routing (no page reload on nav) | Use `open` with the full hash URL rather than clicking nav links |
| Content loads after JS render | Add a short wait after navigation: `agent-browser --session $SESSION eval "await new Promise(r => setTimeout(r, 2000))"` then `snapshot -i` |
