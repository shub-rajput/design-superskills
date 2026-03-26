---
name: design-organize
description: Use when organizing Figma design screens into labeled, spaced layouts with optional sub-sections. Triggers include requests to organize screens, arrange frames, clean up a section, add labels, group screens, or re-format a layout.
---

# Design Organize

Organize scattered design screens inside a Figma section or frame into a clean, labeled layout with optional sub-section grouping. Works on any node type — frames, groups, images, shapes, vectors. Handles both fresh organization and re-formatting existing layouts.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification. If a screenshot reveals a problem, fix it before proceeding.

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Parse user intent, ask only unresolved questions |
| **2** | Read container, classify children (screens vs labels vs notes) |
| **3** | Handle existing labels (ask: keep/update/remove) |
| **4** | Arrange screens + optional sub-section grouping |
| **5** | Validate arrangement (get_screenshot) |
| **6** | Add/reposition labels |
| **7** | Validate labels (get_screenshot) |
| **8** | Resize section(s) to fit content |
| **9** | Final validation (get_screenshot) |
| **10** | Present result, offer adjustments |

## Step 0: Prerequisites

1. **Figma MCP server** — check if `mcp__figma__use_figma` tool is available. If NOT available, tell the user:

> This skill requires the Figma MCP server. Run:
> ```
> claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
> ```
> Then restart Claude Code.

Do NOT proceed without it.

2. **figma-use skill** — load `figma:figma-use` via the Skill tool before making any `use_figma` call. This provides API safety rules and gotchas. If unavailable, proceed but follow these critical rules yourself:
   - Every `use_figma` call must switch page via `setCurrentPageAsync` first
   - Colors use 0-1 range (not 0-255)
   - Fills/strokes are read-only — clone, modify, reassign as new arrays
   - `loadFontAsync` before any text property changes
   - `layoutSizingHorizontal/Vertical = "FILL"` must be set AFTER `appendChild`
   - Always `return` all created/mutated node IDs
   - **Page-switch gotcha:** `getNodeById()` works cross-page once a page has been loaded into memory. The `if (figma.getNodeById("<childId>")) break;` preamble in subsequent steps relies on `<childId>` being set from Step 2's discovery loop. If nodes appear to exist but have no accessible properties, re-run the full page discovery from Step 2.

## Step 1: Parse User Intent

The user has already provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

**Parse inline preferences first.** Check if the user's message already answers any of these:
- Labels preference (e.g., "no labels", "auto-label", "label these screens")
- Grouping preference (e.g., "group by feature", "keep flat")

**Only ask about unresolved choices.** Combine remaining questions into one `AskUserQuestion`:

> **Labels:**
> - A) Use element names (default, fast)
> - B) Auto-detect from content (I'll screenshot each element and generate descriptive labels — great for screenshot dumps with meaningless filenames)
> - C) No labels

Skip questions the user already answered inline.

## Step 2: Read Container and Classify Children

Find the correct page and read the target node's children. **Critical:** the section/frame won't be found on the default page — you must iterate all pages.

**Page discovery approach:** Use a single `use_figma` call that iterates all pages, trying to find the section AND access its children. When the section is found on the correct page, its children will be populated.

```javascript
// Iterate all pages to find the one where this section has children.
// IMPORTANT: getNodeById works cross-page after loading, so checking node
// existence alone stops on the wrong page. Verify a child's properties
// are accessible to confirm we're on the correct page.
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const section = figma.getNodeById("<nodeId>");
  if (section && section.children && section.children.length > 0) {
    const firstChild = section.children[0];
    if (firstChild && firstChild.width !== undefined) break;
  }
}
```

**Why iterate pages:** Section nodes return `children.length === 0` when accessed from the wrong page. You must switch to the correct page to load content. Note: `getNodeById()` returns nodes cross-page once loaded, so the `children` accessibility check is essential.

**Avoid get_metadata for large sections** — it can return 300K+ characters exceeding token limits. Use `use_figma` directly for child classification instead.

Once on the correct page, classify children:

