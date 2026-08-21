//
//  EditorView.swift
//  Tilde
//

import SwiftUI

/// Layout shell around the text editor; reads user settings and passes
/// them down as plain values.
struct EditorView: View {
    var document: TextDocument
    var fileURL: URL?

    @AppStorage(AppSettings.fontSizeKey) private var fontSize = AppSettings.defaultFontSize
    @AppStorage(AppSettings.wordWrapKey) private var wordWrap = AppSettings.defaultWordWrap
    @AppStorage(AppSettings.lineNumbersKey) private var lineNumbers = AppSettings.defaultLineNumbers
    @AppStorage(AppSettings.markdownStylingKey) private var markdownStyling = AppSettings.defaultMarkdownStyling

    /// Reader mode is per-window and never persisted — a document always
    /// opens in the editor.
    @State private var isReaderMode = false

    /// Lets ReaderView ask the editor for its current reading position when
    /// it mounts, so the rendered view opens at the same place.
    @State private var scrollBridge = EditorScrollBridge()

    private var clampedFontSize: CGFloat { fontSize.clamped(to: AppSettings.fontSizeRange) }

    /// Markdown-ness follows the LIVE file URL, not just the type the
    /// document was opened with, so saving an untitled document as `.md`
    /// switches typography, styling, and the Reader toggle immediately.
    private var isMarkdown: Bool {
        document.isMarkdown || TextDocument.isMarkdownExtension(fileURL?.pathExtension ?? "")
    }

    var body: some View {
        ZStack {
            // The editor stays mounted underneath so caret, scroll, and IME
            // state survive the round trip into Reader and back.
            TextEditorView(
                document: document,
                isMarkdown: isMarkdown,
                fontSize: clampedFontSize,
                wordWrap: wordWrap,
                showLineNumbers: lineNumbers,
                markdownStyling: markdownStyling,
                fileURL: fileURL,
                scrollBridge: scrollBridge
            )
            .opacity(isReaderMode ? 0 : 1)

            if isReaderMode {
                ReaderView(
                    document: document,
                    fontSize: clampedFontSize,
                    entryFraction: { scrollBridge.readFraction() },
                    onExit: { isReaderMode = false }
                )
            }
        }
        .ignoresSafeArea()
        // ⌘= catcher: .keyboardShortcut("+") only fires on the shifted key
        // (⌘⇧=), while Safari/TextEdit/Terminal all accept plain ⌘= for
        // zoom-in. An invisible button supplies the second key equivalent.
        .background {
            Button("") {
                fontSize = AppSettings.increasedFontSize(fontSize)
            }
            .keyboardShortcut("=", modifiers: .command)
            .buttonStyle(.plain)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        // No "Reader" subtitle: the title bar toggle (and the rendered
        // content itself) already convey the mode, and the title area shows
        // only the file name (PRODUCT.md §17).
        .publishReaderToggle($isReaderMode, enabled: isMarkdown)
        .toolbar {
            // A single quiet toggle in the title bar — only for Markdown
            // documents, so plain-text and config windows stay chrome-free.
            if isMarkdown {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $isReaderMode) {
                        Label("Reader", systemImage: "book")
                    }
                    .toggleStyle(.button)
                    .help("Reader (⌘⇧R)")
                }
            }
        }
    }
}

// MARK: - Reader command wiring

/// Focused binding the View menu's Reader command drives. Present only for
/// the frontmost Markdown document window; nil elsewhere disables ⌘⇧R.
struct ReaderModeFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var readerMode: Binding<Bool>? {
        get { self[ReaderModeFocusedValueKey.self] }
        set { self[ReaderModeFocusedValueKey.self] = newValue }
    }
}

private extension View {
    /// Publishes the Reader toggle only for Markdown documents, so the
    /// command is disabled for plain text. Publishing nil (instead of an
    /// `if` branch) keeps view identity stable when markdown-ness changes
    /// at Save As time.
    func publishReaderToggle(_ binding: Binding<Bool>, enabled: Bool) -> some View {
        focusedSceneValue(\.readerMode, enabled ? binding : nil)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> CGFloat {
        CGFloat(Swift.min(Swift.max(self, range.lowerBound), range.upperBound))
    }
}
