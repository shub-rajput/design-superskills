---
name: website-research
description: Use when capturing screenshots of websites for design research, comparing competitor marketing pages, creating annotated HTML galleries, or when the user mentions website reference, competitor analysis, marketing review, or screenshot galleries for public websites.
---

# Website Research

Capture screenshots of public websites, generate annotated HTML galleries, and import to Figma for marketing and design review.

## Quick Reference

| Step | What | Key Decision |
|------|------|-------------|
| **0** | Permissions check | Bypass mode recommended |
| **1** | Prerequisites | agent-browser required, Figma MCP optional |
| **2** | Gather ALL user input in one interaction | URLs or discovery query, pages, objective, annotations, Figma |
| **3** | Capture screenshots + journey notes | Handle cookie banners, popups, chat widgets |
| **4** | Deduplicate screenshots | Remove near-duplicates before review |
| **5** | Write review brief | One per site |
| **6** | Dispatch marketing-reviewer subagent(s) | Validate manifest counts after |
| **7** | Dispatch marketing-comparator subagent | Multi-site only |
| **8** | Generate HTML gallery, verify, get approval | Start server once, keep alive |
| **9** | Import to Figma | Optional |
| **10** | Cleanup | Kill local HTTP server |

## Step 0: Permissions (DO THIS FIRST — MANDATORY)

This skill is **extremely command-heavy** — dozens of sequential bash commands for browser automation, screenshots, local server, and file operations.

**You MUST use AskUserQuestion here and WAIT for the user's response. Do NOT proceed, do NOT run any Bash commands, do NOT explore the codebase, do NOT skip this step. No matter what mode you think you're in, always ask.**

Ask with these options:

> **Heads up:** This review involves 40+ bash commands (browser automation, screenshots, local servers). Each one needs manual approval unless permissions are configured.
>
> How would you like to proceed?

1. **Add permissions to settings (Recommended)** — I'll add the required tool permissions to your project's `.claude/settings.json`, then you restart Claude Code and re-invoke the skill
2. **Use bypass mode** — exit, restart with `claude --dangerously-skip-permissions`, then re-invoke the skill
3. **I've already set up permissions or bypass mode** — proceed immediately
4. **Continue with manual approvals** — I'll approve each command individually (slow but works)

**After the user responds:**

- **Option 1:** Read the user's `.claude/settings.json` (create if it doesn't exist). Merge the following permissions into the `permissions.allow` array, preserving any existing entries and all other settings (especially `enabledPlugins`):

```json
{
  "permissions": {
    "allow": [
      "Bash(agent-browser:*)",
      "Bash(python3 -m http.server:*)",
      "Bash(curl -s:*)",
      "Bash(mkdir -p screenshots:*)",
      "Bash(mkdir -p screenshots/*)",
      "Bash(kill:*)",
      "Bash(open http:*)",
      "Bash(cat > screenshots:*)"
    ]
  }
}
```

After writing, tell the user: "Permissions added. Please restart Claude Code (`/exit` then relaunch) and re-invoke the skill." **Stop here — do nothing else.**

- **Option 2:** Tell them to run `claude --dangerously-skip-permissions` and re-invoke the skill. **Stop here — do nothing else.**
- **Option 3:** Proceed to Step 1.
- **Option 4:** Proceed to Step 1, but warn it will be slow (40+ individual approvals).

**Do NOT move to Step 1 until the user has explicitly chosen an option.**

## CRITICAL: No Shell Variables in Bash Commands

Claude Code flags commands containing `$VARIABLE` syntax (like `$HOME`, `$SESSION`) as requiring **extra** manual approval for shell expansion — even with pre-configured permissions this adds friction.

**Rule: Always use fully resolved, literal paths in every Bash command. Never use `$HOME`, `$SESSION`, `$URL`, or any other shell variable.**

```bash
# WRONG — triggers extra "shell expansion" approval prompt:
agent-browser --session "$SESSION" open "$URL"
mkdir -p "$HOME/screenshots/site-name"

# CORRECT — uses resolved values, minimal prompts:
agent-browser --session ws-abc123 open "https://example.com"
mkdir -p /Users/jane/project/screenshots/site-name
```

