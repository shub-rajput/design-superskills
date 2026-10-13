# Figma gotchas for direction builds

Read before writing the brief and paste the relevant lines into it.

## Access and session

- **"Cannot write to node property in a read-only file or mode"** on every write while reads still work: the Figma MCP session lost authorization. Ask the user to run `/mcp` and re-authenticate, then retry. Do not start by diagnosing seats or plans. Builders mid-build stop retrying and write a pending list (frame id, node ids, exact change) to scratch; apply it after re-auth.
- **429 "session limit"** stops background agents. Resume each with "continue where you stopped, do not redo completed work". Their context survives.
- Agents launched with no `model` override inherit the parent's model. Set it explicitly.

## Reading

- `get_metadata` on a large section exceeds the output limit and is saved to a file. Read it in chunks, or use `use_figma` with `findAllWithCriteria` returning only ids, names, types and bounds.
- Only the first **5 inline images** come back from one `use_figma` call. Batch `await node.screenshot()` five per call, fan calls out in parallel, map images by the returned id order.
- A screenshot of a whole section taken right after an edit can come back stale. Screenshot the edited frames by id to confirm a change.
- `getNodeByIdAsync` reaches nodes on other pages, but call `setCurrentPageAsync` once per call before mutating.

## Components and props

- Read `componentPropertyDefinitions` on the SET, never on a variant, or it throws.
- Text and boolean props carry a `#id` suffix (`Label#123:4`). Variant props do not.
- Check whether `Label` or `Description` props are text or **visibility booleans** before writing copy. When a label has no text prop, the edit is a child override: keep it and list the component as a design-system gap. Do not wrap instances in frames with sibling label text; it breaks composition.
- Binding a TEXT prop on a master overwrites that node's characters with the prop default. Never bind icon glyph nodes that share a layer name with a message.
- `swapComponent` keeps stale text overrides; call `resetOverrides()` after swapping.
- `component.clone()` returns a COMPONENT; `createComponentFromNode` on it throws.
- A component named like a common control may not be one (a "tabs" set that is a vertical side nav, for example). Screenshot before using.

## Text and fonts

- Icon-font glyphs typed as literal private-use characters get stripped in transit. Write them with `String.fromCharCode(0xf0c7)` style calls, after loading the icon font.
- Before editing text that mixes fonts (cloned shells, menu items), load every segment's font: `for (const seg of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(seg.fontName)`.
- Labels above frames follow the file's label convention (read an existing label's `fontName`, `fontSize`, `fills`). Inside frames, only the design system's or style card's fonts.
- Component styles may transform text (uppercase toggles, for example). That is not a bug.

## Layout

- Sections do not auto-resize. Resize with `resizeWithoutConstraints` after adding frames; tighten to content plus 100px at the end.
- A cloned shell's content area may not be auto-layout. After adding content, move following blocks and the footer numerically and re-screenshot.
- A cloned shell may carry the wrong product's chrome (menu labels, footer variant). Check variants and override texts.
- A node moved from a horizontal row into a vertical stack can inherit `layoutGrow = 1` and render 1px tall. Reset it.
- New auto-layout frames default to a white fill. Clear `fills` when they sit inside a tinted area.
- `layoutSizingHorizontal = 'FILL'` only after `appendChild`; `HUG` only on auto-layout frames or TEXT children.
- A paint-level `opacity` can be lost when the paint is bound to a colour variable. For scrims and overlays, bind the colour and set `opacity` on the node.
- Gradient stops cannot be bound to variables. Use them only for image stand-ins and say so.
- Variable modes: set a section's or frame's explicit mode with `node.setExplicitVariableModeForCollection(collection, modeId)`; children inherit it.

## Naming and placement

- The user's own numbered labels on the canvas may disagree with the synthesis numbering. Name direction sections by content and number ("Direction v2 · Side rail checklist").
- Frame names `<Direction> / 0N <State>`; label text identical to the frame name.
- One sub-section per direction inside the target section; builders never write outside theirs. The draft kit and style options sit outside every direction's section.
