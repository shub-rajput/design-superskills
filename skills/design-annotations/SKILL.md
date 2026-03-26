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
| **4** | Dev notes: add new / reposition / improve copy |
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

## Step 1: Parse User Intent

The user has provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

**Detect intent from the user's message:**

| Intent detected | Path taken |
|----------------|------------|
| "add dev notes," "place notes" | Straight to add-new-notes flow (Step 4, Path A or B) |
| "improve copy," "update notes," "better dev notes" | Straight to improve-copy flow (Step 4, Path C) |
| Ambiguous (e.g., just a link + "annotations") | Classify children first (Step 2), then ask |

If intent is clear, skip the ambiguity questions in Step 2 and go directly to the relevant path.

## Step 2: Read Container and Classify Children

Find the correct page and read the target node's children. **Critical:** the section/frame won't be found on the default page — you must iterate all pages.

**Page discovery approach:** Use a single `use_figma` call that iterates all pages, trying to find the section AND access its children.

```javascript
// Iterate all pages to find the one where this section has children
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const section = figma.getNodeById("<nodeId>");
  if (section && section.children && section.children.length > 0) {
    // Found the right page — children are loaded
    break;
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

## Step 3: Version Safety

**Before making any changes**, ask the user to save a version manually:

> **Before I start making changes** — please save a named version in Figma (File → Save to Version History) so you can revert if needed. Figma has no undo for MCP changes.
>
> Let me know when you're ready to proceed.

Wait for confirmation before continuing to Step 4.

## Step 4: Dev Notes

### Path A: Add New Notes (user-provided component)

1. Ask for component name if not provided in the user's message
2. Call `mcp__figma__search_design_system` with the component name
3. Check `assetType` in results:
   - `component` → `await figma.importComponentByKeyAsync(componentKey)`
   - `component_set` → `await figma.importComponentSetByKeyAsync(componentKey)`, pick default variant (first child)
4. For each screen: `createInstance()`, position at `screen.x + screen.width + 50`, `screen.y`
5. Append to container
6. Return all instance IDs

If `search_design_system` returns no results, inform the user and offer the default template (Path B) instead.

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
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
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

### Path B: Add New Notes (default template)

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

### Path C: Improve Existing Copy

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
