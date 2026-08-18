# Xcode-Device Verification Checklist

Everything below needs the machine with Xcode (this dev Mac has only
Command Line Tools — code is verified here via swiftc typechecks, CLI test
runners, and the unsigned smoke bundle).

## Build

- [ ] `xcodebuild -project Tilde.xcodeproj -scheme Tilde build` succeeds
      (code already typechecks with `-default-isolation MainActor`; failures
      here would be project-config issues, not code)
- [ ] Asset catalog compiles — AppIcon renders in Dock, Finder, and ⌘Tab
- [ ] No warnings besides the known `NSTextStorage`-Sendable one in
      TextDocument.swift

## Sandbox (the smoke bundle runs unsandboxed — these are UNVERIFIED)

- [ ] Open a file via Finder double-click → edit → ⌘S saves
- [ ] Save As (⌘⇧S) to a new location works
- [ ] Open via drag onto Dock icon and drag into an open window
- [ ] Reopen recent files via File → Open Recent

## File associations (Info.plist UTIs)

- [ ] `.md` / `.markdown` show Tilde in Finder's Open With
- [ ] `.txt` shows Tilde in Open With
- [ ] `.json` / `.log` / `.yml` open via Open With (plain text mode)
- [ ] "Get Info → Change All" association sticks
- [ ] `.toml` opens as text and shows key highlighting (needs the imported
      `io.toml.toml` UTI to register — verify on a clean install, since
      LaunchServices caches the dynamic type)

## Document behavior

- [ ] Autosave: edit, wait, force-quit → relaunch restores content
- [ ] Versions: File → Revert To shows history and restores
- [ ] Window tabs (Window → Merge All Windows) behave
- [ ] Dirty-close on an untitled document prompts to save;
      existing documents close silently (autosave-in-place)

## Performance (targets from PRODUCT.md §28)

- [ ] Cold launch < 500 ms perceived (smoke bundle measured ~225 ms
      including LaunchServices overhead)
- [ ] 4 MB markdown opens in ~1 s, typing stays smooth

## Markdown Preview (⌘⇧P)

- [ ] ⌘⇧P toggles preview; Esc returns to editor; subtitle shows "Preview"
- [ ] Command disabled for plain-text (.txt) documents
- [ ] Headings, lists, quotes, code blocks, HR, links, inline styles render
- [ ] Tables render with borders and column alignment
- [ ] **Sandbox image behavior** (unverifiable on the unsandboxed smoke
      bundle): a sibling `./image.png` is blocked by the sandbox and should
      show the alt-text fallback, NOT the image. Decide whether to add a
      security-scoped folder grant (product call) if this matters.
- [ ] Large document (~1 MB+) preview does not freeze the UI (async render)

## Icon

- [ ] Regenerate if needed: `swift scripts/gen_icon.swift <outdir>` then
      copy sizes into `Tilde/Assets.xcassets/AppIcon.appiconset/`