```javascript
const container = figma.getNodeById("<nodeId>");
const screens = [];
const existingLabels = [];
const existingNotes = [];

for (const child of container.children) {
  if (child.visible === false) continue;

  // Existing label: ANY text node that is a direct child of the container.
  // Do NOT rely on fontSize === 70 — it may return a Symbol for mixed styles
  // or the label may have been created at a different size.
  if (child.type === "TEXT") {
    existingLabels.push({
      id: child.id,
      name: child.name,
      characters: child.characters,
      x: child.x, y: child.y,
      width: child.width, height: child.height
    });
  }
  // Existing note: instance ≤450px wide, or frame named "Dev Note" ≤450px wide
  else if ((child.type === "INSTANCE" && child.width <= 450) ||
           (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    existingNotes.push({ id: child.id, name: child.name, x: child.x, y: child.y });
  }
  // Everything else is a screen
  else {
    screens.push({
      id: child.id, name: child.name,
      x: child.x, y: child.y,
      width: child.width, height: child.height
    });
  }
}

return {
  screens: screens.sort((a, b) => a.x - b.x || a.y - b.y),
  existingLabels,
  existingNotes: existingNotes.length
};
```

**Important:** Store one screen ID (e.g., the first screen's `id`) as `<childId>` — you'll use it in the page-switch preamble for all subsequent `use_figma` calls.

**Classification rules:**

| Type | Detection |
|------|-----------|
| **Label** | `type === "TEXT"` (any direct-child text node is a label) |
| **Note (instance)** | `type === "INSTANCE"` AND `width <= 450` |
| **Note (default)** | `type === "FRAME"` AND `name === "Dev Note"` AND `width <= 450` |
| **Screen** | Everything else that's visible |

## Step 2b: Version Safety

**Before making any changes**, ask the user to save a version manually:

> **Before I start making changes** — please save a named version in Figma (File → Save to Version History) so you can revert if needed. Figma has no undo for MCP changes.
>
> Let me know when you're ready to proceed.

Wait for confirmation before continuing to Step 3.

## Step 3: Handle Existing Labels and Notes

**Do NOT delete existing labels.** Always reuse them. This preserves node IDs, custom styling, and user edits.

If existing labels were found in Step 2, inform the user:

> **Found X existing labels.** I'll reposition them above their screens and update the text if needed.

Then in Step 6:
1. Match each existing label to its nearest screen by x-proximity
2. Reposition it above the matched screen
3. Update `.characters` only if the label text doesn't match the screen name (and user chose Mode A) or with auto-detected text (Mode B)
4. Create new labels only for screens that have no matching existing label
5. If there are leftover labels with no matching screen, ask the user before removing them

**For existing notes:** same approach — reposition, don't delete.

**If no existing labels/notes found:** skip this step entirely.

## Step 4: Arrange Screens

**Layout defaults:**

| Setting | Default |
|---------|---------|
| Section padding | 100px |
| Label-to-screen gap | 70px |
| Screen-to-screen gap | 200px |
| Label font | Inter Medium, 70pt |
| Label color | White `{r:1, g:1, b:1}` |

### Flat layout (default)

Position all screens in a horizontal row:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");

// Collect screens only (exclude text labels and notes)
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
  .sort((a, b) => a.x - b.x || a.y - b.y);

// Measure label height dynamically
await figma.loadFontAsync({ family: "Inter", style: "Medium" });
const tempLabel = figma.createText();
tempLabel.fontName = { family: "Inter", style: "Medium" };
tempLabel.fontSize = 70;
tempLabel.characters = "X";
const labelHeight = tempLabel.height;
tempLabel.remove();

const padding = 100;
const labelGap = 70;
// labelsEnabled = true if user chose A or B for labels in Step 1
const startY = <labelsEnabled> ? padding + labelHeight + labelGap : padding;

const screenToScreenGap = 200;

let currentX = padding;

for (const screen of screens) {
  screen.x = currentX;
  screen.y = startY;
  currentX += screen.width + screenToScreenGap;
}

return { arranged: screens.length, mutatedNodeIds: screens.map(s => s.id) };
```

### Sub-section grouping (when user requests or 8+ screens)

For larger sets of screens, offer to group them into sub-sections. This can happen:
- **User asks explicitly** (e.g., "group by feature area")
- **Auto-suggest for 8+ screens** — analyze labels for common prefixes (text before `>`) and suggest groups

**Grouping flow:**

1. Analyze screen names or auto-detected labels for common prefixes
2. Present detected groups:
   > **Suggested groups (from label prefixes):**
   > - **Submissions** — 4 screens
   > - **Onboarding** — 3 screens
   > - **Settings** — 3 screens
   > - **Dashboard** — 2 screens
   >
   > Layout: **Vertical** (sections stacked top to bottom) or **Horizontal** (side by side)?
3. User confirms or adjusts

**Creating sub-sections:**

```javascript
// Switch page
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const parentSection = figma.getNodeById("<sectionId>");

// Create a child section for each group
const subSection = figma.createSection();
subSection.name = "<groupName>";

// Move this group's screens into the sub-section
for (const screen of groupScreens) {
  const node = figma.getNodeById(screen.id);
  subSection.appendChild(node);
}

// Arrange screens horizontally within the sub-section (same logic as flat layout)
// ...

// Sub-section fill: darken parent fill ~30% for visual contrast
if (parentSection.fills && parentSection.fills.length > 0) {
  const parentFill = parentSection.fills[0];
  if (parentFill.type === "SOLID") {
    subSection.fills = [{ type: "SOLID", color: {
      r: parentFill.color.r * 0.7,
      g: parentFill.color.g * 0.7,
      b: parentFill.color.b * 0.7
    }}];
  } else {
    subSection.fills = [...parentSection.fills];
  }
}

parentSection.appendChild(subSection);
```

**Positioning sub-sections (vertical stacking — default for 3+ groups):**

```javascript
const sectionGap = 100;
let currentY = padding;

for (const subSection of subSections) {
  subSection.x = padding;
  subSection.y = currentY;
  currentY += subSection.height + sectionGap;
}
```

**Positioning sub-sections (horizontal — for 2 groups or when user prefers):**

```javascript
let currentX = padding;

for (const subSection of subSections) {
  subSection.x = currentX;
  subSection.y = padding;
  currentX += subSection.width + sectionGap;
}
```

**Gotcha: sub-section children after creation.** After creating sub-sections and moving children into them, reading `subSection.children` via the parent node may return empty arrays. To access sub-section children reliably, navigate via a known child ID: `figma.getNodeById(childId).parent` gives you the sub-section with populated children.

## Step 5: Validate Arrangement

Call `get_screenshot` on the section/frame. Verify:
- All screens horizontally aligned within each section/sub-section
- Consistent spacing between screens
- Sub-sections properly stacked (vertical or horizontal)
- No overlapping elements

Fix any issues before proceeding.

## Step 6: Add/Reposition Labels

**First, determine the label text for each screen** based on the user's label mode choice:

- **Mode A (element names):** label text = `screen.name`
- **Mode B (auto-detect):** call `get_screenshot` on each screen element (outside `use_figma`), analyze the content, generate a short descriptive label. Build a map: `[{ screenId, labelText }, ...]`

**Auto-detect label guidelines:**
- Keep labels short (2-5 words)
- Use `>` as a hierarchy separator for sub-views (e.g., "Share > Link")
- Focus on the primary content, not UI chrome
- For modals: name the modal (e.g., "Calendar Invitation Email")
- For settings: name the category (e.g., "Limits & Buffers")

**Then, apply labels non-destructively.** If existing labels were found in Step 2, reuse them. Only create new text nodes for screens that don't have a matching label.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const section = figma.getNodeById("<nodeId>");
  if (section && section.children && section.children.length > 0) break;
}

await figma.loadFontAsync({ family: "Inter", style: "Medium" });

const container = figma.getNodeById("<nodeId>");

// Collect screens and existing labels
const screens = [];
const existingLabels = [];
for (const child of container.children) {
  if (child.visible === false) continue;
  if (child.type === "TEXT") {
    existingLabels.push(child);
  } else if (!(child.type === "INSTANCE" && child.width <= 450) &&
             !(child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    screens.push(child);
  }
}
screens.sort((a, b) => a.x - b.x || a.y - b.y);

// labelTexts is an array of strings, one per screen (from Mode A or B)
// Mode A: use screen names directly. Mode B: use auto-detected labels from Step 6.
const labelTexts = /* Mode A */ screens.map(s => s.name);
// OR for Mode B: labelMap is built earlier from get_screenshot analysis
// const labelTexts = screens.map(s => labelMap.get(s.id) || s.name);

// Match existing labels to screens by x-proximity, then reuse them
const usedLabels = new Set();
const mutatedIds = [];

for (let i = 0; i < screens.length; i++) {
  const screen = screens[i];
  const newText = labelTexts[i];

  // Find the closest unused existing label
  let bestLabel = null;
  let bestDist = Infinity;
  for (const label of existingLabels) {
    if (usedLabels.has(label.id)) continue;
    const dist = Math.abs(label.x - screen.x);
    if (dist < bestDist) { bestDist = dist; bestLabel = label; }
  }

  if (bestLabel && bestDist < 2000) {
    // REUSE existing label — update text and reposition
    const fontName = bestLabel.fontName;

    // fontName returns a Symbol if the text has mixed fonts — can't reuse
    if (typeof fontName === "symbol" || fontName === figma.mixed) {
      // Mixed fonts — delete and create fresh
      bestLabel.remove();
      const label = figma.createText();
      label.fontName = { family: "Inter", style: "Medium" };
      label.fontSize = 70;
      label.characters = newText;
      label.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }];
      container.appendChild(label);
      label.x = screen.x;
      label.y = screen.y - 70 - label.height;
      mutatedIds.push(label.id);
      usedLabels.add(bestLabel.id);
    } else {
      // Load the EXACT font the existing label uses, not Inter
      await figma.loadFontAsync(fontName);
      if (bestLabel.characters !== newText) {
        bestLabel.characters = newText;
      }
      bestLabel.x = screen.x;
      bestLabel.y = screen.y - 70 - bestLabel.height;
      usedLabels.add(bestLabel.id);
      mutatedIds.push(bestLabel.id);
    }
  } else {
    // CREATE new label only for screens with no matching existing label
    const label = figma.createText();
    label.fontName = { family: "Inter", style: "Medium" };
    label.fontSize = 70;
    label.characters = newText;
    label.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }];
    container.appendChild(label);
    label.x = screen.x;
    label.y = screen.y - 70 - label.height;
    mutatedIds.push(label.id);
  }
}

// Leftover labels with no matching screen — ask user before removing
const orphanedLabels = existingLabels.filter(l => !usedLabels.has(l.id));

return {
  reused: usedLabels.size,
  created: mutatedIds.length - usedLabels.size,
  orphaned: orphanedLabels.map(l => ({ id: l.id, text: l.characters })),
  mutatedNodeIds: mutatedIds
};
```

**Font fallback:** If Inter loading fails, try "Roboto" then "Arial". Inform the user which font was used.

**Key rule: NEVER delete existing labels without explicit user consent.** The code above reuses existing text nodes by updating `.characters` and repositioning. New text nodes are only created for screens that don't have a nearby existing label. Orphaned labels (no matching screen) are reported back — ask the user what to do with them.

## Step 7: Validate Labels

Call `get_screenshot` on the section. Verify:
- Labels appear above each screen, not overlapping
- Label text is readable
- Label spacing is consistent

Fix any issues before proceeding.

## Step 8: Resize Section(s) to Fit Content

Calculate content bounds and resize. If sub-sections were created, resize each sub-section first, then the parent.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

// Resize a section to fit its content
function resizeToFit(section) {
  let maxX = 0, maxY = 0;
  for (const child of section.children) {
    const right = child.x + child.width;
    const bottom = child.y + child.height;
    if (right > maxX) maxX = right;
    if (bottom > maxY) maxY = bottom;
  }
  const padding = 100;
  section.resizeWithoutConstraints(maxX + padding, maxY + padding);
}

const parent = figma.getNodeById("<sectionId>");

// If sub-sections exist, resize each first
for (const child of parent.children) {
  if (child.type === "SECTION") resizeToFit(child);
}

// Then resize parent
resizeToFit(parent);

return { resized: true };
```

## Step 9: Final Validation

Call `get_screenshot` on the full section/frame. Verify:
- Screens aligned within each section/sub-section
- Labels positioned above each screen with consistent gap
- Sub-sections properly stacked and styled
- No overlapping or clipped elements
- All sections properly sized

Fix any issues before showing the user.

## Step 10: Present Result

Show the user the final screenshot and summarize:

> **Done.** Organized X screens into Y section(s) with labels.
>
> **Spacing defaults used:**
> - Label gap: 70px | Screen gap: 200px | Padding: 100px
>
> Want to adjust spacing, grouping, or layout direction?
>
> **Next steps:** Want to add dev notes or optimize for MCP? (I can invoke design-annotations or mcp-optimize)

If the user requests changes, re-run the relevant steps with updated values.
