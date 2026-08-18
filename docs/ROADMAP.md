# Tilde Post-MVP Roadmap

Companion to [PRODUCT.md](PRODUCT.md) (what/why) and [DESIGN.md](DESIGN.md)
(how). This file adds: the path to shipping 1.0, and a prioritized,
design-sketched queue for what comes after.

## Ground rules

Every candidate must pass the Feature Admission Rule (PRODUCT.md §34):

1. Does it improve **reading or making a small edit to a text file**?
2. Does macOS already provide it? → don't build it.
3. Does it require users to learn a new concept? → avoid.

And §33's meta-rule: **add nothing until real-world use demonstrates the
need.** The queue below is ordered readiness, not a promise.

---

## Phase 0 — Ship 1.0 (blocking)

Everything here is verification and packaging, not features.

| Step | Where | Notes |
| --- | --- | --- |
| Full `xcodebuild` + sandbox verification | Xcode device | run docs/VERIFY.md top to bottom |
| Distribution decision | — | Developer ID + notarization for direct download (App Store optional later; sandbox-ready either way) |
| GitHub release pipeline | Actions | build → sign → notarize → staple → attach .zip to release |
| CI on pull requests | Actions | macOS runner: build + tests |
| Migrate CLI test runners into an XCTest target | Xcode device | keep the scratchpad CLI runners working for the no-Xcode dev loop |
| Screenshots for README | — | light/dark editor shots; add to repo (public) |
| Open-source hygiene | — | CONTRIBUTING.md, issue templates. Keep them one screen, in Tilde's voice |

## Phase 1 — quiet wins (small, high value, no new concepts)

### 1. Character / Word Count (PRODUCT §33.4)

- **What**: on-demand only — a small popover or window-subtitle readout,
  e.g. View → Statistics (⌘I?). Never an always-on status bar.
- **Design**: compute on invocation from `textStorage.string` (no live
  counters, no background work — §29). Words via
  `enumerateSubstrings(.byWords)`.
- **Cost**: tiny. **Risk**: none.

### 2. Always on Top (PRODUCT §33.5)

- **What**: View → Float on Top toggle per window (`window.level = .floating`).
- **Design**: NSWindow access via the existing representable's window; store
  nothing — per-window, per-session state.
- **Cost**: tiny. **Risk**: none.

### 3. Quick Open (PRODUCT §33.3, ⌘P)

- **What**: a small palette listing Recent Documents, fuzzy-filtered.
- **Design**: source = `NSDocumentController.shared.recentDocumentURLs`
  (macOS already tracks it — rule 2). One floating panel, type-to-filter,
  return-to-open. No project concept, no file indexing.
- **Cost**: medium. **Risk**: scope creep toward a file browser — resist.

## Phase 2 — Markdown Preview (PRODUCT §33.1, ⌘⇧P)

The headline post-MVP feature. Read-only rendered view; the editor's
visible-syntax styling stays the default experience.

- **Mode, not split**: ⌘⇧P swaps the editor for a rendered scroll view
  (and back). No `Editor │ Preview` split (§8).
- **Renderer**: start with `AttributedString(markdown:)` — its
  marker-stripping behavior is exactly right for read-only rendering
  (already noted in DESIGN.md §1). Fall back to swift-markdown only if
  tables/task-lists prove necessary.
- **State**: scroll position mapping editor↔preview is the hard part —
  v1 can approximate by fractional offset.
- **Editing shortcut**: any keystroke in preview flips back to the editor.
- **Cost**: large. Gate on real demand.

## Phase 3 — as demand proves out

### Very light syntax highlighting (PRODUCT §33.2) — DONE

Shipped in two layers, both attribute-only and zero-dependency:

1. **Standalone config files** — `.json` / `.yaml` / `.toml`, keys-only
   tinting (values and punctuation stay default), comments dimmed. Table
   headers tinted for TOML. `CodeSyntaxStyler`, a `SyntaxHighlighting`
   sibling of `MarkdownStyler`; language chosen by file extension via
   `DocumentGroup`'s `fileURL` (TOML needs the imported `io.toml.toml`
   UTI to open); always on, no setting.

2. **Fenced code blocks in the Markdown preview** — a generic left-to-right
   lexer (`CodeHighlighter`, preview only) colors the four token kinds every
   language shares: comments, strings, numbers, and (for ~16 known
   languages) keywords. Unknown languages still get strings/comments/numbers
   via a C-like default. No `highlight.js`, no tree-sitter — the same
   pure-Swift, regex/scan approach CotEditor uses, kept lightweight.

Deliberately NOT done: standalone code files (`.css`, `.swift`, …) stay
plain — that would make Tilde a code editor (§31). Fenced highlighting is a
reading aid inside Markdown, not general code editing.

### Viewport-priority initial styling (DESIGN.md known limit)

Only if multi-MB markdown files turn out to be a real use case: style the
visible range synchronously on open, the rest in chunks on the main queue.
Removes the ~1s open hitch at 4MB. Prerequisite: none — styler already
works on arbitrary ranges.

### Encoding edge cases (only on bug reports)

Latin-1/CP949 fallback reading. PRODUCT §20 scopes this out of MVP;
revisit only if real files fail to open.

## Known small debts (fix opportunistically)

- Empty line inside a code fence still shows the taller caret
  (lineSpacing swallowed into the line box; rare enough to defer)
- Gutter `lineNumber(at:)` scans from document start per draw of the
  first visible fragment — fine at MVP sizes, cache line starts if
  line numbers + huge files becomes a pattern
- `TextDocument` Sendable warning (NSTextStorage property) — silence
  properly with `nonisolated(unsafe)` or an isolation annotation when
  the Swift story settles

## Not doing (reaffirmed)

Everything in PRODUCT.md §31: no terminal/Git/LSP, no plugins, no notes
database, no collaboration, no AI. Tilde stays a place to open a file.
