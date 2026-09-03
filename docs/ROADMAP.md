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
| Distribution decision | ✅ DECIDED | Both channels: signed+notarized DMG via GitHub Releases, and the App Store (first submission manual via Xcode Organizer). Sandbox already on for both |
| GitHub release pipeline | ✅ BUILT (awaiting secrets) | `release.yml`: tag push → build → Developer ID sign → `scripts/make_dmg.sh` → sign DMG → notarize → staple → GitHub release. Blocked only on the 6 repo secrets — setup steps in docs/RELEASING.md. Test first via workflow_dispatch (publishes an artifact, not a release) |
| CI on pull requests | ✅ DONE | `.github/workflows/ci.yml`: Tests job runs `Tests/run.sh` (467 assertions, 7 suites); Build job runs a real `xcodebuild` Release build (unsigned) and uploads a `Tilde-unsigned` .app artifact. Already caught its first real bug (missing `import Combine` under MemberImportVisibility) |
| Test suites live in the repo | ✅ DONE | `Tests/` — plain-executable suites + `Tests/run.sh`; no XCTest, so they run with Command Line Tools alone (and on CI). XCTest-target migration no longer needed |
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

## Phase 2 — Markdown Reader (PRODUCT §33.1, ⌘⇧R)

The headline post-MVP feature. Read-only rendered view; the editor's
visible-syntax styling stays the default experience.

- **Mode, not split**: ⌘⇧R swaps the editor for a rendered scroll view
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

2. **Fenced code blocks in the Markdown Reader** — a generic left-to-right
   lexer (`CodeHighlighter`, preview only) colors the four token kinds every
   language shares: comments, strings, numbers, and (for ~16 known
   languages) keywords. Unknown languages still get strings/comments/numbers
   via a C-like default. No `highlight.js`, no tree-sitter — the same
   pure-Swift, regex/scan approach CotEditor uses, kept lightweight.

Deliberately NOT done: standalone code files (`.css`, `.swift`, …) stay
plain — that would make Tilde a code editor (§31). Fenced highlighting is a
reading aid inside Markdown, not general code editing.

### Localization — DONE (2026-09)

UI strings ship in English, Korean, Japanese, and Simplified Chinese via
two String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`);
terminology follows Apple's own macOS localizations (Safari's Reader,
TextEdit, System Settings). Adding a language is a catalog edit plus a
`knownRegions` entry — see DESIGN.md §2 "Localization". The presence of
the `.lproj` folders alone also makes AppKit's standard menus (File, Edit,
Window, …) follow the system language, which is most of what users see.
`Tests/LocalizationTests` fails CI if a UI literal lacks a catalog entry or
a translation is missing.

### Viewport-priority initial styling (DESIGN.md known limit)

Only if multi-MB markdown files turn out to be a real use case: style the
visible range synchronously on open, the rest in chunks on the main queue.
Removes the ~1s open hitch at 4MB. Prerequisite: none — styler already
works on arbitrary ranges.

### Encoding edge cases (only on bug reports)

Latin-1/CP949 fallback reading. PRODUCT §20 scopes this out of MVP;
revisit only if real files fail to open. Since the 2026-08 app-review fixes such
files are SAFE — they open read-only with a notice and can't be saved
over — so this is purely about letting them be edited, not data loss.

### Reader sibling images under the sandbox (security-scoped folder grant)

Opening `doc.md` grants sandbox access to that file only, so a relative
`./images/foo.png` shows its alt-text fallback in the sandboxed build
(READER.md constraint B; README describes the limitation). If real-world
use demands sibling images: ask once per folder via `NSOpenPanel`, persist
a security-scoped bookmark, resolve images through it. It's a product
trade (quiet app vs. permission prompt) — gate on demand, and verify on
the Xcode device since the dev machine can't run sandboxed builds.

## Known small debts (fix opportunistically)

- Empty line inside a code fence still shows the taller caret
  (lineSpacing swallowed into the line box; rare enough to defer)

## Not doing (reaffirmed)

Everything in PRODUCT.md §31: no terminal/Git/LSP, no plugins, no notes
database, no collaboration, no AI. Tilde stays a place to open a file.
