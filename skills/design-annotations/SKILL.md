---
name: design-annotations
description: Use when adding, repositioning, or improving dev note components next to Figma design screens. Triggers include requests to add dev notes, place annotations, improve dev note copy, or update existing notes.
---

# Design Annotations

Add, reposition, or improve dev note components next to design screens in Figma. Works with design system components or a default note template. Chains from design-organize but also works standalone.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification. If a screenshot reveals a problem, fix it before proceeding.

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Parse user intent |
| **2** | Read container, classify children (screens vs labels vs notes) |
| **3** | Version safety — save Figma version |
| **3b** | Determine note width (component variant or default 400px) |
| **4** | Reposition screens/labels for note width, then place notes |
| **5** | Validate (get_screenshot) |
| **6** | Present result, offer mcp-optimize |

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
   - **Section node gotcha:** Figma SECTION nodes may silently discard or auto-reparent children that spatially overlap existing frames between script executions. If you create labels or notes as direct children of a SECTION and they vanish on the next `use_figma` call, try: (1) position them so they don't overlap any frame bounds, or (2) use a parent FRAME inside the section as the container instead. Always verify children exist with a read-back call before proceeding.
   - **Stop on repeated failure:** If the same operation fails twice with the same outcome (e.g., nodes vanish after creation), STOP and investigate the root cause. Do not retry blindly — it wastes rounds. Read back the container's children to understand what happened before attempting a fix.

## Step 1: Parse User Intent

The user has provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

**Detect intent from the user's message:**

| Intent detected | Path taken |
|----------------|------------|
| "add dev notes," "place notes" | Straight to add-new-notes flow (Step 4, Path A or B) |
| "improve copy," "update notes," "better dev notes" | Straight to improve-copy flow (Step 4, Path C) |
| Ambiguous (e.g., just a link + "annotations") | Classify children first (Step 2), then ask |

If intent is clear, skip the ambiguity questions in Step 2 and go directly to the relevant path.

**Even when intent is clear, you MUST still ask about preferences before creating notes.** Do not assume defaults — always confirm:

> **Which screens get dev notes?**
> - A) All screens
> - B) Let me pick (I'll list the screens for you to choose)
>
> **Format:**
> - A) Use a component from your design system (I'll search for it)
> - B) Use a default note template
>
> **Content:**
> - A) Pre-fill with AI-generated descriptions (I'll screenshot each screen)
> - B) Leave empty for manual editing

Skip only questions the user's message already answers (e.g., "add Developer Note components to all screens, leave empty").

## Step 2: Read Container and Classify Children

Find the correct page and read the target node's children. **Critical:** the section/frame won't be found on the default page — you must iterate all pages.

**Page discovery approach:** Use a single `use_figma` call that iterates all pages, trying to find the section AND access its children.

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

Once on the correct page, classify children:

```javascript
const container = figma.getNodeById("<nodeId>");
const screens = [];
const existingLabels = [];
const existingNotes = [];

for (const child of container.children) {
  if (child.visible === false) continue;

  if (child.type === "TEXT") {
    existingLabels.push({
      id: child.id, name: child.name,
      characters: child.characters,
      x: child.x, y: child.y,
      width: child.width, height: child.height
    });
  }
  else if ((child.type === "INSTANCE" && child.width <= 450) ||
           (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    existingNotes.push({
      id: child.id, name: child.name,
      x: child.x, y: child.y,
      width: child.width, height: child.height
    });
  }
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
  existingNotes
};
```

**Important:** Store one screen ID as `<childId>` for the page-switch preamble in subsequent `use_figma` calls.

**Classification rules:**

| Type | Detection |
|------|-----------|
| **Label** | `type === "TEXT"` (any direct-child text node) |
| **Note (instance)** | `type === "INSTANCE"` AND `width <= 450` |
| **Note (default)** | `type === "FRAME"` AND `name === "Dev Note"` AND `width <= 450` |
| **Screen** | Everything else that's visible |

**If intent was ambiguous, ask now:**

When existing notes are found:

> **Found X existing dev notes.** What would you like to do?
> - A) Reposition them next to their screens
> - B) Improve their copy (I'll suggest better versions for each)
> - C) Leave them as-is and add notes to screens that don't have them

When no existing notes are found:

> **No dev notes found.** I'll add them. Which format?
> - A) Use a component from your design system (I'll search for it)
> - B) Use a default note template

**If user chose "let me pick" for screen selection in Step 1**, list the screens now:

