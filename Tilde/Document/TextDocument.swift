//
//  TextDocument.swift
//  Tilde
//

import SwiftUI
import AppKit
// ObservableObject's synthesized objectWillChange lives in Combine; with
// MemberImportVisibility enabled the conformance needs the direct import.
import Combine
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

    /// True when the file's bytes could not be decoded exactly (invalid
    /// UTF-8, BOM-less UTF-16 CJK, legacy encodings): the in-memory text
    /// contains substitution characters, so writing it back would corrupt
    /// the original. Such documents open read-only and refuse to save.
    private(set) var isLossy: Bool

    /// Whether this document was OPENED as Markdown. The editor combines
    /// this with the live file URL (see `isMarkdown(openedAsMarkdown:fileURL:)`)
    /// so a document saved with a different extension switches modes
    /// without reopening.
    private(set) var isMarkdown: Bool

    /// File extensions treated as Markdown (mirrors Info.plist's imported
    /// `net.daringfireball.markdown` declaration).
    static func isMarkdownExtension(_ ext: String) -> Bool {
        ["md", "markdown", "mdown"].contains(ext.lowercased())
    }

    /// Markdown-ness for a document as it exists NOW: the live extension
    /// wins, so Save As from `.md` to `.txt` (or back) switches typography,
    /// styling, code highlighting, and the Reader command immediately. The
    /// open-time type is only the fallback for extension-less files and
    /// untitled documents.
    static func isMarkdown(openedAsMarkdown: Bool, fileURL: URL?) -> Bool {
        if let ext = fileURL?.pathExtension, !ext.isEmpty {
            return isMarkdownExtension(ext)
        }
        return openedAsMarkdown
    }

    /// `.plainText` first: new documents default to `.txt` in the save panel.
    /// `.text` admits the broader family (JSON, YAML, XML, …) via Open With —
    /// all treated as plain text (PRODUCT.md §6). Writable types stay equal
    /// to readable so every file that opens can also be saved back.
    static var readableContentTypes: [UTType] { [.plainText, .markdown, .toml, .text] }

    init() {
        textStorage = NSTextStorage()
        encoding = .default
        lineEnding = .lf
        isLossy = false
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
        isLossy = decoded.isLossy
        isMarkdown = configuration.contentType.conforms(to: .markdown)
    }

    func snapshot(contentType: UTType) throws -> String {
        textStorage.string
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        // A lossily decoded buffer contains substitution characters where
        // the original had bytes Tilde couldn't decode; writing it out
        // would destroy those bytes irrecoverably. The editor is read-only
        // for these documents — this guard is the backstop for any other
        // save path (autosave, Versions, scripted saves).
        guard !isLossy else {
            throw CocoaError(.fileWriteInapplicableStringEncoding, userInfo: [
                NSLocalizedDescriptionKey: String(
                    localized: "This file uses an encoding Tilde can't fully read, so saving would corrupt it."
                ),
                NSLocalizedRecoverySuggestionErrorKey: String(
                    localized: "The document is shown read-only to protect the original file. Copy text out of it, or convert the file to UTF-8 with another tool."
                ),
            ])
        }
        // The buffer should already be LF-only (normalized at load, and the
        // editor normalizes paste/drop), but restore() rewrites every `\n`
        // — a stray literal `\r\n` would corrupt into `\r\r\n` on a CRLF
        // document. Re-normalize as a cheap belt-and-braces pass.
        let normalized = LineEnding.normalizeToLF(snapshot).text
        let data = encoding.encode(lineEnding.restore(in: normalized))
        return FileWrapper(regularFileWithContents: data)
    }
}
