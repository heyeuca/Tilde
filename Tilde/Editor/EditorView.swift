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

    var body: some View {
        TextEditorView(
            document: document,
            fontSize: fontSize.clamped(to: AppSettings.fontSizeRange),
            wordWrap: wordWrap,
            showLineNumbers: lineNumbers,
            markdownStyling: markdownStyling
        )
        .ignoresSafeArea()
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> CGFloat {
        CGFloat(Swift.min(Swift.max(self, range.lowerBound), range.upperBound))
    }
}
