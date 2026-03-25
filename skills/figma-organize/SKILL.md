---
name: figma-organize
description: Use when organizing Figma design screens into labeled, spaced layouts with optional dev notes and sub-sections. Triggers include requests to organize screens, arrange frames, clean up a section, add labels, group screens, or re-format a layout.
---

# Figma Organize

Organize scattered design screens inside a Figma section or frame into a clean, labeled layout with optional dev notes and sub-section grouping. Works on any node type — frames, groups, images, shapes, vectors. Handles both fresh organization and re-formatting existing layouts.

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
| **8** | Add dev notes (if requested) |
| **9** | Resize section(s) to fit content |
| **10** | Final validation (get_screenshot) |
| **11** | Present result, offer adjustments |

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

## Step 1: Parse User Intent

The user has already provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

**Parse inline preferences first.** Check if the user's message already answers any of these:
- Labels preference (e.g., "no labels", "auto-label", "label these screens")
- Dev notes preference (e.g., "no dev notes", "add Developer Note component")
- Grouping preference (e.g., "group by feature", "keep flat")

**Only ask about unresolved choices.** If the user said "organize this, no dev notes" — don't ask about dev notes. Combine remaining questions into one `AskUserQuestion`:

> **Labels:**
> - A) Use element names (default, fast)
> - B) Auto-detect from content (I'll screenshot each element and generate descriptive labels — great for screenshot dumps with meaningless filenames)
> - C) No labels
>
> **Dev notes:**
> - A) Yes — what's the component name? (e.g., "Developer Note")
> - B) Yes — use a default note template
> - C) No

Skip questions the user already answered inline.

## Step 2: Read Container and Classify Children

Find the correct page and read the target node's children. **Critical:** the section/frame won't be found on the default page — you must iterate all pages.

```javascript
// Find the correct page by searching for a known child node
// First, get_metadata on the nodeId to find child IDs
// Then search for a child across pages:
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const target = figma.getNodeById("<childId>");
  if (target) break;
}
```

**Why search for a child, not the section itself:** Section nodes may return `children.length === 0` when accessed from the wrong page. Finding a child node first guarantees the page content is loaded.

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

## Step 2b: Save Version History

**Before making any changes**, create a Figma version snapshot so the user can revert if needed. Figma has no undo for MCP changes — this is the safety net.

```javascript
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

await figma.saveVersionHistoryAsync(
  "Before Figma Organize",
  "Auto-saved before running figma-organize skill"
);

return { versionSaved: true };
```

Inform the user:
> Saved a version snapshot ("Before Figma Organize") — you can revert from Figma's version history if anything goes wrong.

## Step 3: Handle Existing Labels

**Never delete labels without asking.** If existing labels were found in Step 2, present them to the user:

> **Found X existing labels:**
> - "Submissions > List View"
> - "Onboarding > Step 1"
> - ...
>
> What should I do with them?
> - A) **Keep & reposition** (default) — move them to correct positions above their screens
> - B) **Update** — replace with auto-detected or new labels
> - C) **Remove** — strip all existing labels

If user chooses **A (keep):** skip label deletion, reposition in Step 6.
If user chooses **B (update):** delete existing labels, create new ones in Step 6.
If user chooses **C (remove):** delete existing labels, skip Step 6.

For existing notes, apply the same approach — ask if there are existing notes.

**If no existing labels/notes found:** skip this step entirely.

```javascript
// Only if user chose B or C — delete labels
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");
const toDelete = [];

for (const child of container.children) {
  if (child.type === "TEXT") toDelete.push(child);
  // Add notes if user also chose to remove them
}

for (const node of toDelete) node.remove();

return { deleted: toDelete.length };
```

## Step 4: Arrange Screens

**Layout defaults:**

| Setting | Default |
|---------|---------|
| Section padding | 100px |
| Label-to-screen gap | 70px |
| Screen-to-note gap | 50px |
| Note-to-next-screen gap | 200px |
| Screen-to-screen gap (no notes) | 200px |
| Label font | Inter Medium, 70pt |
| Label color | White `{r:1, g:1, b:1}` |
| Default note width | 400px |

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
// notesEnabled = true if user chose A or B for dev notes in Step 1
const startY = <labelsEnabled> ? padding + labelHeight + labelGap : padding;

