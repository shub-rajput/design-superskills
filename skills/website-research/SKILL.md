---
name: website-research
description: Use when capturing screenshots of websites for design research, comparing competitor marketing pages, creating annotated HTML galleries, or when the user mentions website reference, competitor analysis, marketing review, or screenshot galleries for public websites.
---

# Website Research

Capture screenshots of public websites, generate annotated HTML galleries, and import to Figma for marketing and design review.

**Shared reference:** Read `shared/common-steps.md` for permissions, shell variable rules, Figma MCP setup, gallery generation, Figma import, annotation reference, comparison gallery, and troubleshooting. This file covers only website-specific steps.

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

**Read `shared/common-steps.md` → "Permissions" and "No Shell Variables in Bash Commands" sections.** Follow those instructions exactly. No extra permissions needed for this skill.

## Step 1: Prerequisites

Check that required tools are available before gathering input.

| Check | How | Fix |
|-------|-----|-----|
| **agent-browser** | `which agent-browser` | `npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser` |
| **Figma MCP** (optional) | Check for `mcp__figma__generate_figma_design` in available tools | See `shared/common-steps.md` → "Figma MCP Setup" |

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
- **Impact & Opportunity** — each annotation scored on Impact (1-5) and Opportunity (1-5)

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
agent-browser --session <session> screenshot screenshots/<site-slug>/XX-description.png --full
```

**Rules:**
- Use `--full` flag for full-page capture **UNLESS the page is very long** (blog archives, template libraries, integration directories). For those, use viewport-only (no `--full`).
- Naming: `XX-description.png` (01-homepage.png, 02-pricing.png, 03-features.png, etc.)
- After each screenshot, `Read` the PNG file to verify it captured correctly. If the Read fails due to image dimensions exceeding limits, recapture without `--full`.

See `shared/common-steps.md` → "agent-browser Click Syntax" for ref syntax rules.

### Handle Common Interruptions

Dismiss these BEFORE taking the screenshot:

| Interruption | Solution |
|-------------|----------|
| Cookie consent banner | Use `snapshot -i` to find accept/dismiss button, click by `[ref=XX]` |
| Newsletter popup | Find close/dismiss button via `snapshot -i`, click by `[ref=XX]` |
| Chat widget overlay | Find close button via `snapshot -i`, click by `[ref=XX]` |
| Age gate / GDPR modal | Find accept/confirm button via `snapshot -i`, click by `[ref=XX]` |
| Sticky notification bar | Find close button or use `eval` to hide: `agent-browser --session <session> eval "document.querySelector('[class*=notification], [class*=banner]')?.remove()"` |

**Cookie banners that reappear after dismiss:** Use `eval` to set the consent cookie directly:
```bash
agent-browser --session <session> eval "document.cookie = 'cookie_consent=accepted; path=/; max-age=86400'"
```
Then reload the page.

### Sites with Anti-Bot Protection

Some sites use Cloudflare, reCAPTCHA, or aggressive anti-bot measures. If agent-browser is blocked:
1. Note the limitation in the review brief
2. Screenshot what is accessible (the challenge page itself can be a finding)
3. Move on to the next site — do not spend time trying to bypass protection

### Journey Notes

As you capture each screenshot, write a brief journey note describing what you observed. Record things like:
- Page load speed impressions (fast, slow, content jumping around)
- Pop-ups, modals, or banners that appeared before/during the visit
- Scroll depth required to reach key content or CTAs
- Navigation structure observations (clear, confusing, deeply nested)
- Trust signals you noticed (or conspicuous absence of them)

Keep each note to 1-3 sentences. Factual observations, not analysis — the subagent does the analysis.

### SPA / JavaScript-Heavy Sites

| Problem | Solution |
|---------|----------|
| Navigation doesn't trigger page load | Use `open` with the full URL rather than clicking nav links |
| Content loads after JS render | Add a short wait: `agent-browser --session <session> eval "await new Promise(r => setTimeout(r, 2000))"` then `snapshot -i` |

## Step 4: Deduplicate Screenshots

Before writing the review brief, list all captured screenshots and Read any with similar names that might be duplicates. Delete near-duplicates — keep the cleanest capture.

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

## Step 6: Marketing Review (Subagent — Optional)

**If annotation depth is "none": skip this step entirely — go straight to Step 8.**

Dispatch a **general-purpose** subagent to analyze screenshots using the marketing-reviewer prompt template. Do NOT analyze screenshots yourself — delegate to the agent.

**Before dispatching, inform the user:**

> Dispatching marketing review agents now. No action needed on your side — I'll check in when the galleries are ready for your approval.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"`
- **Prompt:** Paste the full content of `agents/marketing-reviewer.md` into the prompt, then tell the agent to:
  1. **Read the review brief** at `screenshots/<site-slug>/review-brief.md`
  2. **Read each screenshot PNG** listed in the review brief using the Read tool
  3. **Analyze and return annotations** per the marketing-reviewer instructions

**For multi-site reviews:** Dispatch one agent per site in parallel.

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

## Step 7: Marketing Comparison (Subagent — Multi-Site Only)

**Only run this step if the user requested a comparison in Step 2.**

After ALL marketing-reviewer agents have completed, dispatch a **general-purpose** subagent using the marketing-comparator prompt template.

**Dispatch with the Agent tool:**
- `subagent_type`: `"general-purpose"`
- `model`: `"sonnet"` (comparator is text-only reasoning on structured JSON)
- **Prompt:** Paste the full content of `agents/marketing-comparator.md` into the prompt, followed by all context below. Do NOT tell the agent to read the file — inline everything.
- Provide in the prompt:
  1. **All site annotations** — the full validated JSON output from each marketing-reviewer agent
  2. **Review brief paths** — tell the agent to read each site's `screenshots/<site-slug>/review-brief.md`
  3. **Review objective** — the exact objective text from Step 2
  4. **Annotation depth** — from Step 2

Use the comparator output to build the comparison gallery in Step 8.

## Step 8: Generate HTML Gallery

**Read `shared/common-steps.md` → "Generate HTML Gallery", "Local Server & Gallery Verification" sections.** Follow those instructions, using `gallery-<site-slug>.html` as the filename. Replace header metadata with site name, URL, and description instead of plugin metadata.

## Step 9: Import to Figma

**Read `shared/common-steps.md` → "Import to Figma" section.**

## Step 10: Cleanup

```bash
# Kill local HTTP server if started for gallery preview
kill %1 2>/dev/null
```

No other cleanup needed — this skill doesn't modify any websites.

## Annotation & Comparison Reference

**Read `shared/common-steps.md` → "Annotation Reference", "Comparison Gallery", and "Common Mistakes & Troubleshooting" sections.**

### Website-Specific Troubleshooting

| Mistake | Fix |
|---------|-----|
| Cookie banner reappears on every page | Set consent cookie via `eval` (see Step 3) instead of clicking dismiss each time. |
| SPA site — navigation doesn't reload page | Use `agent-browser --session <session> open "<full-url>"` for each page instead of clicking nav links. |
| Cloudflare or anti-bot challenge blocks capture | Note the limitation, screenshot what's accessible, move to the next site. |
