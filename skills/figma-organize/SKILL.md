---
name: figma-organize
description: Use when organizing Figma design screens into labeled, spaced layouts with optional dev notes. Triggers include requests to organize screens, arrange frames, clean up a section, add labels, or re-format a layout.
---

# Figma Organize

Organize scattered design screens inside a Figma section or frame into a clean, labeled horizontal layout with optional dev notes. Works on any node type — frames, groups, images, shapes, vectors. Handles both fresh organization and re-formatting existing layouts.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification. If a screenshot reveals a problem, fix it before proceeding.

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Ask about labels and dev notes (only question) |
| **2** | Read container, classify children (screens vs labels vs notes) |
| **3** | Clean up old labels and notes |
| **4** | Arrange screens — horizontal row, consistent spacing |
| **5** | Validate arrangement (get_screenshot) |
| **6** | Add labels — 70pt Inter Medium |
| **7** | Validate labels (get_screenshot) |
| **8** | Add dev notes (if requested) |
| **9** | Resize section to fit content |
| **10** | Final validation (get_screenshot) |
| **11** | Present result, offer spacing adjustments |

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

## Step 1: Ask About Labels and Dev Notes

The user has already provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

Use AskUserQuestion — one combined question:

> **Labels:**
> - A) Use element names (default, fast)
> - B) Auto-detect from content (I'll screenshot each element and generate descriptive labels — great for screenshot dumps with meaningless filenames like "CleanShot 2025-03-05...")
> - C) No labels
>
> **Dev notes:**
> - A) Yes — what's the component name? (e.g., "Developer Note")
> - B) Yes — use a default note template
> - C) No

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
const oldLabels = [];
const oldNotes = [];

for (const child of container.children) {
  if (child.visible === false) continue;

  // Existing label: text node at 70pt
  if (child.type === "TEXT" && child.fontSize === 70) {
    oldLabels.push(child);
  }
  // Existing note: instance ≤450px wide, or frame named "Dev Note" ≤450px wide
  else if ((child.type === "INSTANCE" && child.width <= 450) ||
           (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    oldNotes.push(child);
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
  oldLabels: oldLabels.length,
  oldNotes: oldNotes.length
};
```

**Important:** Store one screen ID (e.g., the first screen's `id`) as `<childId>` — you'll use it in the page-switch preamble for all subsequent `use_figma` calls.

**Classification rules:**

| Type | Detection |
|------|-----------|
| **Label** | `type === "TEXT"` AND `fontSize === 70` |
| **Note (instance)** | `type === "INSTANCE"` AND `width <= 450` |
| **Note (default)** | `type === "FRAME"` AND `name === "Dev Note"` AND `width <= 450` |
| **Screen** | Everything else that's visible |

## Step 3: Clean Up Old Labels and Notes

If existing labels or notes were found, delete them. They'll be recreated fresh with correct spacing.

```javascript
// Switch page first (find via child node)
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");
const toDelete = [];

for (const child of container.children) {
  if (child.type === "TEXT" && child.fontSize === 70) toDelete.push(child);
  else if (child.type === "INSTANCE" && child.width <= 450) toDelete.push(child);
  else if (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450) toDelete.push(child);
}

for (const node of toDelete) node.remove();

return { deleted: toDelete.length };
```

If no old labels/notes were found in Step 2, skip this step.

## Step 4: Arrange Screens

Position all screens in a horizontal row with consistent spacing.

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

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");

// Collect screens (same filter as Step 2 — exclude labels and notes)
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT" && c.fontSize === 70) return false;
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
// If labels enabled, reserve space above screens
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

## Step 5: Validate Arrangement

Call `get_screenshot` on the section/frame. Verify:
- All screens horizontally aligned at the same y-position
- Consistent spacing between screens
- No overlapping elements

Fix any issues before proceeding. Do NOT add labels on top of misaligned screens.

## Step 6: Add Labels

Two modes depending on user choice:

### Mode A: Use element names (default)

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
  .filter(c => { /* same screen filter */ })
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

### Mode B: Auto-detect from content

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

Create a note frame from scratch. **This entire block must run in a single `use_figma` call** since the template reference only exists within that execution context:

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
    if (c.type === "TEXT" && c.fontSize === 70) return false;
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

## Step 9: Resize Section to Fit Content

Calculate content bounds and resize the section so it wraps all content with padding.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const section = figma.getNodeById("<sectionId>");
let maxX = 0, maxY = 0;

for (const child of section.children) {
  const right = child.x + child.width;
  const bottom = child.y + child.height;
  if (right > maxX) maxX = right;
  if (bottom > maxY) maxY = bottom;
}

const padding = 100;
section.resizeWithoutConstraints(maxX + padding, maxY + padding);

return { newWidth: maxX + padding, newHeight: maxY + padding };
```

## Step 10: Final Validation

Call `get_screenshot` on the full section/frame. Verify:
- Screens aligned horizontally
- Labels positioned above each screen with consistent gap
- Dev notes (if added) positioned to the right of each screen
- No overlapping or clipped elements
- Section properly sized to fit all content

Fix any issues before showing the user.

## Step 11: Present Result

Show the user the final screenshot and summarize:

> **Done.** Organized X screens with labels and dev notes.
>
> **Spacing defaults used:**
> - Label gap: 70px | Screen-to-note: 50px | Note-to-next: 200px | Padding: 100px
>
> Want to adjust spacing?

If the user requests spacing changes, re-run Steps 3-10 with updated values.
