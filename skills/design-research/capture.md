# Capture and Placement Recipe

Supporting file for `design-research`. Read `shared/common-steps.md` for the capture strategy (viewport, lazy images, chunking) and shell rules; this file adds login, app-specific capture notes, and the Figma placement recipe.

## Login

Generic form login. Never guess selectors; discover them.

```bash
agent-browser --session <session> open "<login-url>"
agent-browser --session <session> snapshot -i
agent-browser --session <session> fill "[ref=<user-ref>]" "<username>"
agent-browser --session <session> fill "[ref=<pass-ref>]" "<password>"
agent-browser --session <session> click "[ref=<submit-ref>]"
agent-browser --session <session> open "<landing-url>"
```

Verify the landing page loaded (title or a known element in `snapshot -i`). If the page shows SSO, 2FA, a captcha, or a magic-link prompt, stop and ask the user to complete it in the agent-browser window, then continue. Do not attempt to bypass.

## Capture notes for apps

- **React or Vue admin apps.** `click` and `fill` by ref often hang. Use `eval` with `document.querySelector(...).click()`; set input values through the native setter and dispatch `input` and `change` events. Wait with `(async () => { await new Promise(r => setTimeout(r, 1500)); })()`. `agent-browser eval` has no top-level `await`.
- **Editors rendered in an iframe.** Content lives in `iframe[name="editor-canvas"]` or similar; query `contentDocument`.
- **Local apps with notices or overlays from other tools.** Dismiss them before capturing, or ask the user to turn the other tools off for the run and back on after. This skill does not change the target's configuration itself.
- **First-run gates and wizards.** Try direct URL navigation to a known page, then a JS click on hidden skip or dismiss elements. If neither works, capture the gate: a screen that blocks access is a finding.
- **Public sites.** Run the popup and consent auto-dismiss from `shared/common-steps.md` before the first capture; set the consent cookie if a banner returns on every page. Anti-bot walls: note them, capture what is reachable, move on.

## Capture

```bash
mkdir -p screenshots/<source-slug>
agent-browser set viewport 1280 1440 --session <session>
```

Per screen: scroll top to bottom for lazy content, wait for images, measure height, then either one `--full` screenshot or chunked viewport screenshots (`-p1`, `-p2`, step 1440, no overlap). Absolute paths for the output. Read each PNG after capture; if Read fails on dimensions, chunk.

Naming: `NN-description.png` in flow order (`01-bookings-list`, `02-new-booking`). Tabs, modals and dropdowns worth showing are separate screenshots.

Journey notes: one to three factual sentences per screen (clicks to reach it, interruptions dismissed, missing feedback, confusing labels). Keep them in `screenshots/<source-slug>/journey.md`.

## Layout rule: match first, defaults second

If the parent section already holds a row, read it and copy its numbers. Which row: the one the user linked, otherwise the bottom-most.

```javascript
const sec = await figma.getNodeByIdAsync('<subSectionId>');
const tiles = sec.children.filter(c => c.type === 'RECTANGLE').sort((a,b) => a.x - b.x);
const tile = tiles[0];
return { tile: { w: tile.width, h: tile.height, y: tile.y }, padX: tile.x,
  gap: tiles[1] ? tiles[1].x - tile.x - tile.width : null,
  fill: sec.fills, height: sec.height,
  labels: sec.children.filter(c => c.type === 'TEXT').map(t => ({ y: t.y, size: t.fontSize, font: t.fontName })) };
```

Child `x`/`y` are relative to the parent section; `get_metadata` reports absolute canvas coordinates. Do not mix them.

| Setting | Compact default (1280x1440 captures) |
|---|---|
| Tile size | 450 x 506 (width 450, height keeps capture ratio) |
| Tile gap | 80 |
| Sub-section padding (x) | 24 |
| Label | Inter Regular 20, white, about 38px above tile top |
| Tile y inside sub-section | 78 |
| Sub-section height | 762 |
| Row spacing | 60 |
| Sub-section fill | parent fill x 0.6 (`#444444` to `#292929`) |

## Structure

```
Refs (SECTION, parent, created once and reused)
├── <Source A> (SECTION, one per source)
│   ├── "01  bookings list" (TEXT, above tile)   ← label from filename
│   ├── 01-bookings-list (RECTANGLE, IMAGE fill)  ← tile
│   └── …
├── <Source B> (SECTION)
└── …
```

Tiles are rectangles with an IMAGE fill (scale mode FILL), named after the PNG. Chunked captures are separate tiles side by side.

## Place rows in Figma (per source)

1. **One `use_figma` call** creates the sub-section, placeholder tiles and labels. Label text = filename with the number kept: `01-bookings-list` becomes `01  bookings list`. Return rectangle IDs in filename order.
2. **`upload_assets`** with `count` = tile count and `nodeIds` = those IDs in the same order. Max 60 per call. URLs are single-use and expire in 10 minutes.
3. **POST each PNG** as multipart (`-F "file=@01-bookings-list.png;type=image/png"`) to its `submitUrl`. Expect HTTP 200 each.
4. **Grow the parent section**; sections do not auto-resize.
5. **Verify**: count rectangles whose `fills[0].type === 'IMAGE'` (must equal tile count), then `get_screenshot` the parent.

```javascript
const page = await figma.getNodeByIdAsync('<pageId>');
await figma.setCurrentPageAsync(page);
const refs = await figma.getNodeByIdAsync('<parentSectionId>');
await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
const names = ['01-bookings-list', '02-new-booking', '03-edit-booking'];   // PNG basenames, flow order
const T_W = 450, T_H = 506, GAP = 80, PAD_X = 24, TILE_Y = 78, LABEL_Y = 40, ROW_H = 762, ROW_GAP = 60;
const rowIndex = refs.children.filter(c => c.type === 'SECTION').length;   // append below existing rows
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

Then `upload_assets({ count: rectIds.length, nodeIds: rectIds })` and POST the files. One source per call keeps scripts small and a failed upload easy to redo.
