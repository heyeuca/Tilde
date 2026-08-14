//
//  TildeApp.swift
//  Tilde
//

import SwiftUI

@main
struct TildeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { TextDocument() }) { configuration in
            EditorView(document: configuration.document)
        }
        .commands {
            // Standard Find menu (⌘F / ⌘G / ⌥⌘F), routed to the text view's find bar.
            TextEditingCommands()
        }
    }
}