The examples in this skill use placeholders like `<session>` and `<url>` for readability — always substitute actual values when running commands.

Also avoid chaining commands with `||` and `&&` — these trigger "shell operators" approval. Use separate sequential Bash calls instead.

## Step 1: Prerequisites

Check that required tools are available before gathering input.

| Check | How | Fix |
|-------|-----|-----|
| **agent-browser** | `which agent-browser` | `npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser` |
| **Figma MCP** (optional) | Check for `mcp__figma__get_design_context` or `mcp__figma__generate_figma_design` in available tools (must be the remote Figma MCP, not the Claude AI built-in one) | See install instructions below |

### Figma MCP Setup (Only if user wants Figma import)

The skill requires the **remote Figma MCP server**, not the Claude AI built-in Figma integration. If the `mcp__figma__generate_figma_design` tool is not available, tell the user to run:

```
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

Then restart Claude Code. The remote MCP provides `generate_figma_design` which is needed for the HTML-to-Figma capture workflow. The Claude AI built-in Figma tools (`mcp__claude_ai_Figma__*`) do NOT support this.

## Step 2: Gather User Input (Single Interaction)

The user should answer everything in **one interaction**, then walk away. Use AskUserQuestion to gather all of the following.

**Question: How would you like to provide websites?**

1. **"I'll paste URLs"** — user provides specific URLs
2. **"Discovery query"** — user provides a query like "wpforms competitors" or "best SaaS pricing pages"

**If discovery mode:** Use WebSearch to find relevant sites. Present a numbered list of discovered sites (name, URL, brief description). Ask the user to pick which ones to capture.

**Question: Which pages to capture per site?**

For each selected site, ask:
1. **Homepage only** — just the landing page
2. **Homepage + pricing + features** — the core marketing pages
3. **Specific pages** — user lists URLs or page names
4. **Let me explore and suggest pages** — you'll navigate the site, find key pages, and propose a list before capturing

If the user chooses option 4, navigate the site with agent-browser, build a page list from the navigation, and present it for approval before any screenshots.

**Question: Review objective (optional)**

- **Marketing effectiveness** — above-the-fold impact, value prop clarity, social proof, CTAs
- **Visual design** — layout, typography, color, whitespace, brand coherence
- **Conversion flow** — landing-to-action path, form UX, pricing presentation, objection handling
- **Content strategy** — messaging hierarchy, feature-vs-benefit framing, audience targeting, tone
- **Specific objective** — free text (e.g., "How well does the pricing page handle objections?")
- **None (screenshots only)** — capture pages with no analysis

**Question: Comparison (only if 2+ sites selected)**

- "Would you like a side-by-side comparison of these sites?"
- Options: "Yes — include a comparison table" / "No — just individual reviews"

**Question: Annotation depth**

- **None** — screenshots only, no annotations (fastest)
- **Light** — brief colored callouts (positive/critical/observation) with 1-2 sentence descriptions
- **Impact & Opportunity** — each annotation scored on Impact (1-5) and Opportunity (1-5). Highlights where the biggest improvements are.

**Question: Figma import**

- "Do you have a Figma file URL for import?"
- Options: "Yes, I'll paste it" / "Skip Figma import"

**After gathering input, print a summary:**

> **Website Research Plan:**
> - Sites: Stripe (stripe.com), Square (squareup.com), Paddle (paddle.com)
> - Pages per site: Homepage + pricing + features
> - Objective: Conversion flow
> - Comparison: Yes
> - Annotations: Impact & Opportunity
> - Figma import: Yes (fileKey: XXXXX)
> - Estimated screens: ~6-9 per site
>
> I'll now work through the capture and review autonomously. I'll check in when the HTML gallery is ready for your approval before importing to Figma.

This lets the user walk away while work happens.

## Step 3: Capture Screenshots

For each site and page, navigate with agent-browser and capture screenshots.

### Create Directory

```bash
mkdir -p screenshots/<site-slug>
```

Use a URL-derived slug (e.g., `stripe.com` → `stripe`, `squareup.com` → `squareup`).

### Navigate and Capture

```bash
agent-browser --session <session> open "<url>"
```

Wait for the page to load, then take the screenshot:

```bash
agent-browser --session <session> screenshot screenshots/<site-slug>/XX-description.png --full
```

**Rules:**
- Use `--full` flag for full-page capture **UNLESS the page is very long** (blog archives, template libraries, integration directories). For those, use viewport-only (no `--full`) to avoid extremely tall screenshots that become unreadable at gallery scale.
- Naming: `XX-description.png` (01-homepage.png, 02-pricing.png, 03-features.png, etc.)
- After each screenshot, `Read` the PNG file to verify it captured correctly. If the Read fails due to image dimensions exceeding limits, the screenshot is too tall — recapture without `--full`.
- If a page has tabs or sections worth showing separately, capture each as a separate screenshot.

### Handle Common Interruptions

Dismiss these BEFORE taking the screenshot:

| Interruption | Solution |
|-------------|----------|
| Cookie consent banner | Use `snapshot -i` to find accept/dismiss button, click by `[ref=XX]` |
| Newsletter popup | Find close/dismiss button via `snapshot -i`, click by `[ref=XX]` |
| Chat widget overlay | Find close button via `snapshot -i`, click by `[ref=XX]` |
| Age gate / GDPR modal | Find accept/confirm button via `snapshot -i`, click by `[ref=XX]` |
| Exit-intent popup | Use `snapshot -i` to find dismiss, click by `[ref=XX]` |
| Sticky notification bar | Find close button or use `eval` to hide: `agent-browser --session <session> eval "document.querySelector('[class*=notification], [class*=banner]')?.remove()"` |

**Cookie banners that reappear after dismiss:** Some sites re-show consent on every navigation. Use `eval` to set the consent cookie directly:
```bash
agent-browser --session <session> eval "document.cookie = 'cookie_consent=accepted; path=/; max-age=86400'"
```
Then reload the page.

**Always use `snapshot -i`** to discover the correct ref before clicking. Never guess selectors.

**Clicking elements by ref:** Use bracket syntax `[ref=e21]`, NOT `@ref=e21`:
```bash
# CORRECT:
agent-browser --session <session> click "[ref=e21]"

