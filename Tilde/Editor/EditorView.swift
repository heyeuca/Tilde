//
//  EditorView.swift
//  Tilde
//

import SwiftUI

/// Layout shell around the text editor; reads user settings and passes
/// them down as plain values.
struct EditorView: View {
    var document: TextDocument

    @AppStorage(AppSettings.fontSizeKey) private var fontSize = AppSettings.defaultFontSize
    @AppStorage(AppSettings.wordWrapKey) private var wordWrap = AppSettings.defaultWordWrap
    @AppStorage(AppSettings.lineNumbersKey) private var lineNumbers = AppSettings.defaultLineNumbers
    @AppStorage(AppSettings.markdownStylingKey) private var markdownStyling = AppSettings.defaultMarkdownStyling

    /// Preview mode is per-window and never persisted — a document always
    /// opens in the editor.
    @State private var isPreviewing = false

    private var clampedFontSize: CGFloat { fontSize.clamped(to: AppSettings.fontSizeRange) }

    var body: some View {
        ZStack {
            // The editor stays mounted underneath so caret, scroll, and IME
            // state survive the round trip into Preview and back.
            TextEditorView(
                document: document,
                fontSize: clampedFontSize,
                wordWrap: wordWrap,
                showLineNumbers: lineNumbers,
                markdownStyling: markdownStyling
            )
            .opacity(isPreviewing ? 0 : 1)

            if isPreviewing {
                PreviewView(
                    document: document,
                    fontSize: clampedFontSize,
                    onExit: { isPreviewing = false }
                )
            }
        }
        .ignoresSafeArea()
        .navigationSubtitle(isPreviewing ? "Preview" : "")
        .publishPreviewToggle($isPreviewing, enabled: document.isMarkdown)
    }
}

// MARK: - Preview command wiring

/// Focused binding the View menu's Preview command drives. Present only for
/// the frontmost Markdown document window; nil elsewhere disables ⌘⇧P.
struct PreviewingFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var previewing: Binding<Bool>? {
        get { self[PreviewingFocusedValueKey.self] }
        set { self[PreviewingFocusedValueKey.self] = newValue }
    }
}

private extension View {
    /// Publishes the preview toggle only for Markdown documents, so the
    /// command is disabled for plain text. Markdown-ness is fixed for a
    /// document's lifetime, so the branch does not thrash view identity.
    @ViewBuilder
    func publishPreviewToggle(_ binding: Binding<Bool>, enabled: Bool) -> some View {
        if enabled {
            focusedSceneValue(\.previewing, binding)
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