> **Found X screens. Which ones get dev notes?**
> 1. Screen Name A (1280×800)
> 2. Screen Name B (1280×800)
> 3. ...
>
> Enter numbers (e.g., "1, 3, 5") or "all"

Store selected IDs as `selectedScreenIds` for Steps 4a and 4b.

## Step 3: Version Safety

**Before making any changes**, ask the user to save a version manually:

> **Before I start making changes** — please save a named version in Figma (File → Save to Version History) so you can revert if needed. Figma has no undo for MCP changes.
>
> Let me know when you're ready to proceed.

Wait for confirmation before continuing to Step 4.

## Step 3b: Determine Note Width

**Before placing any notes, you must know the note width.** This is needed to pre-allocate space in Step 4.

**For Path A (component):**
1. Ask for component name if not provided in the user's message
2. Call `mcp__figma__search_design_system` with the component name
3. Check `assetType` in results:
   - `component` → `await figma.importComponentByKeyAsync(componentKey)`
   - `component_set` → import it, then **list all variants and ask the user which one to use**. Do NOT silently pick the default — it may be the wrong size (e.g., XL instead of Normal).
4. **Create ONE test instance** and report its dimensions. Confirm before proceeding.
5. Record `noteWidth` from the test instance. Remove it (or keep it for the first screen).

If `search_design_system` returns no results, inform the user and offer the default template (Path B).

**For Path B (default template):** `noteWidth = 400` (fixed width).

**For Path C (improve copy):** Skip this step — no new notes placed, no repositioning needed.

## Step 4: Reposition Screens & Labels, Then Place Notes

**Critical: reposition BEFORE placing notes.** Notes overlap adjacent screens if screens aren't spaced for them. The correct order is:

1. Determine which screens get notes (all, or user-selected subset from Step 1)
2. Calculate new spacing: screens WITH notes get `noteGap (50) + noteWidth + screenToNextGap (200)`. Screens WITHOUT notes keep the original gap.
3. Reposition all screens and their labels
4. Place notes in the pre-allocated space
5. Resize the section

### Step 4a: Reposition screens and labels

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");
const noteWidth = <noteWidth>; // from Step 3b
const noteGap = 50; // gap between screen and note
const noteToNextScreenGap = 200; // gap between note and next screen
const screenToScreenGap = 200; // gap for screens without notes

// selectedScreenIds: array of screen IDs that get notes (all screens if user chose A)
// If user chose B (pick specific), this is the subset they selected
const selectedScreenIds = new Set(<selectedScreenIds>);

// Re-read children
const screens = [];
const labels = [];

