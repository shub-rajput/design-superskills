# Design-system discovery

Read in Step 2 of `design-first-draft`. Look before asking. Everything here is read-only. The goal is one short findings table the user can confirm in Step 3.

## Where to look

### 1. The target Figma file

Two steps, because a script may switch pages only once (figma-use page rule).

**Call 1, file level (one call, no page switching):**

```javascript
// Read-only. Variables and text styles are file-level; pages are listed, not loaded.
const collections = (await figma.variables.getLocalVariableCollectionsAsync())
  .map(c => ({ id: c.id, name: c.name, modes: c.modes.map(m => m.name), count: c.variableIds.length }));
const textStyles = (await figma.getLocalTextStylesAsync())
  .map(s => ({ id: s.id, name: s.name, font: s.fontName.family + ' ' + s.fontName.style, size: s.fontSize }));
return { pages: figma.root.children.map(p => ({ id: p.id, name: p.name })),
         collections, textStyles: textStyles.slice(0, 40), textStyleCount: textStyles.length };
```

**Call 2, components (one call per page, all emitted in one message so they run in parallel):** pick the pages likely to hold components (names like "Components", "Library", "Design system", "Foundations"); when no name fits, fan out over every page.

```javascript
// Read-only. One page per call.
const page = await figma.getNodeByIdAsync('<pageId>');
await figma.setCurrentPageAsync(page);
const out = [];
for (const n of page.findAllWithCriteria({ types: ['COMPONENT_SET', 'COMPONENT'] })) {
  if (n.type === 'COMPONENT' && n.parent && n.parent.type === 'COMPONENT_SET') continue;   // variants count under their set
  out.push({ id: n.id, name: n.name, type: n.type });
}
return { page: page.name, count: out.length, items: out.slice(0, 60) };
```

If either call fails with "Looks like you don't have edit access to this file", stop the Figma probe, continue with the codebase, and mark Figma as unreachable in the findings table (SKILL.md Step 0 has the fix).

Check that what you found belongs to the product in the input. A scratch or playground file often carries another product's tokens, styles or team libraries; report them as **Unrelated** with what they are, and do not offer them as the product's system unless the user says to use them.

Also note:
- **Existing product screens**: frames on pages named like "Designs", "Production", "Current", or near the target section. They show the visual language (do not copy their layout).
- **Shell frames**: app chrome (top bar, sidebar, footer) worth cloning for screens that live inside a product.
- **Label convention**: the font, size and colour of labels above existing frames.

### 2. Enabled libraries

`mcp__figma__get_libraries` for the file, then `mcp__figma__search_design_system` with a few generic queries ("button", "input", "card", "navigation"). A library with matching components counts as a design system even when the file has no local components. Remote components are imported with `importComponentByKeyAsync` / `importComponentSetByKeyAsync`.

### 3. The codebase

The product's code only: the working directory when it is the product (its `package.json` name, README or routes match the product in the input), or a repo path the user named. When the working directory is unrelated (a plugin repo, a notes folder), skip this probe and say so; do not report its tokens as the product's. Look, do not run builds.

| Signal | Where |
|---|---|
| Token files | `**/tokens*.{css,json,ts}`, `**/variables.css`, `**/theme.{ts,js}`, CSS files with many `--` custom properties on `:root` |
| Utility config | `tailwind.config.*`, `@theme` blocks in CSS (Tailwind v4), `uno.config.*` |
| Component folders | `components/ui/`, `src/components/`, `packages/*/src/components/` |
| Docs | `.storybook/`, `*.stories.*`, a design-system `README.md` |
| UI libraries | `package.json` dependencies: shadcn (`components.json`), MUI, Chakra, Mantine, Ant Design, Radix, Headless UI, Bootstrap |
| Fonts | `@font-face`, Google Fonts links, `next/font` imports |
| Code Connect | `*.figma.ts`, `*.figma.tsx`; `mcp__figma__get_code_connect_map` links Figma components to code |

### 4. Brand assets

A logo file, brand colours or fonts named in the input, the brief, or a brand page the user linked. Not a design system, but they seed the style cards in Step 4: the primary colour and the display font start from the brand when one exists.

## Findings table

Report in one block, then ask in Step 3:

| Source | Found | Usable as |
|---|---|---|
| Figma file `<name>` | 38 component sets, 1 colour collection (Light, Dark; 64 vars), 12 text styles (`<font>`) | Full system |
| Library `<name>` | button, input, select, card, tabs | Components only |
| Codebase `<path>` | `tokens.css` (90 custom properties), shadcn in `components/ui` (24 components) | Tokens and components |
| Brand | Logo (SVG), primary `<hex>`, font `<name>` | Brand only |

"Usable as" is one of: **Full system** (components plus tokens plus text styles), **Tokens only**, **Components only**, **Fragments** (a few one-off components or a handful of colours), **Brand only** (logo, colours, fonts), **Unrelated** (belongs to another product, say which), **Nothing found**, **Skipped** (with the reason: no Figma file given, Figma unreachable, working directory is not the product).

## Decision

| Finding | Step 3 asks | Step 4 |
|---|---|---|
| Full system, or tokens plus components | "Build with it?" | Skipped |
| Tokens only | "Build with these tokens? Components are drawn from them." | Skipped |
| Components only, or fragments | "Use these and fill the gaps with a matching style?" | Runs, seeded from what was found |
| Figma and code disagree (different fonts or palettes) | Name both, ask which is the source of truth | Skipped |
| Brand only | "No design system, but I found your brand (logo, `<colour>`, `<font>`). Is there a specific style you want me to try?" | Runs; every style card starts from the brand |
| Nothing found, or only Unrelated systems | "Is there a specific style you want me to try?" (name the unrelated system as an option only if the user might want it) | Runs, unless the user picks neutral wireframe grade |

## For code mode

When the build is in code and the system lives in code, record for the brief: the token file paths, how components are imported (or that they are copied as markup), and the font loading. When the system lives only in Figma, read its variables with `get_variable_defs` and write them to `first-drafts/tokens.css` so code drafts use the same values.
