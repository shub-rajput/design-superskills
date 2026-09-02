# Visual Refs Mode — screenshots straight into Figma

Use this when the user wants **visual references only**: no annotations, no review, no HTML gallery. Screenshots go directly onto the canvas as one labelled row per source (plugin or site), inside a parent "Refs" section.

This replaces Steps 7a, 7b, 7c, 8 and 9 of `wp-plugin-research` / `website-research`. Everything before (capture) and after (cleanup) is unchanged.

**REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call. Layout conventions follow `design-organize` (parent section, darker sub-sections, labels above screens); this file only adds what research captures need.

## Structure

```
Refs (SECTION, parent — created once, reused on later runs)
├── Eventin (SECTION, one per source)
│   ├── "01  events list" (TEXT, above tile)   ← label from filename
│   ├── 01-events-list (RECTANGLE, IMAGE fill)  ← tile
│   └── …
├── Amelia (SECTION)
└── …
```

Tiles are plain rectangles with an IMAGE fill (scale mode FILL), named after the PNG. Chunked captures (`-p1`, `-p2`) are separate tiles side by side.

## Layout rule: match first, defaults second

If the parent section already holds a row (the user often arranges the first source by hand), **read that row and copy its numbers** — tile size, gap, padding, label font/size/colour, sub-section fill. Only fall back to the defaults when the parent is empty.

Which row to copy: the one the user linked (a `node-id=A-B` in a Figma URL is node `A:B`), otherwise the bottom-most row in the parent. Always name the page and row you matched in the final message.

No approval gate before writing: this mode is for unattended runs. Instead, finish with the parent-section `get_screenshot` in the final message so the user can check placement and undo if needed.

| Setting | Compact default (1280×1440 captures) |
|---|---|
| Tile size | 450 × 506 (width 450, height keeps the capture ratio) |
| Tile gap | 80 |
| Sub-section padding (x) | 24 |
| Label | Inter Regular 20, white, baseline ~38px above tile top |
| Tile y inside sub-section | 78 (leaves room for label) |
| Sub-section height | 762 |
| Row spacing (sub-section to sub-section) | 60 |
| Sub-section fill | parent fill × 0.6 (e.g. parent `#444444` → `#292929`) |

Read an existing row with:

```javascript
const sec = await figma.getNodeByIdAsync('<subSectionId>');
const tile = sec.children.find(c => c.type === 'RECTANGLE');
const tiles = sec.children.filter(c => c.type === 'RECTANGLE').sort((a,b) => a.x - b.x);
return { tile: { w: tile.width, h: tile.height, y: tile.y }, padX: tiles[0].x,
  gap: tiles[1] ? tiles[1].x - tiles[0].x - tile.width : null,
  fill: sec.fills, height: sec.height,
  labels: sec.children.filter(c => c.type === 'TEXT').map(t => ({ y: t.y, size: t.fontSize, font: t.fontName })) };
```

Child `x`/`y` are relative to the parent section; `get_metadata` reports absolute canvas coordinates. Don't mix them.

## Build order (per source)

1. **Create the sub-section, tiles and labels in one `use_figma` call.** Placeholder fill on tiles (light grey), label text = filename with the number kept: `01-events-list` → `01  events list`. Return the rectangle IDs in filename order.
2. **Request upload slots:** `upload_assets` with `count` = number of tiles and `nodeIds` = the rectangle IDs **in the same order**. Max 60 per call. URLs are single-use and expire in 10 minutes, so upload immediately.
3. **POST each PNG** as multipart (`-F "file=@01-events-list.png;type=image/png"`) to its `submitUrl`. Multipart keeps the filename as the layer name. Expect HTTP 200 per file.
4. **Grow the parent section** to fit the new row (sections do not auto-resize).
5. **Verify:** one `use_figma` read that counts rectangles with `fills[0].type === 'IMAGE'` per sub-section (must equal the tile count), then `get_screenshot` of the parent. Fix before moving to the next source.

One source per call keeps each script small and makes a failed upload easy to redo.

## Example — create one row

```javascript
const page = await figma.getNodeByIdAsync('<pageId>');
await figma.setCurrentPageAsync(page);
const refs = await figma.getNodeByIdAsync('<parentSectionId>');
await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
const names = ['01-events-list', '02-add-new-event', '03-tab-location'];   // PNG basenames, in flow order
const T_W = 450, T_H = 506, GAP = 80, PAD_X = 24, TILE_Y = 78, LABEL_Y = 40, ROW_H = 762, ROW_GAP = 60;
const rowIndex = refs.children.filter(c => c.type === 'SECTION').length;       // append below existing rows
const sec = figma.createSection(); sec.name = '<Source name>'; refs.appendChild(sec);
sec.x = 77; sec.y = 78 + rowIndex * (ROW_H + ROW_GAP);
sec.resizeWithoutConstraints(PAD_X*2 + names.length*T_W + (names.length-1)*GAP, ROW_H);
sec.fills = [{ type: 'SOLID', color: { r: 0.16, g: 0.16, b: 0.16 } }];
const rectIds = [];
names.forEach((n, i) => {
  const x = PAD_X + i * (T_W + GAP);
  const r = figma.createRectangle(); r.name = n; r.resize(T_W, T_H);
  r.fills = [{ type: 'SOLID', color: { r: 0.85, g: 0.85, b: 0.85 } }];
  sec.appendChild(r); r.x = x; r.y = TILE_Y; rectIds.push(r.id);
  const t = figma.createText(); t.characters = n.replace(/^(\d+)-/, '$1  ').replace(/-/g, ' ');
  t.fontSize = 20; t.fontName = { family: 'Inter', style: 'Regular' };
  t.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  sec.appendChild(t); t.x = x; t.y = LABEL_Y;
});
refs.resizeWithoutConstraints(refs.width, Math.max(refs.height, sec.y + ROW_H + 80));
return { sectionId: sec.id, rectIds };
```

Then `upload_assets({ count: rectIds.length, nodeIds: rectIds })` and POST the files.

## Common mistakes

| Mistake | Fix |
|---|---|
| Building an HTML gallery "for the import" | Not needed. `upload_assets` places PNGs directly; `generate_figma_design` is for capturing live web pages, not for screenshots you already have. |
| Applying the defaults when the user already arranged a row | Read the existing row first; the user's arrangement wins. |
| Uploading with `nodeIds` in a different order than the files | Both arrays must be in the same filename order, or images land on the wrong tiles. |
| Letting upload URLs expire | Request slots only when the files are ready; POST within 10 minutes. |
| Trusting HTTP 200 alone | Re-read the tiles and confirm every fill is `IMAGE`. |
| Labels sized for full-scale screens (70pt) | Tiles are compact (450 wide); 20pt reads correctly. Match the existing row if there is one. |
