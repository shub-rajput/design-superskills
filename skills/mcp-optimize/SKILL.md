---
name: mcp-optimize
description: Use when creating MCP-optimized versions of Figma design screens for AI consumption. Triggers include requests to optimize for MCP, prepare for dev, make AI-readable, or create dev sections.
---

# MCP Optimize

Clone design screens and create lightweight, AI-readable versions optimized for MCP consumption. Breaks pages into sections based on frame hierarchy, replaces heavy illustrations and images with labeled placeholders, and extracts originals into an Assets section for dev reference. Chains from design-organize or design-annotations but also works standalone.

> **Validation principle:** Every `use_figma` write step must be followed by a `get_screenshot` check. Do not stack writes without visual verification.

> **Assumption:** Designs use auto-layout or at least proper frames. This skill reads the existing frame hierarchy — it does not convert flat designs to auto-layout. Users should ensure their pages are properly structured before invoking this skill.

> **Timeout warning:** Figma MCP timeout errors are **NOT atomic**. A timed-out `use_figma` call may have partially executed — nodes may have been created, cloned, or moved before the timeout. After any timeout, always read back the section's children before retrying or continuing, to detect partial writes. Never assume a timeout means "nothing happened."

## Quick Reference

| Step | What |
|------|------|
| **0** | Prerequisites — Figma MCP required |
| **1** | Parse user intent |
| **2** | Read container, classify children |
| **3** | Version safety |
| **4** | Clone screens into "MCP Dev Ready" section |
| **5** | Read frame hierarchy, propose sections, confirm |
| **6** | Create section frames, export heavy assets as 2x PNG, replace with placeholders |
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

2. **figma-use skill** — load `figma:figma-use` via the Skill tool before any `use_figma` call.

3. **Figma Section gotchas** — critical, cause silent failures:
   - **Page discovery:** FRAME children are accessible cross-page, but TEXT/INSTANCE require the correct page. Verify ALL children have accessible properties (`every(c => c.type !== undefined && c.width !== undefined)`).
   - **Overlapping children:** SECTION nodes may discard children that overlap existing frames between calls. Verify children exist with read-back.
   - **Timeout non-atomicity:** Timed-out `use_figma` calls may have partially executed. Always read back after timeouts.
   - **Stop on repeated failure:** If same operation fails twice, STOP and read back children before retrying.

## Step 1: Parse User Intent

The user has provided a Figma link to a section or frame. Extract `fileKey` and `nodeId` from the URL (convert `-` to `:` in nodeId).

No ambiguity questions needed — if this skill is invoked, the user wants MCP optimization.

## Step 2: Read Container and Classify Children

Same page-discovery approach as design-organize. Iterate all pages to find the section, classify children to identify screens (skip labels and notes).

```javascript
// Page discovery: FRAME children are accessible cross-page, but TEXT and
// INSTANCE nodes require the correct page. Verify ALL children are loaded.
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const section = figma.getNodeById("<nodeId>");
  if (section && section.children && section.children.length > 0) {
    const allAccessible = section.children.every(c => c.type !== undefined && c.width !== undefined);
    if (allAccessible) break;
  }
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

// Idempotency: check if MCP section already exists (from a previous
// partial run or timed-out attempt). Reuse it instead of creating a duplicate.
let mcpSection = container.children.find(
  c => c.type === "SECTION" && c.name === "MCP Dev Ready"
);
if (!mcpSection) {
  mcpSection = figma.createSection();
  mcpSection.name = "MCP Dev Ready";
  container.appendChild(mcpSection);
}

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

## Step 6: Create Section Frames, Export Heavy Assets, Replace with Placeholders

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

    // Sub-section fill: slight gray to create visual separation
    frame.fills = [{ type: "SOLID", color: { r: 0.93, g: 0.93, b: 0.93 } }];
  }

  // Remove the now-empty clone frame
  clone.remove();
}

return { sectionsCreated: confirmedProposals.reduce((acc, p) => acc + p.sections.length, 0) };
```

### 6b: Identify heavy assets

**Important:** The `isHeavyAsset` helper below must be defined in the same `use_figma` call as Step 6c's scan loop — it's referenced there. Include it at the top of that script.

Scan all section frames for heavy assets using these heuristics:

```javascript
function isHeavyAsset(node) {
  // Image fills — check on FRAME, GROUP, RECTANGLE, VECTOR, and INSTANCE types
  // (Plugin API may not expose fills on deeply nested instances; check explicitly)
  if (node.fills && Array.isArray(node.fills)) {
    for (const fill of node.fills) {
      if (fill.type === "IMAGE") return true;
    }
  }

  // Name-based heuristic: nodes with common image/illustration names
  const nameLower = (node.name || "").toLowerCase();
  const imagePatterns = ["image", "photo", "illustration", "img", "icon", "logo", "avatar", "thumbnail"];
  if (imagePatterns.some(p => nameLower.includes(p)) &&
      node.width > 100 && node.height > 100) return true;

  // Export settings heuristic: nodes configured for image export
  if (node.exportSettings && node.exportSettings.length > 0) {
    const hasImageExport = node.exportSettings.some(s =>
      ["PNG", "JPG", "SVG"].includes(s.format)
    );
    if (hasImageExport && node.width > 100) return true;
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

### 6c: Export heavy assets as 2x PNG, replace with descriptive placeholders

Instead of keeping heavy assets in Figma (which defeats MCP optimization), **export them as 2x PNG files** to a local folder. The designer can share this folder with devs directly.

**First, collect all heavy asset node IDs** via `use_figma`:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

await figma.loadFontAsync({ family: "Inter", style: "Regular" });
await figma.loadFontAsync({ family: "Inter", style: "SemiBold" });

const mcpSection = figma.getNodeById("<mcpSectionId>");

// Deduplication: same-named assets across screens only need one export
const extractedAssetNames = new Map(); // name → { nodeId, width, height }
const replacements = []; // { nodeId, origName, origWidth, origHeight, origX, origY, parentId, index }

for (const frame of mcpSection.children) {
  if (frame.type !== "FRAME") continue;

  function findHeavyAssets(parent) {
    const children = [...parent.children];
    for (const child of children) {
      if (isHeavyAsset(child)) {
        const origName = child.name;
        const origParent = child.parent;
        const origIndex = [...origParent.children].indexOf(child);

        if (!extractedAssetNames.has(origName)) {
          // First occurrence — mark for export, add 2x export setting
          child.exportSettings = [{ format: "PNG", suffix: "@2x", constraint: { type: "SCALE", value: 2 } }];
          extractedAssetNames.set(origName, {
            nodeId: child.id, width: child.width, height: child.height
          });
        }

        replacements.push({
          nodeId: child.id, origName, isDuplicate: extractedAssetNames.get(origName).nodeId !== child.id,
          origWidth: child.width, origHeight: child.height,
          origX: child.x, origY: child.y,
          parentId: origParent.id, index: origIndex
        });
      } else if (child.children) {
        findHeavyAssets(child);
      }
    }
  }

  findHeavyAssets(frame);
}

return { replacements, uniqueAssets: [...extractedAssetNames.entries()].map(([name, info]) => ({ name, ...info })) };
```

