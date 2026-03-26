---
name: mcp-optimize
description: Use when creating MCP-optimized versions of Figma design screens for AI consumption. Clones screens, breaks them into lightweight sections based on frame hierarchy, replaces heavy assets with placeholders, and extracts originals into an Assets section. Triggers include requests to optimize for MCP, prepare for dev, make AI-readable, or create dev sections.
---

# MCP Optimize

Clone design screens and create lightweight, AI-readable versions optimized for MCP consumption. Breaks pages into sections based on frame hierarchy, replaces heavy illustrations and images with labeled placeholders, and extracts originals into an Assets section for dev reference. Chains from design-organize or design-annotations but also works standalone.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification.

> **Assumption:** Designs use auto-layout or at least proper frames. This skill reads the existing frame hierarchy — it does not convert flat designs to auto-layout. Users should ensure their pages are properly structured before invoking this skill.

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Parse user intent |
| **2** | Read container, classify children |
| **3** | Version safety |
| **4** | Clone screens into "MCP Dev Ready" section |
| **5** | Read frame hierarchy, propose sections, confirm |
| **6** | Create section frames, replace heavy assets, create Assets section |
| **7** | Resize & validate (get_screenshot) |
| **8** | Present result |

## Step 0: Prerequisites

1. **Figma MCP server** — check if `mcp__figma__use_figma` tool is available. If NOT available, tell the user:

> This skill requires the Figma MCP server. Run:
> ```
> claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
> ```
> Then restart Claude Code.

Do NOT proceed without it.

2. **figma-use skill** — load `figma:figma-use` via the Skill tool before making any `use_figma` call. If unavailable, proceed but follow these critical rules yourself:
   - Every `use_figma` call must switch page via `setCurrentPageAsync` first
   - Colors use 0-1 range (not 0-255)
   - Fills/strokes are read-only — clone, modify, reassign as new arrays
   - `loadFontAsync` before any text property changes
   - `layoutSizingHorizontal/Vertical = "FILL"` must be set AFTER `appendChild`
   - Always `return` all created/mutated node IDs

## Step 1: Parse User Intent

The user has provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

No ambiguity questions needed — if this skill is invoked, the user wants MCP optimization.

## Step 2: Read Container and Classify Children

Same page-discovery approach as design-organize. Iterate all pages to find the section, classify children to identify screens (skip labels and notes).

```javascript
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const section = figma.getNodeById("<nodeId>");
  if (section && section.children && section.children.length > 0) break;
}

const container = figma.getNodeById("<nodeId>");
const screens = [];

for (const child of container.children) {
  if (child.visible === false) continue;
  if (child.type === "TEXT") continue; // skip labels
  if (child.type === "INSTANCE" && child.width <= 450) continue; // skip note instances
  if (child.type === "FRAME" && child.name === "Dev Note" && child.width <= 450) continue; // skip default notes
  screens.push({
    id: child.id, name: child.name,
    x: child.x, y: child.y,
    width: child.width, height: child.height
  });
}

return { screens: screens.sort((a, b) => a.x - b.x || a.y - b.y) };
```

Store one screen ID as `<childId>` for the page-switch preamble.

## Step 3: Version Safety

**Before making any changes**, ask the user to save a version manually:

> **Before I start making changes** — please save a named version in Figma (File → Save to Version History) so you can revert if needed. Figma has no undo for MCP changes.
>
> Let me know when you're ready to proceed.

Wait for confirmation.

## Step 4: Clone Screens

Clone each screen into a new "MCP Dev Ready" section. **Order matters:** clone then move, per screen.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const container = figma.getNodeById("<nodeId>");

// Create the MCP section
const mcpSection = figma.createSection();
mcpSection.name = "MCP Dev Ready";
container.appendChild(mcpSection);

// Collect screens
const screens = container.children
  .filter(c => {
    if (c.visible === false) return false;
    if (c.type === "TEXT") return false;
    if (c === mcpSection) return false;
    if (c.type === "INSTANCE" && c.width <= 450) return false;
    if (c.type === "FRAME" && c.name === "Dev Note" && c.width <= 450) return false;
    return true;
  })
  .sort((a, b) => a.x - b.x || a.y - b.y);

