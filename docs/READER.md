# Markdown Reader (⌘⇧R) — Design

Post-MVP Phase 2 feature (see ROADMAP.md). Read-only rendered Markdown as a
**mode**, not a split view (PRODUCT.md §8). Decisions settled 2026-08-15:
full v1 scope (tables + local images), return via ⌘⇧R / Esc, mode shown in
the window subtitle.

---

## 1. Architecture

```text
document.textStorage.string
        │
        ▼
AttributedString(markdown:, interpretedSyntax: .full)   Apple parser, zero deps
        │   runs + PresentationIntent (block structure as metadata)
        ▼
MarkdownRenderer                                         intent → attributes
        │   NSAttributedString (EditorTheme tokens)
        ▼
ReaderTextView (read-only NSTextView)                   selection/copy/⌘F free
```

Key fact driving the design: Apple's parser identifies block structure
(header level, list ordinal, quote depth, code language, table geometry)
but applies **no visual styling** — `MarkdownRenderer` walks the runs'
`PresentationIntent` and builds the styled string. That walker is plain
logic → fully testable with the CLI runner on the no-Xcode machine.

### Files

```text
Tilde/Preview/
├── MarkdownRenderer.swift   String → NSAttributedString
└── ReaderView.swift        NSViewRepresentable (read-only NSTextView)
```

Plus: `EditorView` gains the mode state, `TildeApp` the menu command.

## 2. Mode switching

- Per-window transient state: `@State var isReaderMode` in `EditorView`.
  Never persisted — a document always opens in the editor.
- **ZStack, not view swap**: the editor stays alive underneath (opacity 0,
  hit-testing off) so caret, scroll, and IME state survive the round trip.
  The Reader view is created lazily on first use.
- Three entry points, all driving the same `isReaderMode` binding:
  1. **Title-bar toggle** — a single `.toolbar` item (`Toggle` in
     `.button` style) beside the file name, shown only for Markdown
     documents. Window uses `.unifiedCompact` toolbar style so there is no
     separate toolbar row; plain-text/config windows show no button and
     stay chrome-free. The book icon fills/accents when Reader is active.
  2. **Menu**: View → “Show Reader” / “Hide Reader”, `⌘⇧R`, Safari-style
     dynamic label. Wiring: `focusedSceneValue` binding read by
     `ViewCommands` via `@FocusedValue`.
  3. **Esc** in Reader returns to the editor: `ReaderTextView` subclass
     overrides `cancelOperation(_:)`.
- Window subtitle shows “Reader” while active (`navigationSubtitle`).

## 3. Rendering rules (EditorTheme continuity)

Same body size, content-width cap (820), padding, and semantic colors as
the editor — toggling should feel like the markers dissolve, not like a
different app.

| Block | Treatment |
| --- | --- |
| Paragraph | body font, lineSpacing rhythm, paragraphSpacing between blocks |
| Heading 1–6 | `EditorTheme.headingFont`, extra space above |
| Unordered list | inserted `•\t`, hanging indent via tab stop + headIndent |
| Ordered list | inserted `N.\t`, same indent scheme; ordinals from intent |
| Nested lists | indent per nesting depth from the intent stack |
| Blockquote | quoteColor + left indent (v1: no bar; bar is a v2 nicety) |
| Code block | codeFont + codeBackground, indented block, language ignored |
| Thematic break | hairline via 1-pt NSTextAttachment image spanning content width |
| Link | linkColor + `.link` attribute (clickable; read-only view makes this safe) |
| Inline bold/italic/code/strike | same tokens as the editor styler |
| Table | NSTextTable / NSTextTableBlock paragraph styles (see constraint A) |
| Image (local) | NSTextAttachment, scaled to fit content width (constraint B) |
| Image (remote) | never fetched — alt text styled as a link (privacy §30) |

### Constraint A — tables force TextKit 1 in the Reader view

`NSTextTable` is not supported by TextKit 2; NSTextView falls back to
TextKit 1 for content containing text blocks. Acceptable: the Reader is
read-only and rendered per-toggle, so TK1 performance characteristics
don't matter. The EDITOR stays TextKit 2 — only `ReaderTextView` is
affected. Note: construct the Reader NSTextView the classic way to avoid
mixed-mode surprises.

### Constraint B — sandbox blocks sibling images

Opening `doc.md` grants sandbox access to that file only, NOT to
`./images/foo.png` next to it. Behavior:

1. Resolve the image URL relative to the document's directory
2. Try to load; on success → attachment, scaled to `min(natural, content width)`
3. On denial/missing → render alt text in quoteColor with a small missing-image mark

The unsandboxed smoke bundle will always load images (dev machine);
Real sandbox behavior gets verified on the Xcode device. If real-world use
demands sibling images, revisit with a security-scoped folder grant —
that's a product decision (quiet app vs permission prompt), not v1.

## 4. Content, performance & scroll sync

- Render happens on: entering Reader, document instance change (Revert),
  font size change. NOT live-per-keystroke — there is no editing path
  while the editor is hidden.
- **Performance**: Apple's `AttributedString(markdown:)` parser dominates
  the cost and cannot be sped up (measured: ~90 ms at 50 KB, ~170 ms at
  100 KB, ~1.8 s at 1 MB, ~7.5 s at 4 MB). Documents ≤ 256 KB render
  synchronously (no flash); larger ones render on a background queue with a
  generation token so ⌘⇧R never freezes the UI. Verified with a size-sweep
  benchmark and a 500-input renderer fuzz (no crashes).
- Scroll sync: **deferred to v2.** Doing it well needs scroll observation
  and restore on the editor side (already stable), and most rendered
  documents start at the top anyway. Reader opens at the top for now.

## 5. Failure policy

The renderer must never fail: `failurePolicy: .returnPartiallyParsedIfPossible`,
and if parsing throws entirely, fall back to plain body-styled text.
A fuzz test (random byte-noise + truncated markdown) asserts no crash.

## 6. Milestones

1. **Renderer core** — paragraphs, headings, lists, quotes, code blocks,
   HR, links, inline styles. CLI attribute tests (styler-test pattern)
2. **Mode plumbing** — ReaderView, ZStack toggle, ⌘⇧R/Esc, menu item,
   subtitle. Smoke-verify via osascript + screenshots
3. **Tables** — NSTextTable rendering, alignment from column intents
4. **Local images** — attachment loading, scaling, alt-text fallback
5. **Polish** — renderer fuzz + big-doc perf (async render above the size
   threshold). Scroll fraction sync deferred to v2.

Each milestone ends buildable + visually verified on the smoke bundle.

Status: milestones 1–5 implemented and verified on the smoke bundle
(renderer 51 CLI tests incl. fuzz; mode toggle, tables, and local images
confirmed visually). Remaining before shipping: real-sandbox image
behavior and the whole feature under a full Xcode build (docs/VERIFY.md).

## 7. Explicitly not in v1

- Scroll position sync between editor and Reader (v2)
- Live side-by-side or live-typing reader (mode only, §8)
- Remote images,raw HTML, footnotes, task-list checkboxes (parser doesn't
  emit them anyway), syntax highlighting inside code blocks
- Print/PDF export from Reader (could ride on the same attributed string later)
