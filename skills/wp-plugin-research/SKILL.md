---
name: wp-plugin-research
description: Use when capturing screenshots of WordPress plugins for UX review, comparing competitor plugin UIs, creating annotated HTML galleries for Figma import, or when the user mentions plugin UX review, competitor analysis, or screenshot galleries.
---

# WP Plugin Research

Automate screenshot capture of WordPress plugin UIs, generate annotated HTML galleries, and import to Figma for UX review.

**Shared reference:** Read `shared/common-steps.md` for permissions, shell variable rules, Figma MCP setup, gallery generation, Figma import, annotation reference, comparison gallery, and troubleshooting. This file covers only WP-plugin-specific steps.

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

**Read `shared/common-steps.md` → "Permissions" and "No Shell Variables in Bash Commands" sections.** Follow those instructions exactly. For this skill, also add these extra permissions in Option 1: `"Bash(chmod +x:*)"` and `"Bash(screenshots/wp:*)"`.

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
| **Figma MCP** | Check for `mcp__figma__generate_figma_design` in available tools | See `shared/common-steps.md` → "Figma MCP Setup" |
| **Working directory** | Check for `wp-config.php` or `app/public/wp-config.php` in the given path | Ask user for correct path |
| **WP-CLI** | See "WP-CLI Setup" section below | Only needed if creating temp user or managing plugins |
| **Site is running** | `curl -s -o /dev/null -w "%{http_code}" <site-url>` | User must start their local server |

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

The objective shapes what gets annotated. All annotations should be viewed through the lens of the chosen objective.

**Question: Figma import**
- Ask: "Do you have a Figma file URL for import?"
- Options: "Yes, I'll paste it" / "Skip Figma import"

**Question: Annotation depth**
- Ask: "How detailed should annotations be?"
- Options:
  - **None** — screenshots only, no annotations (fastest)
  - **Light** — brief colored callouts (positive/critical/observation) with 1-2 sentence descriptions
  - **Impact & Opportunity** — each annotation scored on Impact (1-5) and Opportunity (1-5). Best for presenting findings to stakeholders.

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
agent-browser --session <session> open "<site-url>/wp-admin/"
agent-browser --session <session> snapshot -i 2>&1 | grep -i "plugin-keyword"
```

Click the main menu item, then snapshot again to find all sub-pages/tabs. See `shared/common-steps.md` → "agent-browser Click Syntax" for ref syntax rules.

**Build a list of all pages/tabs to capture** before starting screenshots. Example:
```
1. Events list (main page)
2. Add New Event
3. Calendars
4. Tickets
5. Venues
6. Settings (+ each settings tab)
7. Tools
8. Addons
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

### First-Run Gates

Some plugins gate their entire UI behind a welcome/setup screen that won't dismiss via normal clicks. Try these in order:

1. **Direct URL navigation** — Skip the gate by navigating to a known admin page: `agent-browser --session <session> open "<site-url>/wp-admin/admin.php?page=<plugin-slug>-settings"`
2. **JS dismiss** — Use `eval` to find and click hidden dismiss/skip elements: `agent-browser --session <session> eval "document.querySelector('[class*=skip], [class*=dismiss], [class*=close]')?.click()"`
3. **WP-CLI option bypass** — Set the plugin's "setup complete" flag directly: `screenshots/wp option update <plugin_slug>_setup_complete 1` (check the plugin's options table for the exact key)
4. **Capture as UX observation** — If none of the above work, capture the gate screen itself. A first-run screen that blocks access is a legitimate UX finding.

### Wizard Progression

Wizards that validate fields before advancing (e.g., requiring SMTP credentials):

1. **Fill dummy values** — Use plausible-looking test data (e.g., `smtp.example.com`, port `587`, `test@example.com`). The goal is to reach subsequent screens, not to configure a working connection.
2. **WP-CLI option bypass** — Set the wizard's step/completion option directly to jump past validation: `screenshots/wp option update <plugin_slug>_wizard_step 99`
3. **Capture the validation state** — If the wizard won't advance, capture the error/validation state as a UX observation.