// Clone each screen and move immediately into MCP section
const padding = 100;
const gap = 200;
let currentX = padding;
const cloneIds = [];

for (const screen of screens) {
  const clone = screen.clone();
  mcpSection.appendChild(clone);
  clone.x = currentX;
  clone.y = padding;
  currentX += clone.width + gap;
  cloneIds.push(clone.id);
}

// Resize MCP section to fit
mcpSection.resizeWithoutConstraints(currentX + padding, padding + Math.max(...screens.map(s => s.height)) + padding);

return { cloned: cloneIds.length, mcpSectionId: mcpSection.id, cloneIds };
```

Verify with `get_screenshot` that clones appear in the new section and originals are untouched.

## Step 5: Read Frame Hierarchy & Propose Sections

For each cloned screen, read its top-level auto-layout children to identify natural sections.

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

// cloneIds from Step 4
const proposals = [];

for (const cloneId of cloneIds) {
  const clone = figma.getNodeById(cloneId);
  const sections = [];
  for (const child of clone.children) {
    sections.push({
      id: child.id,
      name: child.name,
      type: child.type,
      width: child.width,
      height: child.height,
      hasAutoLayout: !!child.layoutMode,
      childCount: child.children ? child.children.length : 0
    });
  }
  proposals.push({
    screenName: clone.name,
    cloneId: cloneId,
    sections
  });
}

return { proposals };
```

Present the breakdown for each screen and ask for confirmation:

> **Screen: Dashboard**
> - Header (nav + breadcrumb) — 1280x80, auto-layout
> - Stats Row (4 stat cards) — 1280x200, auto-layout
> - Main Content (table + filters) — 1280x600, auto-layout
> - Footer — 1280x60, auto-layout
>
> **Screen: Settings**
> - ...
>
> Confirm all, or adjust specific screens?

For 10+ screens, offer a "confirm all" shortcut to avoid tedious per-screen confirmation.

## Step 6: Create Section Frames, Replace Heavy Assets, Build Assets Section

### 6a: Create section frames

For each confirmed section breakdown, reparent children into named frames:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

const mcpSection = figma.getNodeById("<mcpSectionId>");

// For each screen's confirmed sections
for (const proposal of confirmedProposals) {
  const clone = figma.getNodeById(proposal.cloneId);

  for (const sectionDef of proposal.sections) {
    const child = figma.getNodeById(sectionDef.id);
    // Create a new frame as direct child of MCP section
    const frame = figma.createFrame();
    frame.name = clone.name + " > " + child.name;
    frame.resize(child.width, child.height);
    mcpSection.appendChild(frame);

    // Reparent the child into the new frame
    frame.appendChild(child);
    child.x = 0;
    child.y = 0;
  }

  // Remove the now-empty clone frame
  clone.remove();
}

return { sectionsCreated: /* count */ };
```

### 6b: Identify heavy assets

Scan all section frames for heavy assets using these heuristics:

```javascript
function isHeavyAsset(node) {
  // Image fills
  if (node.fills && Array.isArray(node.fills)) {
    for (const fill of node.fills) {
      if (fill.type === "IMAGE") return true;
    }
  }

  // Vector groups: >20 direct vector/boolean children, no auto-layout
  if ((node.type === "GROUP" || node.type === "FRAME") && !node.layoutMode) {
    if (node.children) {
      const vectorChildren = node.children.filter(c =>
        c.type === "VECTOR" || c.type === "BOOLEAN_OPERATION"
      );
      if (vectorChildren.length > 20) return true;
    }
  }

  // Large unstructured groups: >200px wide, no layoutMode
  if (node.type === "GROUP" && node.width > 200 && !node.layoutMode) return true;

  // Deep illustrations: vector/boolean nesting depth >5
  function maxVectorDepth(n, depth) {
    if (n.type === "VECTOR" || n.type === "BOOLEAN_OPERATION") {
      if (depth > 5) return depth;
    }
    if (n.children) {
      let max = depth;
      for (const child of n.children) {
        max = Math.max(max, maxVectorDepth(child, depth + 1));
      }
      return max;
    }
    return depth;
  }
  if (maxVectorDepth(node, 0) > 5) return true;

  return false;
}
```

### 6c: Replace with placeholders and build Assets section

```javascript
// Create Assets section as sibling to MCP section
const container = figma.getNodeById("<parentSectionId>");
const assetsSection = figma.createSection();
assetsSection.name = "Assets";
container.appendChild(assetsSection);