# WRONG (will throw CSS parse error):
agent-browser --session <session> click "@ref=e21"
```

### Sites with Anti-Bot Protection

Some sites use Cloudflare, reCAPTCHA, or aggressive anti-bot measures. If agent-browser is blocked:
1. Note the limitation in the review brief
2. Screenshot what is accessible (the challenge page itself can be a finding)
3. Move on to the next site — do not spend time trying to bypass protection

### Journey Notes

As you capture each screenshot, write a brief journey note describing what you observed. These notes capture experiential context that static screenshots cannot — the subagent hasn't browsed the site, so these notes are its only window into the browsing experience. Record things like:
- Page load speed impressions (fast, slow, content jumping around)
- Pop-ups, modals, or banners that appeared before/during the visit
- Scroll depth required to reach key content or CTAs
- Navigation structure observations (clear, confusing, deeply nested)
- Trust signals you noticed (or conspicuous absence of them)
- How the page felt from a visitor's perspective
- What you expected to see vs. what actually appeared

Keep each note to 1-3 sentences. Factual observations, not analysis — the subagent does the analysis.

### SPA / JavaScript-Heavy Sites

Sites built with React, Vue, Next.js, or other SPA frameworks may need special handling:

| Problem | Solution |
|---------|----------|
| Navigation doesn't trigger page load | Use `open` with the full URL rather than clicking nav links |
| Content loads after JS render | Add a short wait: `agent-browser --session <session> eval "await new Promise(r => setTimeout(r, 2000))"` then `snapshot -i` |
| Elements load dynamically | Use `snapshot -i` after waiting to verify content is present before screenshotting |

## Step 4: Deduplicate Screenshots

Before writing the review brief, list all captured screenshots and Read any with similar names or sequential numbers that might be duplicates (e.g., `03-pricing.png` and `04-pricing-retry.png`). Delete near-duplicates — keep the cleanest capture. This prevents the reviewer subagent from annotating the same page multiple times.

## Step 5: Write Review Brief

After all screenshots are captured for a site, write a review brief that consolidates everything the subagent needs.

**File:** `screenshots/<site-slug>/review-brief.md`

**Template:**

```markdown
# Review Brief: <Site Name>

## Objective
<Exact objective text from Step 2>

