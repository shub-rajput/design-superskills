# Direction build brief (template)

Copy to `<scratch>/direction-brief.md`, fill every `<placeholder>`, delete the guidance lines in italics. Every builder reads this file first. Mid-course feedback from the user is appended as `## Addendum <letter> (<date>)` so all builders see the same rule set.

---

# <Product>: <flow name>, direction build brief

You are building ONE direction for the "<flow name>" of <product> <in Figma | as HTML pages>, using <the product's design system | the draft tokens and draft kit>. Other builders work on the other directions in their own <sections | folders>. Stay inside yours. Never edit library or kit components, other sections, or anything outside your assignment.

## The objective (what every direction must satisfy)

*Restate the objectives from the synthesis or brief, numbered, primary first, one sentence each plus one sentence on what it means on screen. Two to four objectives.*

1. **<Objective 1>.** <What it means on screen.>
2. **<Objective 2>.** <What it means on screen.>
3. **<Objective 3>.** <What it means on screen.>

Out of scope for every direction: <what the synthesis deferred>. Do not design it. The layout may leave an obvious place for it later, nothing more.

Current problems this replaces (context, do not repeat them): <one line from the findings, or "new flow, nothing replaced">.

Keep in view while designing (shape the layout, do not design them): <the synthesis's "Keep in view" list, one line each, or delete this line>.

## Platform and decisions for this build

- Platform: <phone | desktop web | inside the app shell>, frames <width> wide.
- <Open decision>: <answer, or "each direction answers this its own way, see its bullet">. Assumed, not confirmed, unless marked confirmed.
- <Open decision>: <answer>.

## Feature parity

*Keep this section only if Step 5 ran. Otherwise write "No parity check: this is a new flow" or "Parity check skipped: no access to the current screen".*

Read `parity-checklist.md` in this folder. "Essentials first" does not mean "essentials only". Every feature the current product offers must have a visible, non-blocking home: essentials prominent, everything else in collapsed sections, secondary cards or a "More options" area, never in a step that blocks completion, never dropped. Show paid or add-on items the way the product shows them today (badge or inline upsell), never hidden.

## The directions (build only the one assigned to you)

*Paste the direction cards verbatim, lightly edited. One bullet per direction with its references and, when per-direction styles apply, its visual line. Do not rank them.*

These are the user's own definitions. Directions must look and behave clearly differently from each other. **If your build could be mistaken for another direction, it fails.**

- **v1 <name>** (after <references>). <Summary.>
- **v2 <name>** (after <references>). <Summary.>
- **v3 <name>** (after <references>). <Summary.>

## Sample content (identical across directions so they compare fairly)

*One realistic record for the flow. Every builder uses exactly this.*

- <Field>: "<value>"
- <Field>: "<value>"
- <Field>: "<value>"
- Image: a placeholder rectangle with a gradient fill labelled "<Image>". Do not upload real images.

## Target facts

*Figma mode:*
- File key `<fileKey>`. Page "<page name>" id `<pageId>`. Every `use_figma` call starts with `await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('<pageId>'))`.
- Parent section `<sectionId>`. Your section id is in your task; its fill is `<section fill>`, so text you place on the section uses `<label colour>`. Frames start at x = <n>, y >= <n> inside your section, <gap>px apart.
- Labels above frames: <"none, Figma shows frame names" | "TEXT matching `<labelNodeId>`: <font> <size> <colour>, identical to the frame name">.
- Screen frames <width> wide. Background bound to `<surface token>`.
- Shell frame to clone for in-product screens: `<shellId>` (<what it contains>), or "none, full-page screens".
- Existing screens for visual language (do not copy layout): `<frameIds>`.

*Code mode:*
- Your folder: `first-drafts/<direction-slug>/`. One HTML file per frame (`00-start.html`, `01-filled.html`, ...).
- Every page links `<token file path>` and `<component or kit CSS>`; fonts load from `<source>`.
- Preview at `http://localhost:<port>/<direction-slug>/`; screenshots at <frame width> wide.

## Components

*From the design system, or from the draft kit. For Figma, read `componentPropertyDefinitions` on the SET (never a variant) and record the keys; text and boolean props carry a `#id` suffix.*

Create instances with `(await figma.getNodeByIdAsync('<id>')).createInstance()`; for a component SET use `set.defaultVariant`, then `instance.setProperties({...})`. For library components that are remote, `await figma.importComponentSetByKeyAsync('<key>')`.

| Need | Component | Id or key | Props and notes |
|---|---|---|---|
| Primary button | | | |
| Secondary button | | | |
| Text input | | | |
| Select | | | |
| Checkbox, toggle, radio | | | |
| Card | | | |
| Navigation (tabs, nav items, steps, progress) | | | |
| Badge, notice, modal, toast | | | |
| Shell pieces (top bar, sidebar, footer) | | | |
| Icons | | | |

## Text styles

| Style | Id | Font |
|---|---|---|
| <Display> | `S:<hash>,` | <family style size> |
| <Heading> | | |
| <Body> | | |
| <Label> | | |
| <Button> | | |

Load each font before any text edit. Apply with `await node.setTextStyleIdAsync(styleId)`.

## Tokens

Collection `<name>` (`<id>`), mode `<mode name>` (`<modeId>`; only when the collection has more than one mode: set it on every frame you create with `setExplicitVariableModeForCollection`, or the frame renders in another style's colours), or CSS file `<path>`. Names to use: `<color/*>`, `<space/*>`, `<radius/*>`. Bind colours with `figma.variables.setBoundVariableForPaint(paint, 'color', variable)` and reassign fills. Never type a raw hex for anything that has a token. Gradient stops cannot be bound; note them in the report.

## Build rules

- Load `figma:figma-use` before your first `use_figma` call. Small steps (under 10 operations per call), `return` created node ids, `await` everything, load fonts before text edits, set `layoutSizingHorizontal = 'FILL'` only after `appendChild`.
- Auto-layout everywhere. Instances over redraws. Do not detach instances.
- Copy: sentence case, plain language, no em-dashes.
- Frames: `<Direction> / 00 Start`, `/ 01 Filled`, `/ 02 <mechanism state>`, `/ 03 <finishing state>`. Three minimum, six maximum. Start, filled and finishing states are required; an objective that needs its own state (cancel, waitlist, error) gets its own frame, and a direction may rename a required state its mechanism changes.
- One moment per frame. A frame never shows a call to action next to the result of taking it.
- Screenshot after each frame (`await frame.screenshot()`, or the browser in code mode) and fix clipped text, overlaps and off-token colours before moving on. Leave no `placeholder = true`.
- If a component misbehaves (font errors, missing props), fall back to a token-styled auto-layout frame and say so in the report.

## Report format (final message)

1. Section id and frame ids with names (or file paths).
2. Two sentences per objective on how the direction meets it.
3. Two sentences on what makes it visibly different from the other directions.
4. Components used and any hand-built fallbacks.
5. Known gaps or things you were unsure about.

---

## Addendum pattern

```
## Addendum A (<date>): <topic>

**<Rule name>.** <One paragraph, imperative, with the observable test a builder can apply.>
```

Typical addenda: a parity rule after an inventory finding; a reframe of one direction after the user narrowed its intent; a data-model correction that applies to every direction.