const screenToNoteGap = 50;
const noteWidth = 400;
const noteToNextGap = 200;
const screenToScreenGap = 200;

let currentX = padding;

for (const screen of screens) {
  screen.x = currentX;
  screen.y = startY;
  if (<notesEnabled>) {
    currentX += screen.width + screenToNoteGap + noteWidth + noteToNextGap;
  } else {
    currentX += screen.width + screenToScreenGap;
  }
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

// Match parent section's fill color for sub-section styling
if (parentSection.fills && parentSection.fills.length > 0) {
  subSection.fills = [...parentSection.fills];
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

## Step 5: Validate Arrangement

Call `get_screenshot` on the section/frame. Verify:
- All screens horizontally aligned within each section/sub-section
- Consistent spacing between screens
- Sub-sections properly stacked (vertical or horizontal)
- No overlapping elements

Fix any issues before proceeding.

## Step 6: Add/Reposition Labels

Depends on Step 3 choice:
- **Keep & reposition:** Move existing label text nodes to correct positions above their associated screens
- **Update / Fresh:** Create new labels

### Creating labels

Two modes depending on user choice:

**Mode A: Use element names (default)**

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

await figma.loadFontAsync({ family: "Inter", style: "Medium" });

const container = figma.getNodeById("<nodeId>");

// Re-collect screens (same filter as Step 4)
const screens = container.children
  .filter(c => { /* same screen filter — exclude TEXT nodes and notes */ })
  .sort((a, b) => a.x - b.x || a.y - b.y);

const createdIds = [];

for (const screen of screens) {
  const label = figma.createText();
  label.fontName = { family: "Inter", style: "Medium" };
  label.fontSize = 70;
  label.characters = screen.name;
  label.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }];

  container.appendChild(label);
  label.x = screen.x;
  label.y = screen.y - 70 - label.height; // 70px gap

  createdIds.push(label.id);
}

return { labelsCreated: createdIds.length, createdNodeIds: createdIds };
```

**Font fallback:** If Inter loading fails, try "Roboto" then "Arial". Inform the user which font was used.

**Mode B: Auto-detect from content**

1. Call `get_screenshot` on each individual screen element (by node ID) — this happens outside `use_figma`, using the MCP screenshot tool directly
2. Analyze the screenshot content — identify what the screen shows
3. Generate a short, descriptive label (e.g., "Event Types Overview", "Booking Preview", "Share > Link")
4. Build a label map: `[{ id, label }, ...]`
5. Use the same `use_figma` code as Mode A (including the page-switch preamble and `loadFontAsync` call), but substitute the auto-generated labels instead of `screen.name`

**Guidelines for auto-generated labels:**
- Keep labels short (2-5 words)
- Use `>` as a hierarchy separator when the screen shows a sub-view (e.g., "Share > Link")
- Focus on the primary content/feature shown, not the UI chrome
- For modals/dialogs, name the modal (e.g., "Calendar Invitation Email")
- For settings panels, name the setting category (e.g., "Limits & Buffers")

### Repositioning existing labels

If user chose "keep & reposition" in Step 3, match each existing label to its nearest screen by x-position and move it above:

```javascript
// For each existing label, find the closest screen and reposition
for (const label of existingLabels) {
  const labelNode = figma.getNodeById(label.id);
  // Find closest screen by x-position
  const closestScreen = screens.reduce((closest, s) =>
    Math.abs(s.x - label.x) < Math.abs(closest.x - label.x) ? s : closest
  );
  labelNode.x = closestScreen.x;
  labelNode.y = closestScreen.y - 70 - labelNode.height;
}
```

## Step 7: Validate Labels

Call `get_screenshot` on the section. Verify:
- Labels appear above each screen, not overlapping
- Label text is readable
- Label spacing is consistent

Fix any issues before proceeding to dev notes.

## Step 8: Add Dev Notes (if requested)

### Path A: User-provided component

1. Call `search_design_system` with the component name the user provided
2. Check `assetType` in results:
   - `component` → `await figma.importComponentByKeyAsync(componentKey)`
   - `component_set` → `await figma.importComponentSetByKeyAsync(componentKey)`, pick default variant (first child)
3. For each screen: `createInstance()`, position at `screen.x + screen.width + 50`, `screen.y`
4. Append to container
5. Return all instance IDs

If `search_design_system` returns no results, inform the user and offer the default template instead.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");

// Import component (adjust based on assetType)
const component = await figma.importComponentByKeyAsync("<componentKey>");
// OR for component_set:
// const componentSet = await figma.importComponentSetByKeyAsync("<componentKey>");
// const component = componentSet.children[0]; // default variant

const screens = container.children
  .filter(c => { /* same screen filter */ })
  .sort((a, b) => a.x - b.x || a.y - b.y);

const createdIds = [];

for (const screen of screens) {
  const instance = component.createInstance();
  container.appendChild(instance);
  instance.x = screen.x + screen.width + 50;
  instance.y = screen.y;
  createdIds.push(instance.id);
}

return { notesCreated: createdIds.length, createdNodeIds: createdIds };
```

