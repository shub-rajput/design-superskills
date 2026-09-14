# Synthesis Output Contract

Read before drafting in Step 6 of `research-synthesis`. The document is an audit written for the user's audience (managers, PMs, other designers). It presents what was observed and what is being considered. It does not decide.

## Voice

| Rule | Example |
|---|---|
| Third person, audit register | "Publishing creates the page automatically. No share prompt follows." |
| No second person | Not "your note says". Write "the note on 02 add new event states". |
| No Claude opinions or recommendations | No "take v4 forward", no "best fit", no "we suggest". |
| Findings are observations | "Image sits low on the page", not "image is buried". |
| Neutral about the current product | State what is present and what is not. Avoid "broken", "mess", "scavenger hunt". Quote the user's harsher words only inside the verbatim inventory. |
| Short | Problem in three to four sentences. Findings one line each. Objective cards two sentences. |
| No reasoning paragraphs | Do not explain why a section exists or how the list was derived. |
| No em-dashes | Commas, full stops, colons. |
| Placeholders when generalising | `<product>`, `<competitor>`, `<screen>`. Never copy names from one project into another. |

## Data structure

One source of truth, kept in the generator script or a JSON file next to it. Suggested shape:

```
notes:       [{ id, source, colour, screen, text }]          verbatim text
problem:     [{ text, refs[] }]
objectives:  [{ title, body, refs[] }]                        user's priority first
keepInView:  [{ title, body, refs[] }]                        optional, "accommodate, build later"
patterns:    [{ pattern, who, productToday, status, refs[] }]
findings:    [{ text, refs[] }]
scopeNow:    [{ text, refs[] }]
avoid:       [{ text, refs[] }]
directions:  [{ tag, name, after, summary, openQuestions[], wireframe? }]
questions:   [{ question, note, refs[] }]
features:    [{ group, items: [{ text, refs[] }] }]
gaps:        [{ title, body }]
```

`refs` are note ids. Render each as a chip linking to `https://www.figma.com/design/<fileKey>/<fileName>?node-id=<id with : replaced by ->`.

## Statuses (shared patterns table)

| Status | Use when |
|---|---|
| `Not present` | The product has no form of the pattern. |
| `Present, weaker` | The product has it in a weaker or less visible form. |
| `Present` | The product has it at parity or better. |
| `Open question` | Whether to adopt it is undecided (for example, a full-page takeover). |
| `Deferred` | Out of scope for the current work by the user's decision. |

Never `Gap`, `Missing`, `Table stakes`, or any label that reads as a verdict.

## Sections

1. **Masthead**: title, one-line description of what the page is, legend (note colours with counts, total notes, number of sources).
2. **Problem**: three to four sentences. First sentence names the core friction. Last sentence names what is out of scope.
3. **Objectives**: two to four cards, the user's primary objective first. Optional "Keep in view while designing" list for things that shape the layout but are not objectives.
4. **Shared patterns**: table with columns Pattern, Who, `<product>` today, Status. "Who" names sources; never "everyone".
5. **Current state**: one line per finding, source chip on each.
6. **Scope**: "Proposed v1 scope" list, "Patterns to avoid" list (competitor mistakes, each naming the source).
7. **Directions**: one card per direction stub. Card holds: tag (v1, v2, Option A), name, "After <references>", summary rewritten from the user's stub text without judgement, "Open" list of questions the stub raises, optional schematic wireframe. Intro line: "Summaries from the direction notes on the board. Wireframes are schematic." No matrix.
8. **Open decisions**: questions the directions depend on, each with a one-line note and refs.
9. **Feature ideas, separate track**: grouped lists of enhancements and new features surfaced by the notes. Intro line states these are not part of the flow work and can be logged as a backlog.
10. **All notes**: `<details>` per source, closed by default. Each note: colour swatch, verbatim text (with `[duplicate]` or `[corrected: …]` markers where agreed), screen label in mono, "Open" link to the note.
11. **Coverage and gaps**: sources with screens but no notes, duplicate notes, notes that could not be read, direction stubs that are placeholders.

## HTML page

- Single file, theme aware (light tokens on `:root`, dark under `prefers-color-scheme` guarded with `:root:not([data-theme="light"])`, and again under `:root[data-theme="dark"]`). Body background from a token.
- Left sticky table of contents on wide screens, single column below 980px, 16px side gutter at every width.
- Note chips: mono, small, bordered, link to the note. Swatches use the real sticky colours.
- Wireframes: inline SVG, rectangles only, classes mapped to theme tokens, `role="img"` with an aria-label, labelled schematic in the section intro.
- Fonts from Google Fonts with a fallback stack. Avoid the defaults that read as generated (cream plus serif display, Inter as the safe face).

## Markdown copy

Same sections in the same order. Chips become `[id](url)` links. Tables stay tables. The inventory is a table per source. No wireframes.

## Republish loop

Edit the data structure, rebuild both files, republish to the same artifact path. Reply with the link and a short list of what changed. Do not restate the document.
