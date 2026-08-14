# Tilde

*English · [한국어](README.ko.md)*

**A tiny, beautiful text editor for macOS.**

> `~` — home, plain text, and nothing more than you need.

---

## What is Tilde?

The way software is built has changed. With AI-assisted development, you read and edit code by hand far less often — so reaching for a full IDE just to glance at a single `.txt` or `.md` file feels like too much.

Tilde fills that gap. It's an ultra-lightweight text editor for macOS built around one idea: open the file, read it, maybe change a line, and close it. No projects, no workspaces, no plugins, no terminals, no sidebars.

The goal isn't a smaller IDE. The goal is for the editor to disappear so the content is all that's left.

## Core Values

- **Instant** — Double-click a file and it opens almost immediately.
- **Quiet** — The interface never draws more attention than the content.
- **Native** — It behaves like a built-in macOS app.
- **Beautiful** — Reading text is a pleasure in itself.
- **Disposable** — There is almost nothing to configure or manage.

## Who it's for

Tilde is for people who want to quickly read or lightly edit plain-text files:

- Developers who work with AI and spend less time in code editors
- People who frequently read Markdown documents
- Anyone who wants to inspect a README, note, or config file without launching a heavy editor

It is **not** an IDE, a project workspace, a note database, or a Markdown authoring suite. If you need Git integration, plugins, or multi-file navigation, Tilde is intentionally the wrong tool.

## Features

- Native macOS document-based app (one file → one window)
- Open, edit, and save `.txt`, `.md`, and `.markdown` files
- Opens most UTF-based plain-text files (`.json`, `.yaml`, `.toml`, `.xml`, `.csv`, `.log`, `.env`, and more) as plain text
- Lightweight Markdown styling that keeps syntax visible while improving readability
- Standard editing: undo/redo, cut/copy/paste, drag-and-drop, spell check, Find & Replace
- Word wrap (on by default) and optional line numbers
- Light / Dark / System appearance using macOS semantic colors
- Fast launch and near-zero idle resource usage
- Full macOS integration: Open With, file associations, Recent Documents, Autosave, Versions, Full Screen, window tabs

### Markdown, done lightly

For Markdown files, Tilde applies gentle semantic styling. A heading's `#` stays visible while the text renders slightly larger; `**bold**` keeps its markers while the enclosed text can render in bold. The aim is not to hide Markdown, but to make it easier to read.

Styled elements: headings, bold, italic, strikethrough, inline code, code blocks, blockquotes, links, bullet lists, numbered lists, and horizontal rules.

## Keyboard Shortcuts

Tilde follows macOS conventions.

| Action | Shortcut |
| --- | --- |
| New | `⌘N` |
| Open | `⌘O` |
| Save | `⌘S` |
| Save As | `⌘⇧S` |
| Close | `⌘W` |
| Find | `⌘F` |
| Find Next | `⌘G` |
| Find Previous | `⌘⇧G` |
| Find & Replace | `⌥⌘F` |
| Preferences | `⌘,` |
| Increase Font | `⌘+` |
| Decrease Font | `⌘-` |
| Reset Font | `⌘0` |

## Privacy

Tilde processes every document locally.

- No server uploads
- No account or sign-in
- No cloud storage
- No AI features
- No analytics in the initial release

## Building

Tilde is built with Swift, SwiftUI, and AppKit, using SwiftUI as the primary technology and wrapping `NSTextView` where a mature text engine is needed.

Requirements:

- macOS
- Xcode

To build and run:

```bash
open Tilde.xcodeproj
```

Then build and run from Xcode (`⌘R`).

## Non-Goals

Tilde deliberately leaves out anything that would turn it back into a full IDE:

- Terminal, Git, debugger, build/run, LSP, IntelliSense, refactoring, project explorer
- Extensions, plugins, marketplaces
- Note databases, tags, backlinks, vaults, wikis, sync
- Accounts, comments, shared workspaces, real-time collaboration
- AI completion, chat, rewrite, or agents

For the full product thinking behind these decisions, see [docs/PRODUCT.md](docs/PRODUCT.md).

## License

Tilde is released under the [MIT License](LICENSE).

---

> **Just open the file.**
