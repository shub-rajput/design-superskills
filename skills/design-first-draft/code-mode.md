# Code mode: first drafts as HTML

Use when the user picks "Code first" in Step 3. Drafts are standalone HTML pages, one per frame, built from the discovered tokens and components (or the draft tokens and kit). They are drafts to compare, not production code in the user's app.

## Inputs

- The token source from Step 2 or Step 4: the codebase's token file, a `tokens.css` written from Figma variables, or `first-drafts/tokens.css` from the style card.
- Component styling: the codebase's component CSS when it is plain CSS; otherwise copy the markup and class names from the components' rendered output, docs or stories; or the draft kit's `kit.css`.
- The brief, the sample record, and the parity checklist if Step 5 ran.

## Steps

1. **Map components.** For each row of the brief's component table, note the source (codebase component, library docs, draft kit). Pieces with no source are hand-written from tokens and listed as gaps.
2. **One folder per direction** under `<project>/first-drafts/<direction-slug>/`, one file per frame (`00-start.html`, `01-filled.html`, ...). Each page links the token file and the component or kit CSS; no inline hex. Same sample content everywhere.
3. **Utility-class systems.** If the codebase uses Tailwind, load the Tailwind CDN build in the drafts with the project's theme values copied into its inline config, so classes resolve to the same tokens. Say so in the summary.
4. **Preview.** Pick a free port (`lsof -iTCP:<port> -sTCP:LISTEN` returns nothing), then `python3 -m http.server <port>` from `first-drafts/` in the background. The first navigation can race the server start; if it is refused, retry once. Screenshot each page at the brief's frame width (390 for phone, 1440 for desktop web) and critique with the same checklist as Figma mode. Stop the server when the run ends.
5. **Capture into Figma (optional).** If the user wants the drafts on the canvas, `generate_figma_design` per page into the direction's section. After capture: swap fonts Figma cannot load to the system or style font, check that colours bound to the expected variables, re-run the Figma QA sweep.

## When to prefer code mode

- The direction's value is interaction (inline expansion, live preview) that static frames undersell.
- The design system lives in code and has little or nothing in Figma.
- The user wants developers to start from markup.

Prefer Figma mode when the user works in Figma daily, when the Figma library has components the code side lacks, or when screens depend on a cloned app shell.