## Annotation Depth
<"light" or "impact-opportunity">

## Site Metadata
- **Name:** <site name from page title or meta>
- **URL:** <base URL>
- **Description:** <meta description or brief summary of what the site/company offers>

## Pages Captured
<Numbered list of all URLs/pages captured>

## Capture Scope
<What the user chose to capture and why. Note any pages skipped or inaccessible.>

## Screenshots & Journey Notes

### 01-homepage.png
**Page:** <URL>
**Journey:** <1-3 sentences of what you observed>

### 02-pricing.png
**Page:** <URL>
**Journey:** <1-3 sentences>

<!-- Continue for every screenshot -->
```

**This file serves three purposes:**
1. **Subagent context** — the subagent reads this before analyzing screenshots, so it understands the browsing experience
2. **User review** — the user can skim it to verify scope before the subagent runs
3. **Audit trail** — documents what was captured and why

## Step 6: Marketing Review (Subagent — Optional)

**If annotation depth is "none": skip this step entirely — go straight to Step 8.**

After all screenshots are captured for a site, dispatch a **general-purpose** subagent to analyze them using the marketing-reviewer prompt template. Do NOT analyze screenshots yourself — delegate to the agent.

**Before dispatching, inform the user:**

> Dispatching marketing review agents now. No action needed on your side — I'll check in when the galleries are ready for your approval.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"` (there is no custom marketing-reviewer type)
- **Prompt:** Paste the full content of `agents/marketing-reviewer.md` into the prompt, then tell the agent to:
  1. **Read the review brief** at `screenshots/<site-slug>/review-brief.md` — this contains the objective, metadata, page structure, and journey notes per screenshot
  2. **Read each screenshot PNG** listed in the review brief using the Read tool
  3. **Analyze and return annotations** per the marketing-reviewer instructions

The review brief is the subagent's primary context document. It contains everything the subagent needs to understand the site beyond what the screenshots show — the browsing experience, the objective, the scope, and per-page observations from actually visiting the site.

**For multi-site reviews:** Dispatch one agent per site in parallel. Each agent analyzes one site's screenshots independently.

The agent returns:
- **Status:** `DONE | DONE_WITH_CONCERNS | BLOCKED`
- A JSON array of screenshots with annotations, grouped into sections
- An overall summary for the gallery banner (3-5 bullet executive summary)

**Handling agent status:**
- **DONE:** Proceed to validation below.
- **DONE_WITH_CONCERNS:** Read the concerns. If screenshots appeared irrelevant to the objective, that's a signal the page selection was too broad — note it but proceed. If the agent couldn't read images, re-dispatch.
- **BLOCKED:** The agent couldn't complete analysis. Check if screenshots are readable (Read the PNGs yourself). If images are fine, re-dispatch with more context.

**Post-subagent validation:** The reviewer returns a `manifest` object with `screenshots_reviewed` and `screenshots_with_annotations` counts. Before using the output:
1. **Check manifest counts** — `screenshots_reviewed` must equal the number of PNGs captured. If not, re-dispatch for the missing screenshots.
2. Spot-check 2-3 annotations for objective relevance
3. Verify section groupings make sense for the gallery layout
4. If annotations reference off-topic pages, remove those entries

Use the validated output to populate annotations in the HTML gallery (Step 8).

## Step 7: Marketing Comparison (Subagent — Multi-Site Only)

**Only run this step if the user requested a comparison in Step 2.**

