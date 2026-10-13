# Critique checklist

The orchestrator critiques. Builders never grade themselves as done; they report, the orchestrator screenshots and judges. Inline builds use the same checklist on your own frames.

## Criteria (every round)

| Criterion | Question | Fail signs |
|---|---|---|
| Objective fit | Does every frame serve the stated objectives? Is the primary objective visibly the point of the screen? | Essentials split across clicks; the finishing step missing or implied only by copy; an objective mentioned in copy but not in layout; copy that promises more than the flow does ("one tap" in front of a confirm screen) |
| Direction fidelity and distinctness | Would the user recognise the direction they described? Could it be mistaken for another direction? | Two directions share a navigation model; a "steps" direction with no visible progress; a "keep the current screen" direction that replaced it |
| Design-system or visual-direction adherence | Instances where a component exists, tokens and text styles applied, chrome belongs to this product, same visual language as existing screens (or the chosen style card) | Raw hex where a token exists; a font outside the system or style; another product's chrome in a cloned shell; detached instances; a draft style drifting from its card; hand-built text standing in for a property the component lacks (list it as a gap instead) |
| Parity (only when Step 5 ran) | Every checklist item has a visible, non-blocking home with the right gating badge | A multi-select shown as a single dropdown; coexisting features shown as exclusive modes (or the reverse); paid shown as free (or the reverse); anything from the inventory absent |
| Craft | Is it finished enough to compare? | Clipped text, overlaps, leftover placeholders, empty white containers, duplicate action bars, em-dashes, states described but not drawn (a popover "implied by copy" is not drawn); sample data that contradicts the screen's own state (results that do not match the selected filters, counts without a scope); invented facts outside the sample record |

## Round shape

One consolidated message per direction per round, numbered, each item observable and testable:

```
Critique of <direction> (reviewed frames <list>). <One sentence of what works.> Fix these, then report again in under <n> words:
1. <Frame>: <what is wrong> -> <exact change, with component or token names>.
2. ...
Keep everything else. Do not touch other sections.
```

- Screenshot every frame yourself before writing, and again after each revision. Never critique or accept from the report alone; a revision that reports three fixes after two tool calls still gets checked.
- Group by frame; lead with the item that most affects the objective.
- Give the fix, not just the finding, so the round closes in one pass.
- Resume the same agent (it knows its node ids). If the user asks for a cheaper model, brief a fresh agent with the section and frame ids and the brief path.
- User feedback that applies to more than one direction becomes an Addendum in the brief first, then a message to each affected builder.

## Acceptance

A direction is accepted when all applicable criteria pass on every frame, its QA sweep is clean, and its section is tightened to content plus padding. Record the accepted frame ids.

## Not the orchestrator's call

Do not rank directions or recommend one. Report facts per criterion. If asked what you think, answer in chat, not in the deliverable.

## QA sweep, Figma (once per section at the end)

Read-only. Checks only what the builder made: labels above frames and everything inside library instances are excluded, because instance internals belong to the library.

```javascript
const page = await figma.getNodeByIdAsync('<pageId>'); await figma.setCurrentPageAsync(page);
const s = await figma.getNodeByIdAsync('<sectionId>');
const allowedFonts = [<'Body family'>, <'Icon font family'>];   // the system's or style card's fonts, plus its icon font
const isLabel = n => n.type === 'TEXT' && n.parent === s;
const insideInstance = n => { for (let p = n.parent; p && p !== s; p = p.parent) if (p.type === 'INSTANCE') return true; return false; };
const own = s.findAll(n => !isLabel(n) && !insideInstance(n));
const texts = own.filter(n => n.type === 'TEXT');
const frames = s.children.filter(c => c.type === 'FRAME').sort((a,b)=>a.x-b.x).map(f => ({ name: f.name, w: Math.round(f.width), h: Math.round(f.height) }));
const offFont = [...new Set(texts.filter(t => t.fontName !== figma.mixed && !allowedFonts.includes(t.fontName.family)).map(t => t.fontName.family))];
const emdash = texts.filter(t => /\u2014/.test(t.characters)).length;
const forbidden = texts.filter(t => /<words the addenda banned>/i.test(t.characters)).map(t => t.characters.slice(0, 60));
const shimmer = s.findAll(n => n.placeholder === true).length;
let rawFills = 0, defaultWhite = 0;   // unbound solid fills on builder-made nodes; white is the createAutoLayout default
for (const n of own) {
  if (n.type === 'INSTANCE' || n.type === 'SECTION' || !('fills' in n) || !Array.isArray(n.fills) || (n.boundVariables && n.boundVariables.fills)) continue;
  for (const p of n.fills) {
    if (p.type !== 'SOLID' || p.visible === false || (p.boundVariables && p.boundVariables.color)) continue;
    (p.color.r === 1 && p.color.g === 1 && p.color.b === 1) ? defaultWhite++ : rawFills++;
  }
}
const noStyle = texts.filter(t => !t.textStyleId || t.textStyleId === figma.mixed).map(t => t.characters.slice(0, 30));   // a size or font override detaches the style
const remote = new Set();
for (const i of s.findAllWithCriteria({ types: ['INSTANCE'] })) { const mc = await i.getMainComponentAsync(); if (mc && mc.remote) remote.add(mc.name); }
return { section: s.name, size: [Math.round(s.width), Math.round(s.height)], frames, offFont, emdash, forbidden, shimmer, rawFills, defaultWhite, noStyle: noStyle.slice(0, 10), noStyleCount: noStyle.length, remote: [...remote] };
```

Expected: `offFont` empty, `emdash` 0, `forbidden` empty, `shimmer` 0, `rawFills` 0 (image stand-ins excepted, and named in the report), `noStyleCount` 0 (every builder-made text uses a text style, no size overrides), `remote` only the library the user confirmed. `defaultWhite` is informational: wrapper frames left with the default white fill; clear them (`fills = []`) or bind them to the surface token when they sit on a tinted background. Then tighten each section to its frames' bounds plus 100px (`resizeWithoutConstraints`) and take one overview screenshot of the target section.

## QA sweep, code (once per folder)

- `grep -rn "#[0-9a-fA-F]\{3,8\}\b" first-drafts/<direction-slug>/` returns only token files or image stand-ins.
- `grep -rln "—" first-drafts/<direction-slug>/` (an em-dash) returns nothing.
- Every page links the token file; fonts come only from the system or style card.
- Every frame screenshotted at the brief's frame width with no console errors.

## Final summary shape

1. Table: direction, section id or folder, frames (names and ids or paths), one line on its identity.
2. What it was built with: design system name, or "draft tokens and draft kit, style `<name>`".
3. Parity items applied everywhere, or "parity check skipped" with the reason.
4. QA results per direction (the sweep numbers).
5. Design-system gaps: component, id, what is missing (a text property, a variant, a whole component), and pieces builders had to hand-build.
6. Open questions the user raised or the build surfaced.