await figma.loadFontAsync({ family: "Inter", style: "Regular" });

const assetPadding = 100;
const assetGap = 50;
let assetX = assetPadding;
let maxAssetHeight = 0;
const replacedIds = [];

// Walk all section frames in MCP section to find heavy assets
const mcpSection = figma.getNodeById("<mcpSectionId>");
for (const frame of mcpSection.children) {
  if (frame.type !== "FRAME") continue;

  function findAndReplace(parent) {
    // Iterate children in reverse to safely modify during iteration
    const children = [...parent.children];
    for (const child of children) {
      if (isHeavyAsset(child)) {
        const origWidth = child.width;
        const origHeight = child.height;
        const origX = child.x;
        const origY = child.y;
        const origName = child.name;
        const origParent = child.parent;
        const origIndex = [...origParent.children].indexOf(child);

        // Move original to Assets section
        assetsSection.appendChild(child);
        child.x = assetX;
        child.y = assetPadding;
        assetX += child.width + assetGap;
        if (child.height > maxAssetHeight) maxAssetHeight = child.height;

        // Create placeholder frame (not rectangle — needs text child)
        const placeholder = figma.createFrame();
        placeholder.name = "placeholder: " + origName;
        placeholder.resize(origWidth, origHeight);
        placeholder.fills = [{ type: "SOLID", color: { r: 0.9, g: 0.9, b: 0.9 } }];
        placeholder.cornerRadius = 8;

        // Add label text
        const label = figma.createText();
        label.fontName = { family: "Inter", style: "Regular" };
        label.fontSize = 14;
        label.characters = origName;
        label.fills = [{ type: "SOLID", color: { r: 0.5, g: 0.5, b: 0.5 } }];
        placeholder.appendChild(label);
        label.x = 12;
        label.y = 12;

        // Insert placeholder at original position
        origParent.insertChild(origIndex, placeholder);
        placeholder.x = origX;
        placeholder.y = origY;

        replacedIds.push({ original: child.id, placeholder: placeholder.id });
      } else if (child.children) {
        findAndReplace(child);
      }
    }
  }

  findAndReplace(frame);
}

// Resize Assets section
assetsSection.resizeWithoutConstraints(
  assetX + assetPadding,
  assetPadding + maxAssetHeight + assetPadding
);

return { assetsExtracted: replacedIds.length, replacedIds };
```

## Step 7: Resize & Validate

Resize the "MCP Dev Ready" section to fit all section frames:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

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

const mcpSection = figma.getNodeById("<mcpSectionId>");
resizeToFit(mcpSection);

// Also resize parent if needed
const parent = figma.getNodeById("<parentSectionId>");
resizeToFit(parent);

return { resized: true };
```

Call `get_screenshot` on the parent section. Verify:
- "MCP Dev Ready" section contains named section frames
- Placeholders are visible with labels (gray boxes)
- "Assets" section contains extracted originals
- No overlapping or clipped elements

Fix any issues before presenting.

## Step 8: Present Result

Show the user a before/after screenshot and summarize:

> **Done.** Created MCP-optimized version with X sections and Y assets extracted.
>
> - **Original screens:** untouched
> - **MCP Dev Ready:** lightweight section frames, heavy assets replaced with labeled placeholders
> - **Assets:** original illustrations and images for dev reference
>
> Want to adjust anything?