After ALL marketing-reviewer agents have completed, dispatch a **general-purpose** subagent using the marketing-comparator prompt template. This agent does text reasoning on structured JSON — no vision needed, so it can use a faster model.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"` (there is no custom marketing-comparator type)
- `model`: `"sonnet"` (comparator is text-only reasoning on structured JSON — doesn't need the most capable model)
- **Prompt:** Paste the full content of `agents/marketing-comparator.md` into the prompt, followed by all context below. Do NOT tell the agent to read the file — inline everything.
- Provide in the prompt:
  1. **All site annotations** — the full validated JSON output from each marketing-reviewer agent
  2. **Review brief paths** — tell the agent to read each site's `screenshots/<site-slug>/review-brief.md` for metadata, page structure, and journey notes
  3. **Review objective** — the exact objective text from Step 2
  4. **Annotation depth** — from Step 2

The agent returns:
- A comparison table with per-dimension ratings and justifications
- A verdict with winner-per-dimension, overall winner, and top 3 differentiators

Use this output to build the comparison gallery in Step 8.

## Step 8: Generate HTML Gallery

Read the template at `templates/gallery.html` (relative to this skill's repo root). Copy it to `screenshots/gallery-<site-slug>.html` and customize:

- Replace `Plugin Name` with the site name in the header `<h1>`
- Replace `Author`, `vX.X`, `Description` in the header `<p>` with site URL and description
- Replace `/* ACCENT_COLOR */` with a brand-appropriate color (for `.step-num` background and `.flow-label` border)
- Populate sections from the marketing-reviewer JSON: one `.flow-group` per section, one `.screen-item` per screenshot
- Add `.ux-note` callouts from annotations (use `.critical`, `.positive`, or default orange for observations)
- For Impact & Opportunity depth, add `.score` spans inside `.ux-note`
- For comparisons, uncomment the `.comparison-section` block and populate from marketing-comparator output
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
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/gallery-<site-slug>.html
# If server died, restart it before proceeding
```

**Do NOT skip verification.** Open the gallery in agent-browser, screenshot it, Read the screenshot, and show to the user. **Ask for approval before Figma import.**

## Step 9: Import to Figma

Only if user provided a Figma file URL.

1. Extract `fileKey` from URL: `figma.com/design/:fileKey/:fileName`
2. Call `mcp__figma__generate_figma_design` with `outputMode: "existingFile"` and `fileKey`
3. Open the gallery URL with capture hash:
   ```bash
   open "http://localhost:3000/gallery-<site-slug>.html#figmacapture=<captureId>&figmaendpoint=...&figmadelay=3000"
   ```
4. Wait 6 seconds for images to load
5. Poll with captureId until status is "completed"
6. Report the Figma node URL to user

Use `figmadelay=3000` to ensure images load before capture.

## Step 10: Cleanup

```bash
# Kill local HTTP server if started for gallery preview
kill %1 2>/dev/null
```

No other cleanup needed — this skill doesn't modify any websites.

## UX Annotation Reference (for HTML generation)

The marketing-reviewer subagent handles annotation logic and rubrics. This section covers only what you need for building the gallery HTML.

**Annotation classes** — map the subagent's `type` field to CSS:

| type | Class | Color |
|------|-------|-------|
| `critical` | `.critical` | Red |
| `observation` | (default) | Orange |
| `positive` | `.positive` | Green |

**For Impact & Opportunity depth**, add score spans and include the rubric legend in `.ux-summary`:

```html
<div class="ux-note critical">
  <span class="tag">CTA</span>
  Primary CTA is below the fold and uses passive language — "Learn More" instead of a benefit-driven action.
  <span class="score">Impact: <span class="high">4</span> · Opportunity: <span class="high">5</span></span>
</div>
```

## Comparison Conclusion (Multi-Site Reviews)

**Only generate if the user requested a comparison in Step 2.**

After the marketing-comparator subagent returns its output (Step 7), generate a separate HTML page:

- File: `screenshots/gallery-comparison.html`
- Use the marketing-comparator's JSON output to populate the comparison table — do NOT invent ratings yourself
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
| Full-page screenshot extremely tall | Use viewport-only capture (no `--full`) for long scrollable lists. If `Read` fails on the PNG, recapture without `--full`. |
| agent-browser click runs in background/times out | The page likely navigated. Use `open` to navigate to the expected URL instead of waiting for the click. |
| Subagent annotates off-topic pages | Objective filtering was too broad. Re-check the page selection and that the review brief includes the exact objective. |
| Cookie banner reappears on every page | Set consent cookie via `eval` (see Step 3) instead of clicking dismiss each time. |
| SPA site — navigation doesn't reload page | Use `agent-browser --session <session> open "<full-url>"` for each page instead of clicking nav links. |
| Cloudflare or anti-bot challenge blocks capture | Note the limitation, screenshot what's accessible, move to the next site. |
| Gallery shows broken image paths | Verify the `src` paths in the HTML match the actual screenshot filenames in the screenshots directory. |