## Step 7: Capture Screenshots

Create the screenshots directory:
```bash
mkdir -p screenshots/<plugin-slug>
```

For each screen/tab, **follow `shared/common-steps.md` → "Screenshot Capture Strategy"** — this covers image loading waits and chunked capture for long pages.

**Quick summary of the capture flow:**
1. Set tall viewport: `agent-browser set viewport 1280 1440 --session <session>`
2. Scroll the full page top-to-bottom to trigger lazy images (see common-steps for the eval script)
3. Wait for all images to finish loading
4. Measure page height — if > 4× viewport (~5800px+), use chunked capture (scroll by 1440px per chunk, no overlap, named `XX-description-p1.png`, `-p2.png`, etc.)
5. If page is short enough, use a single `--full` screenshot

**Rules:**
- Naming: `XX-description.png` (01-events-list.png, 02-add-new-event.png, etc.). For chunks: `XX-description-p1.png`, `-p2.png`, etc.
- Save to `screenshots/<plugin-slug>/` directory
- After each screenshot, `Read` the PNG file to verify it captured correctly. If the Read fails due to image dimensions exceeding limits, the screenshot is too tall — switch to chunked capture.
- If a page has tabs, capture each tab as a separate screenshot
- If a page has modals or dropdowns worth showing, open them and capture separately