### Path B: Default note template

**This entire block must run in a single `use_figma` call** since the template reference only exists within that execution context:

```javascript
// Switch page, load fonts
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

await figma.loadFontAsync({ family: "Inter", style: "SemiBold" });
await figma.loadFontAsync({ family: "Inter", style: "Regular" });

const container = figma.getNodeById("<nodeId>");

// Create template note
const note = figma.createFrame();
note.name = "Dev Note";
note.resize(400, 1);
note.layoutMode = "VERTICAL";
note.paddingTop = 24; note.paddingBottom = 24;
note.paddingLeft = 24; note.paddingRight = 24;
note.itemSpacing = 16;
note.primaryAxisSizingMode = "AUTO";
note.counterAxisSizingMode = "FIXED";
note.cornerRadius = 12;
note.fills = [{ type: "SOLID", color: { r: 1, g: 0.98, b: 0.94 } }];
note.strokes = [{ type: "SOLID", color: { r: 0.85, g: 0.85, b: 0.85 } }];
note.strokeWeight = 1;

const title = figma.createText();
title.fontName = { family: "Inter", style: "SemiBold" };
title.fontSize = 20;
title.characters = "Dev Note";
title.fills = [{ type: "SOLID", color: { r: 0.1, g: 0.1, b: 0.1 } }];
note.appendChild(title);
title.layoutSizingHorizontal = "FILL"; // MUST be AFTER appendChild

const body = figma.createText();
body.fontName = { family: "Inter", style: "Regular" };
body.fontSize = 14;
body.characters = "Add development notes here...";
body.fills = [{ type: "SOLID", color: { r: 0.4, g: 0.4, b: 0.4 } }];
note.appendChild(body);
body.layoutSizingHorizontal = "FILL"; // MUST be AFTER appendChild

// Position the template note off-screen temporarily
container.appendChild(note);
note.x = -1000;
note.y = -1000;

// Clone for each screen
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c === note) return false; // skip the template
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
  .sort((a, b) => a.x - b.x || a.y - b.y);

const createdIds = [];

for (const screen of screens) {
  const clone = note.clone();
  container.appendChild(clone);
  clone.x = screen.x + screen.width + 50;
  clone.y = screen.y;
  createdIds.push(clone.id);
}

// Remove the template
note.remove();

return { notesCreated: createdIds.length, createdNodeIds: createdIds };
```

## Step 9: Resize Section(s) to Fit Content

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

## Step 10: Final Validation

Call `get_screenshot` on the full section/frame. Verify:
- Screens aligned within each section/sub-section
- Labels positioned above each screen with consistent gap
- Dev notes (if added) positioned to the right of each screen
- Sub-sections properly stacked and styled
- No overlapping or clipped elements
- All sections properly sized

Fix any issues before showing the user.

## Step 11: Present Result

Show the user the final screenshot and summarize:

> **Done.** Organized X screens into Y section(s) with labels and dev notes.
>
> **Spacing defaults used:**
> - Label gap: 70px | Screen-to-note: 50px | Note-to-next: 200px | Padding: 100px
>
> Want to adjust spacing, grouping, or layout direction?

If the user requests changes, re-run the relevant steps with updated values.
