//
//  TextDocument.swift
//  Tilde
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Markdown is not a system-declared type; Tilde imports it (see Info.plist).
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

/// A plain-text document.
///
/// A reference type (`ReferenceFileDocument`) so the editor can push edits
/// without copying the whole buffer through SwiftUI value semantics on
/// every keystroke.
final class TextDocument: ReferenceFileDocument {
    @Published var text: String

    /// Captured at load, preserved on save.
    private(set) var encoding: FileEncoding
    private(set) var lineEnding: LineEnding

    /// Whether this document gets Markdown typography and styling.
    /// New documents are plain text until saved with a Markdown extension.
    private(set) var isMarkdown: Bool

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    init() {
        text = ""
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
        text = normalized.text
        encoding = decoded.encoding
        lineEnding = normalized.lineEnding
        isMarkdown = configuration.contentType.conforms(to: .markdown)
    }

    func snapshot(contentType: UTType) throws -> String {
        text
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = encoding.encode(lineEnding.restore(in: snapshot))
        return FileWrapper(regularFileWithContents: data)
    }
}
