//
//  NSDocument+ExternalWrites.swift
//  Tilde
//

import AppKit
import ObjectiveC

/// Unsaved edits survive another app's coordinated write (#32).
///
/// When another process writes the file through `NSFileCoordinator`,
/// AppKit's `presentedItemDidChange()` reverts an autosave-in-place
/// document to the file on disk even when it has unsaved changes: the
/// window switches to the other content, and the edit and its undo
/// history are gone without a prompt. SwiftUI's document class is private,
/// so AppKit's implementation is exchanged once at launch and only passed
/// the notification when the document has no unsaved changes.
///
/// - A clean document still reloads, as before.
/// - An edited document keeps the user's text. Its `fileModificationDate`
///   is still the one from before the write, so the next save or autosave
///   shows AppKit's "The file has been changed by another application."
///   sheet (Save Anyway / Revert), the same as after a plain write.
extension NSDocument {
    static func keepUnsavedEditsOnExternalWrites() {
        _ = exchangePresentedItemDidChange
    }

    private static let exchangePresentedItemDidChange: Void = {
        guard let original = class_getInstanceMethod(NSDocument.self, #selector(presentedItemDidChange)),
              let replacement = class_getInstanceMethod(NSDocument.self, #selector(tilde_presentedItemDidChange))
        else { return }
        method_exchangeImplementations(original, replacement)
    }()

    /// Runs on the presenter queue. The edited state is read on the main
    /// actor, then AppKit's implementation runs back on the presenter
    /// queue, where it would have run.
    @objc private nonisolated dynamic func tilde_presentedItemDidChange() {
        Task { @MainActor in
            guard !self.isDocumentEdited else { return }
            self.presentedItemOperationQueue.addOperation {
                // Exchanged: this calls AppKit's original implementation.
                self.tilde_presentedItemDidChange()
            }
        }
    }
}