for (const child of container.children) {
  if (child.visible === false) continue;
  if (child.type === "TEXT") {
    labels.push(child);
  } else if (!(child.type === "INSTANCE" && child.width <= 450) &&
             !(child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    screens.push(child);
  }
}

screens.sort((a, b) => a.x - b.x || a.y - b.y);

// Match labels to screens by x-proximity (before moving anything)
const labelMap = new Map(); // screenIndex → label
for (const label of labels) {
  let bestIdx = -1;
  let bestDist = Infinity;
  for (let i = 0; i < screens.length; i++) {
    const dist = Math.abs(label.x - screens[i].x);
    if (dist < bestDist) { bestDist = dist; bestIdx = i; }
  }
  if (bestIdx >= 0 && bestDist < 2000) {
    labelMap.set(bestIdx, label);
  }
}

// Reposition each screen with space for a note to its right
const padding = 100;
let currentX = screens[0].x; // preserve starting position
const mutatedIds = [];

for (let i = 0; i < screens.length; i++) {
  const screen = screens[i];
  const oldX = screen.x;
  screen.x = currentX;
  mutatedIds.push(screen.id);

  // Move label to follow screen
  const label = labelMap.get(i);
  if (label) {
    label.x = currentX;
    mutatedIds.push(label.id);
  }

  // Screens with notes get extra space; screens without keep normal gap
  if (selectedScreenIds.has(screen.id)) {
    currentX += screen.width + noteGap + noteWidth + noteToNextScreenGap;
  } else {
    currentX += screen.width + screenToScreenGap;
  }
}

// Resize section to fit
let maxX = 0, maxY = 0;
for (const child of container.children) {
  const right = child.x + child.width;
  const bottom = child.y + child.height;
  if (right > maxX) maxX = right;
  if (bottom > maxY) maxY = bottom;
}
container.resizeWithoutConstraints(maxX + padding, maxY + padding);

return { repositioned: mutatedIds.length, mutatedNodeIds: [...new Set(mutatedIds)] };
```

**Verify with `get_screenshot`** that screens are evenly spaced with visible gaps for notes.

### Step 4b: Place notes (Path A or B)

#### Path A: Add New Notes (user-provided component)

Screens are already repositioned from Step 4a. Place notes in the pre-allocated space:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");

// Import component (adjust based on assetType)
const component = await figma.importComponentByKeyAsync("<componentKey>");
// OR for component_set — list variants, DO NOT auto-pick default:
// const componentSet = await figma.importComponentSetByKeyAsync("<componentKey>");
// const variants = componentSet.children.map(c => ({
//   name: c.name, width: c.width, height: c.height
// }));
// return { variants }; // Present to user, ask which one
// Then: const component = componentSet.children.find(c => c.name === "<chosen variant>");

// Only annotate selected screens (selectedScreenIds from Step 1)
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
  .filter(c => selectedScreenIds.has(c.id))
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

#### Path B: Add New Notes (default template)

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

// Clone for each selected screen
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c === note) return false; // skip the template
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
  .filter(c => selectedScreenIds.has(c.id))
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

#### Path C: Improve Existing Copy

Use when existing dev notes are found and the user wants to improve their text content.

1. Read all existing note content via `use_figma`:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");
const notes = [];
const screens = [];

for (const child of container.children) {
  if (child.visible === false) continue;
  if ((child.type === "INSTANCE" && child.width <= 450) ||
      (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450)) {
    // Extract text from note — walk children to find text nodes
    const textParts = [];
    function collectText(node) {
      if (node.type === "TEXT") {
        textParts.push({ name: node.name, characters: node.characters, id: node.id });
      }
      if (node.children) {
        for (const child of node.children) collectText(child);
      }
    }
    collectText(child);
    notes.push({
      id: child.id, name: child.name,
      x: child.x, y: child.y,
      textParts
    });
  } else if (child.type !== "TEXT") {
    screens.push({
      id: child.id, name: child.name,
      x: child.x, y: child.y,
      width: child.width, height: child.height
    });
  }
}

// Match notes to screens by x-proximity
const matched = notes.map(note => {
  let bestScreen = null;
  let bestDist = Infinity;
  for (const screen of screens) {
    const dist = Math.abs(note.x - (screen.x + screen.width));
    if (dist < bestDist) { bestDist = dist; bestScreen = screen; }
  }
  return { note, screen: bestScreen };
});

return { matched, screenIds: screens.map(s => s.id) };
```

2. Screenshot each screen using `get_screenshot` for visual context (the screen ID, not the note). Use this to understand what the screen shows.

3. For each note, generate improved copy — tighter wording, better structure, clearer for devs. Focus on what developers need to know: component behavior, state handling, data sources, interactions.

4. Present all suggestions in a summary for user confirmation:

> **Suggested copy improvements:**
>
> | Screen | Current | Suggested |
> |--------|---------|-----------|
> | Dashboard | "Add notes here..." | "Main dashboard view. Stats row shows real-time metrics..." |
> | Settings | "Settings page" | "General settings with 3 toggle groups: notifications, privacy, display..." |
>
> Confirm all, or tell me which ones to adjust?

5. User confirms all, edits individual suggestions, or rejects specific ones.

6. Bulk update all confirmed notes via a single `use_figma` call:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

// updates is an array of { textNodeId, newText } from confirmed suggestions
const mutatedIds = [];

for (const update of updates) {
  const textNode = figma.getNodeById(update.textNodeId);
  if (textNode && textNode.type === "TEXT") {
    const fontName = textNode.fontName;
    if (typeof fontName !== "symbol" && fontName !== figma.mixed) {
      await figma.loadFontAsync(fontName);
      textNode.characters = update.newText;
      mutatedIds.push(textNode.id);
    }
  }
}

return { updated: mutatedIds.length, mutatedNodeIds: mutatedIds };
```

## Step 5: Validate

Call `get_screenshot` on the section. Verify:
- Notes positioned correctly next to their screens (not overlapping)
- Note text is readable
- Spacing is consistent

Fix any issues before presenting to the user.

## Step 6: Present Result

Show the user the final screenshot and summarize:

> **Done.** Added/updated X dev notes across Y screens.
>
> Want to adjust anything?
>
> **Next step:** Want me to create an MCP-optimized version of these screens? (I can invoke mcp-optimize)