**Journey notes:** As you capture each screenshot, write a brief journey note describing what you observed while navigating to and interacting with that screen. These notes capture experiential context that static screenshots cannot. Record things like:
- How many clicks/steps to reach this screen
- Modals, banners, or interruptions you had to dismiss
- Elements that didn't work as expected (broken clicks, JS workarounds needed)
- Missing feedback (no success message after save, no loading indicator)
- Confusing navigation (tab label doesn't match URL, feature buried in unexpected place)
- Load time issues or rendering problems

Keep each note to 1-3 sentences. Factual observations, not analysis — the subagent does the analysis.

### Deduplicate Screenshots

Before writing the review brief, list all captured screenshots and Read any with similar names or sequential numbers that might be duplicates. Delete near-duplicates — keep the cleanest capture.

## Step 7a: Write Review Brief

After all screenshots are captured for a plugin, write a **review brief** markdown file that consolidates everything the subagent needs.

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
<If Step 5 filtered pages, list only the pages kept and briefly note why others were excluded. If "General review", write "No filtering — all pages captured.">

## Screenshots & Journey Notes

### 01-mailer-selection.png
**Screen:** <What this screen shows>
**Journey:** <1-3 sentences of what you observed navigating to/interacting with this screen>

### 02-sendgrid-config (3 parts)
**Screen:** <What this screen shows>
**Parts:** 02-sendgrid-config-p1.png, 02-sendgrid-config-p2.png, 02-sendgrid-config-p3.png
**Journey:** <1-3 sentences — note that it was a long page requiring chunked capture>

<!-- Continue for every screenshot. Use the multi-part format for chunked captures. -->
```

## Step 7b: UX Review (Subagent)

After all screenshots are captured for a plugin, dispatch a **general-purpose** subagent to analyze them using the ux-reviewer prompt template. Do NOT analyze screenshots yourself — delegate to the agent.

**Before dispatching, inform the user:**

> Dispatching UX review agents now. No action needed on your side — I'll check in when the galleries are ready for your approval.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"` (there is no custom ux-reviewer type)
- **Prompt:** Paste the full content of `agents/ux-reviewer.md` into the prompt, then tell the agent to:
  1. **Read the review brief** at `screenshots/<plugin-slug>/review-brief.md`
  2. **Read each screenshot PNG** listed in the review brief using the Read tool
  3. **Analyze and return annotations** per the ux-reviewer instructions

**For multi-plugin reviews:** Dispatch one agent per plugin in parallel.

The agent returns:
- **Status:** `DONE | DONE_WITH_CONCERNS | BLOCKED`
- A JSON array of screenshots with annotations, grouped into sections
- An overall summary for the gallery banner

**Handling agent status:**
- **DONE:** Proceed to validation below.
- **DONE_WITH_CONCERNS:** Read the concerns. If the agent couldn't read images, re-dispatch.
- **BLOCKED:** Check if screenshots are readable (Read the PNGs yourself). If images are fine, re-dispatch with more context.

**Post-subagent validation:** The reviewer returns a `manifest` object with `screenshots_reviewed` and `screenshots_with_annotations` counts. Before using the output:
1. **Check manifest counts** — `screenshots_reviewed` must equal the number of PNGs captured. If not, re-dispatch for the missing screenshots.
2. Spot-check 2-3 annotations for objective relevance
3. Verify section groupings make sense for the gallery layout

**If annotation depth is "none":** Skip this step entirely — go straight to Step 8 with screenshots only.

## Step 7c: UX Comparison (Subagent — Multi-Plugin Only)

**Only run this step if the user requested a comparison in Step 2.**

After ALL ux-reviewer agents have completed, dispatch a **general-purpose** subagent using the ux-comparator prompt template.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"`
- `model`: `"sonnet"` (comparator is text-only reasoning on structured JSON)
- **Prompt:** Paste the full content of `agents/ux-comparator.md` into the prompt, followed by all context below. Do NOT tell the agent to read the file — inline everything.
- Provide in the prompt:
  1. **All plugin annotations** — the full validated JSON output from each ux-reviewer agent
  2. **Review brief paths** — tell the agent to read each plugin's `screenshots/<plugin-slug>/review-brief.md`
  3. **Review objective** — the exact objective text from Step 2
  4. **Annotation depth** — from Step 2

Use the comparator output to build the comparison gallery in Step 8.

## Step 8: Generate HTML Gallery

**Read `shared/common-steps.md` → "Generate HTML Gallery", "Local Server & Gallery Verification" sections.** Follow those instructions, using `gallery-<plugin-slug>.html` as the filename.

## Step 9: Import to Figma

**Read `shared/common-steps.md` → "Import to Figma" section.**

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

## Annotation & Comparison Reference

**Read `shared/common-steps.md` → "Annotation Reference", "Comparison Gallery", and "Common Mistakes & Troubleshooting" sections.**

### WP-Plugin-Specific Troubleshooting

| Mistake | Fix |
|---------|-----|
| Guessed tab URL slug from visible label | Extract actual `href` from DOM — slugs often differ from display names. Use `eval`: `agent-browser --session <session> eval "Array.from(document.querySelectorAll('[class*=nav-menu] a, .nav-tab-wrapper a']).map(a => a.textContent.trim() + ' → ' + a.href).join('\\n')"` |
| Subagent annotates off-topic screens | Objective filtering missed pages. Re-check Step 5 filtering and that the review brief includes the exact objective. |

### SPA / JavaScript Framework Troubleshooting

Plugins built with Vue (Element UI, Fluent UI), React, or other SPA frameworks often break standard agent-browser interactions:

| Problem | Solution |
|---------|----------|
| `click` on Vue/React elements times out or does nothing | Use `eval` to click via JS: `agent-browser --session <session> eval "document.querySelector('.target-selector').click()"` |
| `fill` doesn't trigger Vue reactivity | Use `eval` with `dispatchEvent`: `agent-browser --session <session> eval "const el = document.querySelector('input'); el.value = 'test'; el.dispatchEvent(new Event('input', {bubbles: true}))"` |
| Element UI radio buttons / custom controls | Target the inner clickable element: `eval "document.querySelector('.el-radio-button__inner').click()"` |
| Hash-based routing (no page reload on nav) | Use `open` with the full hash URL rather than clicking nav links |
| Content loads after JS render | Add a short wait after navigation: `agent-browser --session <session> eval "await new Promise(r => setTimeout(r, 2000))"` then `snapshot -i` |
