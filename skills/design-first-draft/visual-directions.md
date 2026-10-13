# Visual directions and draft tokens

Read in Step 4 of `design-first-draft`, only when no design system will be used (none found, or the user declined it) and the user did not choose neutral wireframe grade.

## Sources, one outcome

| Source | What to do |
|---|---|
| The synthesis or brief has a **Visual direction** line per direction, and the user accepted them in Step 3 | One style card per direction from its line. Directions differ visually only in this case. |
| The synthesis or brief has one shared **Visual direction** line under Scope, and the user accepted it | One style card from that line, shown and confirmed. Every direction uses it. |
| The user chose **match a reference** | Screenshot the reference, extract one style card from it (palette roles, type, density, radius, shadow), show it, confirm. |
| The user chose **propose styles** | Two or three shared style cards, the user picks one. Every direction uses it. |

All of them end in draft tokens that builders bind to.

## Style card

Each card has exactly these fields:

| Field | Content |
|---|---|
| Name | Two or three words ("Quiet utility", "Warm editorial", "Bold product") |
| Feel | One line on the impression it gives and who it suits |
| Palette | Roles, not swatches: background, surface, text, muted text, border, primary, text on primary, primary soft, accent, success, success soft, danger, danger soft. Hex per role, light mode (add dark only if the user asks). The card shows five chips (bg, text, primary, accent, danger); the full set goes into the tokens |
| Type | Display and body families (Google Fonts or system), base size, scale ratio |
| Density | Base spacing unit and the scale (4, 8, 12, 16, 24, 32, 48) |
| Shape | Radius for small, medium, large; border weight; shadow or none |
| Reference | One or two products or sites that carry this feel |

Proposed styles must differ on at least three of palette, type, density and shape. Ground them in the problem and audience from the input (a dense admin tool and a consumer sign-up flow want different defaults), and start from the brand when Step 2 found one. When a card uses a common generated-looking default (cream background with a serif display, a purple gradient, Inter as the only face), its Feel line names the audience reason. Cards speak to the user about the style; they never comment on the rules for choosing it.

## Showing the cards

**Figma mode:** one `use_figma` call places a "Style options" frame next to the parent section (created at the end of Step 3), outside it: per card, a title, the feel line, palette chips with role names, a type specimen (display and body), and a mini component row (primary button, input, card) in that style. Screenshot it and show the user. Delete it after the pick, or keep it if the user wants the record.

**Code mode:** one `first-drafts/style-options.html` with the same content per card (cards side by side, wrapping on narrow screens), screenshotted at 1440 wide so the cards sit next to each other.

Ask one question: which card, or what to change. Apply edits to the card, not to a new set.

## Draft tokens

**Figma:** a local variable collection named "Draft tokens · <Style name>", one per style. A new collection, rather than a new mode on an earlier one, means nodes resolve to the right style without an explicit mode.

| Group | Variables |
|---|---|
| `color/` | `bg`, `surface`, `text`, `text-muted`, `border`, `primary`, `on-primary`, `primary-soft`, `accent`, `success`, `success-soft`, `danger`, `danger-soft` |
| `space/` | `1` to `8` from the density scale |
| `radius/` | `sm`, `md`, `lg` |

Plus local text styles named `Draft/<Style name>/<Role>` so they never clash with the file's own styles or an earlier run's (text styles have no modes): roles `Display`, `Heading`, `Body`, `Body small`, `Label`, `Button`. Check exact style names with `figma.listAvailableFontsAsync()` first (many Google families use "SemiBold", Inter uses "Semi Bold"), then load each font before creating its style. If a collection for the same style already exists from an earlier run, reuse it.

The collection and styles are file-level additions. In a file that holds real product work, say so in Step 3 and get the user's okay; in a scratch or playground file, go ahead. Per-direction styles (first row of the table above) are the one case for modes: one collection, one mode per direction, named after the direction. Set the explicit mode on each direction's section, the kit section and the kit components, and tell builders in the brief to set it on every frame they create; a wrong mode shows as a frame rendering in another direction's colours.

**Code:** `first-drafts/tokens.css` with the same names as custom properties on `:root` (`--color-bg`, `--space-4`, `--radius-md`, `--font-display`), the Google Fonts link noted at the top for pages to include.

Record the collection id, variable names and text-style ids (or the CSS path) in the brief's token table.

## Draft kit

Before Step 6, build one small shared kit so every direction uses the same pieces: primary and secondary button, text input, select, checkbox, toggle, card, nav item, badge, notice. Each is an auto-layout component bound to the draft tokens, with text properties for its labels. Input and select get a `State` variant (Empty with muted placeholder text, Filled with text colour), because every direction draws both a start and a filled frame. The nav item doubles as a chip, so its Default state has a border; an unselected chip with no fill and no border reads as plain text.

Three recipe rules that prevent known defects:
- `addComponentProperty` on a component set rewrites every variant's bound text to the property default. Set each variant's text afterwards with a per-variant override, or accept one shared default and say so on the kit page; otherwise the kit page shows every badge with the same wording.
- Notices and other message containers hug their height, with the text set to `textAutoResize = 'HEIGHT'` and filling the width. A fixed height clips two-line messages.
- Variants that differ only in emphasis share one box model. A Selected state with a fill gets a stroke in its own fill colour, so it measures the same as the bordered Default.

**Figma:** a "Draft kit" frame next to the parent section (outside every direction's section). Record each component id and its `componentPropertyDefinitions` keys in the brief's component table, the same way a real library is recorded.

**Code:** `first-drafts/kit.css` with one class per piece built on the custom properties, plus `first-drafts/kit.html` showing each one.

## Rules for builders

- Bind every colour, spacing and radius to a draft token. Raw hex only for image stand-ins (gradients cannot be bound) and say so in the report.
- Use draft-kit instances wherever a piece exists. A piece the kit lacks is built inside the builder's own section from tokens and listed in the report; never edit the kit.
- The summary labels the tokens and kit as **draft, not a design system**.
