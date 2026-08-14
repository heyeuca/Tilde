//
//  EditorView.swift
//  Tilde
//

import SwiftUI

/// Layout shell around the text editor.
///
/// Typography (content width, padding refinements) lands here in a later
/// milestone; the skeleton just fills the window.
struct EditorView: View {
    @ObservedObject var document: TextDocument

    var body: some View {
        TextEditorView(document: document)
            .ignoresSafeArea()
    }
}
