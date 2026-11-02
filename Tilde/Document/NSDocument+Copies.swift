//
//  NSDocument+Copies.swift
//  Tilde
//

import AppKit
import ObjectiveC
import os
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
/// - `prepareSavePanel(_:)`: for a file whose type the panel can't list
///   (no extension, like `id_ed25519`, or an unknown one, like `.pub`),
///   the proposed name keeps the source's extension, or none, instead of
///   Plain Text's `.txt`. Picking another format still applies that
///   format's extension.
///   The panel still shows `.txt` while Plain Text is selected, so
///   `SavePanelNameDelegate` drops it when the user confirms exactly the
///   proposed name with `.txt` appended (inside the panel, so the sandbox
///   grants the final file). `save(to:ofType:for:completionHandler:)` is
///   exchanged only to log the final URL.
///
/// The `SavePanel` log category (subsystem: the app's bundle id) traces each step:
/// `log stream --predicate 'subsystem == "co.euca.Tilde" AND category == "SavePanel"' --level debug`
extension NSDocument {
    static func keepFileTypeAndPermissionsOnCopies() {
        _ = exchangeImplementations
    }

    private static let exchangeImplementations: Void = {
        exchange(#selector(writableTypes(for:)), #selector(tilde_writableTypes(for:)))
        exchange(#selector(fileAttributesToWrite(to:ofType:for:originalContentsURL:)),
                 #selector(tilde_fileAttributesToWrite(to:ofType:for:originalContentsURL:)))
        exchange(NSSelectorFromString("duplicateAndReturnError:"), #selector(tilde_duplicate))
        exchange(#selector(prepareSavePanel(_:)), #selector(tilde_prepareSavePanel(_:)))
        exchange(#selector(save(to:ofType:for:completionHandler:)),
                 #selector(tilde_save(to:ofType:for:completionHandler:)))
    }()

    static let savePanelLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "co.euca.Tilde", category: "SavePanel")

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

    /// The name the save panel should propose for a copy of `sourceURL`,
    /// or `nil` to leave the panel alone. Only for a source the panel can't
    /// list (`writableTypes(_:listing:)` leaves its type out): no extension
    /// (`id_ed25519`, `.gitignore`) or an unknown one (`.pub`). The panel
    /// then falls back to Plain Text and proposes `current` with `.txt`;
    /// that extension is swapped for the source's, or dropped.
    static func savePanelName(_ current: String, sourceURL: URL) -> String? {
        let listed = TextDocument.writableContentTypes
        let ext = sourceURL.pathExtension
        if !ext.isEmpty {
            guard let type = UTType(filenameExtension: ext), !listed.contains(type),
                  writableTypes(listed.map(\.identifier), listing: type.identifier) == listed.map(\.identifier)
            else { return nil }
        }
        var name = current
        let currentExt = (current as NSString).pathExtension.lowercased()
        if !ext.isEmpty && currentExt == ext.lowercased() {
            return name
        }
        if listed.contains(where: { $0.tags[.filenameExtension]?.contains(currentExt) == true }) {
            name = (current as NSString).deletingPathExtension
        }
        return ext.isEmpty ? name : name + "." + ext
    }

    /// `proposed`, when the save panel's name field shows it with only
    /// `.txt` appended; otherwise `nil`. AppKit appends the selected
    /// format's extension (Plain Text) after `prepareSavePanel(_:)` sets
    /// the name, so the name is set again once the panel is up. Any other
    /// value (the user typed, or picked another format) is left alone.
    static func savePanelNameToRestore(_ field: String, proposed: String) -> String? {
        let ext = (field as NSString).pathExtension
        guard ext.lowercased() == "txt",
              (field as NSString).deletingPathExtension == proposed
        else { return nil }
        return proposed
    }

    private static var sourceURLKey = 0

    /// A duplicate's source file, until its first save.
    var sourceURL: URL? {
        get { objc_getAssociatedObject(self, &Self.sourceURLKey) as? URL }
        set { objc_setAssociatedObject(self, &Self.sourceURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The file name to save under when the user confirmed `chosen` in
    /// a save panel that proposed `proposed`: `proposed` when `chosen` is
    /// only that name with the `.txt` AppKit appends for Plain Text;
    /// otherwise `nil`, and `chosen` is kept (a typed name, or another
    /// format picked in the menu). The panel only warned about replacing
    /// `chosen`, so `proposed` is used only when no file is there
    /// (`targetExists`) or that file is the document itself (`isOwnFile`);
    /// otherwise another file would be overwritten without a warning.
    static func savedName(_ chosen: String, proposed: String?,
                          targetExists: Bool, isOwnFile: Bool) -> String? {
        guard let proposed, chosen != proposed, !targetExists || isOwnFile else { return nil }
        return savePanelNameToRestore(chosen, proposed: proposed)
    }

    /// Runs after AppKit has set up the panel (name, File Format menu,
    /// allowed types) and before it is shown. For Save As, and for a
    /// duplicate's first save (`fileURL` is still `nil` then), it proposes
    /// `savePanelName(_:sourceURL:)`, lets the panel accept that name's
    /// extension, or none, and puts a `SavePanelNameDelegate` in front of
    /// the panel's delegate. The panel shows that name with `.txt` again;
    /// the delegate drops it when the user confirms, inside the panel, so
    /// the sandbox grants access to the final file. The allowed types are
    /// left as AppKit set them, so the File Format menu stays and choosing
    /// a format still applies that format's extension.
    @objc private dynamic func tilde_prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        let log = Self.savePanelLog
        guard tilde_prepareSavePanel(savePanel) else {
            log.info("prepare: AppKit declined, panel left alone")
            return false
        }
        let field = savePanel.nameFieldStringValue
        let source = fileURL ?? sourceURL
        log.info("prepare: entered, class=\(String(describing: type(of: self)), privacy: .public) fileType=\(self.fileType ?? "nil", privacy: .public) source=\(source?.lastPathComponent ?? "nil", privacy: .public) field=\(field, privacy: .public) delegate=\(String(describing: savePanel.delegate.map { type(of: $0) }), privacy: .public)")
        guard let source, let name = Self.savePanelName(field, sourceURL: source) else {
            log.info("prepare: source type is listed or no source, field left as is")
            return true
        }
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = name
        SavePanelNameDelegate.install(on: savePanel, proposed: name, ownFile: fileURL)
        log.info("prepare: proposed=\(name, privacy: .public) field after set=\(savePanel.nameFieldStringValue, privacy: .public)")
        return true
    }

    /// Log only: the URL the save actually goes to.
    @objc private dynamic func tilde_save(
        to url: URL, ofType typeName: String, for saveOperation: SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if saveOperation == .saveAsOperation || (saveOperation == .saveOperation && fileURL == nil) {
            Self.savePanelLog.info("save: url=\(url.lastPathComponent, privacy: .public) type=\(typeName, privacy: .public)")
        }
        tilde_save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }

    // MARK: - Permissions

    /// The permission bits of the file at `url`; setuid, setgid and sticky
    /// aren't carried over. A symbolic link is followed: its own mode is
    /// usually `rwxr-xr-x`, not the private file it points to.
    static func posixPermissions(at url: URL?) -> Int? {
        guard let url,
              let permissions = try? FileManager.default.attributesOfItem(
                  atPath: url.resolvingSymlinksInPath().path
              )[.posixPermissions] as? Int
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
        duplicate.sourceURL = fileURL ?? sourceURL
        return duplicate
    }
}

/// Sits in front of the save panel's own delegate (NSDocument's) and
/// forwards everything to it, except that a confirmed name that is only
/// the proposed name plus AppKit's `.txt` is returned without `.txt`.
/// Renaming in the panel, not at save time, keeps the file inside the
/// sandbox's grant for the URL the panel returns.
final class SavePanelNameDelegate: NSObject, NSOpenSavePanelDelegate {
    private weak var original: NSOpenSavePanelDelegate?
    private let proposed: String
    private let ownFile: URL?
    private static var key = 0

    private init(original: NSOpenSavePanelDelegate?, proposed: String, ownFile: URL?) {
        self.original = original
        self.proposed = proposed
        self.ownFile = ownFile
    }

    static func install(on panel: NSSavePanel, proposed: String, ownFile: URL?) {
        let original = panel.delegate
        if let current = original as? SavePanelNameDelegate {
            current.uninstall(from: panel)
            return install(on: panel, proposed: proposed, ownFile: ownFile)
        }
        let proxy = SavePanelNameDelegate(original: original, proposed: proposed, ownFile: ownFile)
        // The panel's delegate is weak: the panel keeps the proxy alive.
        objc_setAssociatedObject(panel, &key, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        panel.delegate = proxy
    }

    private func uninstall(from panel: NSSavePanel) {
        panel.delegate = original
        objc_setAssociatedObject(panel, &Self.key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        original?.responds(to: selector) == true ? original : nil
    }

    func panel(_ sender: Any, userEnteredFilename filename: String, confirmed okFlag: Bool) -> String? {
        let log = NSDocument.savePanelLog
        var name: String? = filename
        if let original, original.responds(to: #selector(NSOpenSavePanelDelegate.panel(_:userEnteredFilename:confirmed:))) {
            name = original.panel?(sender, userEnteredFilename: filename, confirmed: okFlag)
        }
        guard okFlag, let entered = name else {
            log.info("delegate: confirmed=\(okFlag, privacy: .public) entered=\(filename, privacy: .public) returned=\(name ?? "nil", privacy: .public)")
            return name
        }
        let directory = (sender as? NSSavePanel)?.directoryURL
        var targetExists = false
        var isOwnFile = false
        if let candidate = NSDocument.savePanelNameToRestore(entered, proposed: proposed), candidate != entered,
           let target = directory?.appendingPathComponent(candidate) {
            targetExists = FileManager.default.fileExists(atPath: target.path)
            isOwnFile = ownFile.map {
                $0.standardizedFileURL.resolvingSymlinksInPath() == target.standardizedFileURL.resolvingSymlinksInPath()
            } ?? false
        }
        let result = NSDocument.savedName(entered, proposed: proposed, targetExists: targetExists, isOwnFile: isOwnFile) ?? entered
        log.info("delegate: confirmed=true entered=\(filename, privacy: .public) proposed=\(self.proposed, privacy: .public) dir=\(directory?.path ?? "nil", privacy: .public) targetExists=\(targetExists, privacy: .public) isOwnFile=\(isOwnFile, privacy: .public) returned=\(result, privacy: .public)")
        return result
    }
}
