//
//  TextDocument.swift
//  Tilde
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension UTType {
    /// Markdown is not a system-declared type; Tilde imports it (see Info.plist).
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
    /// TOML has no system UTI either; Tilde imports it so `.toml` files are
    /// recognized as plain text and open (see Info.plist).
    static let toml = UTType(importedAs: "io.toml.toml")
}

/// A plain-text document.
///
/// The document owns the `NSTextStorage` and the text view renders it
/// directly — keystrokes never copy the buffer through SwiftUI. The
/// content is materialized as a `String` only when a save snapshot is
/// taken (DESIGN.md §1).
final class TextDocument: ReferenceFileDocument {
    let textStorage: NSTextStorage

    /// Captured at load, preserved on save.
    private(set) var encoding: FileEncoding
    private(set) var lineEnding: LineEnding

    /// Whether this document gets Markdown typography and styling.
    /// New documents are plain text until saved with a Markdown extension.
    private(set) var isMarkdown: Bool

    /// `.plainText` first: new documents default to `.txt` in the save panel.
    /// `.text` admits the broader family (JSON, YAML, XML, …) via Open With —
    /// all treated as plain text (PRODUCT.md §6). Writable types stay equal
    /// to readable so every file that opens can also be saved back.
    static var readableContentTypes: [UTType] { [.plainText, .markdown, .toml, .text] }

    init() {
        textStorage = NSTextStorage()
        encoding = .default
        lineEnding = .lf
        isMarkdown = false
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoded = FileEncoding.decode(data)
        let normalized = LineEnding.normalizeToLF(decoded.string)
        textStorage = NSTextStorage(string: normalized.text)
        encoding = decoded.encoding
        lineEnding = normalized.lineEnding
        isMarkdown = configuration.contentType.conforms(to: .markdown)
    }

    func snapshot(contentType: UTType) throws -> String {
        textStorage.string
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = encoding.encode(lineEnding.restore(in: snapshot))
        return FileWrapper(regularFileWithContents: data)
    }
}
