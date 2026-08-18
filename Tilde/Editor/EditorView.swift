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

    private var clampedFontSize: CGFloat { fontSize.clamped(to: AppSettings.fontSizeRange) }

    var body: some View {
        ZStack {
            // The editor stays mounted underneath so caret, scroll, and IME
            // state survive the round trip into Reader and back.
            TextEditorView(
                document: document,
                fontSize: clampedFontSize,
                wordWrap: wordWrap,
                showLineNumbers: lineNumbers,
                markdownStyling: markdownStyling,
                fileURL: fileURL
            )
            .opacity(isReaderMode ? 0 : 1)

            if isReaderMode {
                ReaderView(
                    document: document,
                    fontSize: clampedFontSize,
                    onExit: { isReaderMode = false }
                )
            }
        }
        .ignoresSafeArea()
        .navigationSubtitle(isReaderMode ? "Reader" : "")
        .publishReaderToggle($isReaderMode, enabled: document.isMarkdown)
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
    /// command is disabled for plain text. Markdown-ness is fixed for a
    /// document's lifetime, so the branch does not thrash view identity.
    @ViewBuilder
    func publishReaderToggle(_ binding: Binding<Bool>, enabled: Bool) -> some View {
        if enabled {
            focusedSceneValue(\.readerMode, binding)
        } else {
            self
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> CGFloat {
        CGFloat(Swift.min(Swift.max(self, range.lowerBound), range.upperBound))
    }
}
