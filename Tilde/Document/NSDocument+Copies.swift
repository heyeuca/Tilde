//
//  NSDocument+Copies.swift
//  Tilde
//

import AppKit
import ObjectiveC
import UniformTypeIdentifiers

/// Save As and Duplicate keep the file's extension and permissions (#39).
///
/// SwiftUI's document class is private and offers no hook for either, so
/// AppKit's implementations are exchanged once at launch:
///
/// - `writableTypes(for:)`: SwiftUI answers with the static
///   `TextDocument.writableContentTypes` for every document. When the
///   document's type isn't one of them (`.json`, `.sh`, …), the save panel
///   falls back to the first entry, Plain Text, and proposes `.txt`. With
///   the document's own type listed, the panel selects it and keeps the
///   extension, and the File Format menu still offers the other types.
/// - `fileAttributesToWrite(to:ofType:for:originalContentsURL:)`: the file
///   Save As or a duplicate's first save creates gets the source file's
///   permissions, so a copy of a private key stays `-rw-------`.
/// - `duplicate()`: the duplicate is read back from a copy AppKit writes
///   without group and other access, so it is handed the source's
///   permissions instead.
extension NSDocument {
    static func keepFileTypeAndPermissionsOnCopies() {
        _ = exchangeImplementations
    }

    private static let exchangeImplementations: Void = {
        exchange(#selector(writableTypes(for:)), #selector(tilde_writableTypes(for:)))
        exchange(#selector(fileAttributesToWrite(to:ofType:for:originalContentsURL:)),
                 #selector(tilde_fileAttributesToWrite(to:ofType:for:originalContentsURL:)))
        exchange(NSSelectorFromString("duplicateAndReturnError:"), #selector(tilde_duplicate))
    }()

    private static func exchange(_ original: Selector, _ replacement: Selector) {
        guard let original = class_getInstanceMethod(NSDocument.self, original),
              let replacement = class_getInstanceMethod(NSDocument.self, replacement)
        else { return }
        method_exchangeImplementations(original, replacement)
    }

    // MARK: - Extension

    /// `types` with `fileType` added at the end when it isn't listed and
    /// the save panel can use it. The panel picks a type by the name's
    /// extension, so a type without one (`public.data`, for `id_ed25519`)
    /// is never selected. AppKit also drops a type it has no display name
    /// for (`dyn.*`, for `id_ed25519.pub`) from the panel, then asserts
    /// when asked to select it, leaving the document unable to save.
    /// Those documents keep the static list and propose `.txt`, as before.
    static func writableTypes(_ types: [String], listing fileType: String?) -> [String] {
        guard let fileType, !types.contains(fileType),
              let type = UTType(fileType), !type.isDynamic,
              type.preferredFilenameExtension != nil
        else { return types }
        return types + [fileType]
    }

    /// Set while the replacement reads `fileType`: with no type set,
    /// AppKit's getter falls back to `writableTypes(for:)`, which would
    /// recurse.
    private static var isReadingFileType = false

    @objc private dynamic func tilde_writableTypes(for saveOperation: SaveOperationType) -> [String] {
        // Exchanged: this calls AppKit's original implementation (`dynamic`
        // sends it through the Objective-C runtime instead of recursing).
        let types = tilde_writableTypes(for: saveOperation)
        guard !Self.isReadingFileType else { return types }
        Self.isReadingFileType = true
        defer { Self.isReadingFileType = false }
        return Self.writableTypes(types, listing: fileType)
    }

    // MARK: - Permissions

    /// The permission bits of the file at `url`; setuid, setgid and sticky
    /// aren't carried over.
    static func posixPermissions(at url: URL?) -> Int? {
        guard let url,
              let permissions = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        else { return nil }
        return permissions & 0o777
    }

    private static var sourcePermissionsKey = 0

    /// A duplicate's source file permissions, until its first save.
    var sourcePermissions: Int? {
        get { objc_getAssociatedObject(self, &Self.sourcePermissionsKey) as? Int }
        set { objc_setAssociatedObject(self, &Self.sourcePermissionsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The permissions for the file a save creates: the source's for Save
    /// As and for a duplicate's first save; `nil` (AppKit's default) for
    /// new documents, autosaves and in-place saves, which keep the file's
    /// own permissions.
    func permissionsForCopy(for saveOperation: SaveOperationType) -> Int? {
        switch saveOperation {
        case .saveAsOperation:
            return fileURL.flatMap(Self.posixPermissions(at:)) ?? sourcePermissions
        case .saveOperation where fileURL == nil:
            return sourcePermissions
        default:
            return nil
        }
    }

    @objc private dynamic func tilde_fileAttributesToWrite(
        to url: URL, ofType typeName: String, for saveOperation: SaveOperationType,
        originalContentsURL absoluteOriginalContentsURL: URL?
    ) throws -> [String: Any] {
        var attributes = try tilde_fileAttributesToWrite(
            to: url, ofType: typeName, for: saveOperation, originalContentsURL: absoluteOriginalContentsURL
        )
        if let permissions = permissionsForCopy(for: saveOperation) {
            attributes[FileAttributeKey.posixPermissions.rawValue] = permissions
        }
        return attributes
    }

    @objc private dynamic func tilde_duplicate() throws -> NSDocument {
        let duplicate = try tilde_duplicate()
        duplicate.sourcePermissions = Self.posixPermissions(at: fileURL) ?? sourcePermissions
        return duplicate
    }
}