**Then, export each unique asset** using `get_screenshot` (which exports node content as an image). For each unique asset:

```bash
# Create assets folder next to the working directory
mkdir -p <output-dir>/assets

# Use get_screenshot on each unique asset node ID to export it
# Save as <asset-name>@2x.png
```

> **Note:** If `get_screenshot` is insufficient for export quality, instruct the user: "I've tagged X assets with 2x PNG export settings in Figma. Select them and use File → Export to save to your assets folder."

**Finally, replace originals with descriptive placeholders** via `use_figma`:

```javascript
// Switch page first
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  if (figma.getNodeById("<childId>")) break;
}

await figma.loadFontAsync({ family: "Inter", style: "Regular" });
await figma.loadFontAsync({ family: "Inter", style: "SemiBold" });

const replacedIds = [];

for (const r of replacements) {
  const node = figma.getNodeById(r.nodeId);
  const parent = figma.getNodeById(r.parentId);
  if (!node || !parent) continue;

  // Remove the heavy asset
  node.remove();

  // Create descriptive placeholder
  const placeholder = figma.createFrame();
  placeholder.name = "placeholder: " + r.origName;
  placeholder.resize(r.origWidth, r.origHeight);
  placeholder.fills = [{ type: "SOLID", color: { r: 0.95, g: 0.95, b: 0.97 } }];
  placeholder.strokes = [{ type: "SOLID", color: { r: 0.8, g: 0.8, b: 0.85 } }];
  placeholder.strokeWeight = 1;
  placeholder.strokeDashes = [8, 4];
  placeholder.cornerRadius = 8;
  placeholder.layoutMode = "VERTICAL";
  placeholder.primaryAxisAlignItems = "CENTER";
  placeholder.counterAxisAlignItems = "CENTER";
  placeholder.primaryAxisSizingMode = "FIXED";
  placeholder.counterAxisSizingMode = "FIXED";
  placeholder.itemSpacing = 8;

  // Asset name label (bold)
  const nameLabel = figma.createText();
  nameLabel.fontName = { family: "Inter", style: "SemiBold" };
  nameLabel.fontSize = 14;
  nameLabel.characters = r.origName;
  nameLabel.fills = [{ type: "SOLID", color: { r: 0.3, g: 0.3, b: 0.4 } }];
  placeholder.appendChild(nameLabel);

  // Size info
  const sizeLabel = figma.createText();
  sizeLabel.fontName = { family: "Inter", style: "Regular" };
  sizeLabel.fontSize = 12;
  sizeLabel.characters = Math.round(r.origWidth) + " × " + Math.round(r.origHeight) + (r.isDuplicate ? " (duplicate)" : "");
  sizeLabel.fills = [{ type: "SOLID", color: { r: 0.5, g: 0.5, b: 0.55 } }];
  placeholder.appendChild(sizeLabel);

  // File reference
  const fileLabel = figma.createText();
  fileLabel.fontName = { family: "Inter", style: "Regular" };
  fileLabel.fontSize = 11;
  fileLabel.characters = "→ assets/" + r.origName + "@2x.png";
  fileLabel.fills = [{ type: "SOLID", color: { r: 0.5, g: 0.5, b: 0.55 } }];
  placeholder.appendChild(fileLabel);

  // Insert at original position
  parent.insertChild(Math.min(r.index, parent.children.length), placeholder);
  placeholder.x = r.origX;
  placeholder.y = r.origY;

  replacedIds.push(placeholder.id);
}

return { replaced: replacedIds.length, mutatedNodeIds: replacedIds };
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
- Placeholders are visible with asset name, dimensions, and file reference (dashed border boxes)
- No overlapping or clipped elements
- Placeholder sizes match the original asset dimensions

Fix any issues before presenting.

## Step 8: Present Result

Show the user a before/after screenshot and summarize:

> **Done.** Created MCP-optimized version with X sections. Y assets exported as 2x PNG.
>
> - **Original screens:** untouched
> - **MCP Dev Ready:** lightweight section frames, heavy assets replaced with descriptive placeholders
> - **Assets folder:** `<output-dir>/assets/` — contains Y exported PNGs at 2x resolution
> - **Placeholders:** show asset name, dimensions, and file path reference
>
> Designer can share the assets folder with devs directly.
>
> Want to adjust anything?
