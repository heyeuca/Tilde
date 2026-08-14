//
//  TextEditorView.swift
//  Tilde
//

import SwiftUI
import AppKit

/// Wraps an AppKit `NSTextView` (TextKit 2) for SwiftUI.
///
/// Undo, Find, spell checking, IME, and drag & drop all come from the
/// system text view — Tilde switches them on rather than building them.
/// The view renders the document's own `NSTextStorage`, so typing never
/// round-trips the buffer through SwiftUI.
struct TextEditorView: NSViewRepresentable {
    var document: TextDocument

    var fontSize: CGFloat
    var wordWrap: Bool
    var showLineNumbers: Bool
    var markdownStyling: Bool

    /// The settings state last pushed into AppKit, for cheap diffing.
    struct AppliedSettings: Equatable {
        var fontSize: CGFloat
        var wordWrap: Bool
        var showLineNumbers: Bool
        var stylerActive: Bool
    }

    private var desiredSettings: AppliedSettings {
        AppliedSettings(
            fontSize: fontSize,
            wordWrap: wordWrap,
            showLineNumbers: showLineNumbers,
            stylerActive: document.isMarkdown && markdownStyling
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator

        // Editing behavior
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        // Plain-text editor: smart quotes/dashes would corrupt code and config files.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Appearance
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: EditorTheme.padding, height: EditorTheme.padding)

        // Layout: grow vertically; wrap is configured from settings below.
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Markdown caps its content width; recompute the insets as the
        // window resizes.
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        context.coordinator.attach(document, to: textView, in: scrollView, settings: desiredSettings)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.undoManager = context.environment.undoManager

        guard let textView = scrollView.documentView as? NSTextView else { return }

        // A new document instance (e.g. Revert To) swaps the backing storage.
        if context.coordinator.attachedDocument !== document {
            context.coordinator.attach(document, to: textView, in: scrollView, settings: desiredSettings)
            return
        }

        if context.coordinator.applied != desiredSettings {
            context.coordinator.apply(desiredSettings, to: textView, in: scrollView)
            context.coordinator.restyleAll()
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorView
        /// The document's undo manager (from the SwiftUI environment), so text
        /// edits drive the window's dirty state, autosave, and ⌘Z.
        var undoManager: UndoManager?
        /// Attribute-only Markdown styling; present while styling is active.
        var styler: MarkdownStyler?
        var applied: AppliedSettings?
        private(set) weak var attachedDocument: TextDocument?

        init(parent: TextEditorView) {
            self.parent = parent
        }

        // MARK: - Document attachment

        /// Points the text view at the document's own storage, then styles
        /// the whole buffer exactly once.
        func attach(_ document: TextDocument, to textView: NSTextView, in scrollView: NSScrollView, settings: AppliedSettings) {
            attachedDocument = document
            textView.textContentStorage?.textStorage = document.textStorage
            apply(settings, to: textView, in: scrollView)
            restyleAll()
        }

        // MARK: - Settings

        func apply(_ settings: AppliedSettings, to textView: NSTextView, in scrollView: NSScrollView) {
            let textStorage = attachedDocument?.textStorage
            if settings.stylerActive {
                let styler = self.styler ?? MarkdownStyler()
                styler.fontSize = settings.fontSize
                self.styler = styler
                textStorage?.delegate = styler
            } else {
                styler = nil
                textStorage?.delegate = nil
            }

            let monospaced = !(attachedDocument?.isMarkdown ?? false)
            textView.typingAttributes = EditorTheme.bodyAttributes(
                monospaced: monospaced,
                size: settings.fontSize
            )
            textView.defaultParagraphStyle = EditorTheme.paragraphStyle(
                for: EditorTheme.bodyFont(monospaced: monospaced, size: settings.fontSize)
            )

            configureWordWrap(settings.wordWrap, textView: textView, scrollView: scrollView)
            configureLineNumbers(settings.showLineNumbers, textView: textView, scrollView: scrollView)
            applied = settings
            updateContentInsets(of: textView)
        }

        private func configureWordWrap(_ wrap: Bool, textView: NSTextView, scrollView: NSScrollView) {
            guard let container = textView.textContainer else { return }
            if wrap {
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                container.widthTracksTextView = true
                textView.setFrameSize(NSSize(
                    width: scrollView.contentSize.width,
                    height: textView.frame.height
                ))
                scrollView.hasHorizontalScroller = false
            } else {
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
                container.widthTracksTextView = false
                container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                scrollView.hasHorizontalScroller = true
            }
        }

        private func configureLineNumbers(_ show: Bool, textView: NSTextView, scrollView: NSScrollView) {
            if show {
                if scrollView.verticalRulerView == nil {
                    scrollView.verticalRulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
                }
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true
            } else {
                scrollView.rulersVisible = false
            }
        }

        // MARK: - Typography

        /// Restyles the whole buffer: Markdown via the styler, plain text flat.
        func restyleAll() {
            guard let document = attachedDocument else { return }
            if let styler {
                styler.restyleAll(document.textStorage)
            } else {
                let attributes = EditorTheme.bodyAttributes(
                    monospaced: !document.isMarkdown,
                    size: applied?.fontSize ?? parent.fontSize
                )
                document.textStorage.setAttributes(
                    attributes,
                    range: NSRange(location: 0, length: document.textStorage.length)
                )
            }
        }

        /// Markdown documents keep their content no wider than
        /// `EditorTheme.maxContentWidth`, centered; plain text uses the full width.
        func updateContentInsets(of textView: NSTextView) {
            var horizontal = EditorTheme.padding
            if attachedDocument?.isMarkdown == true, applied?.wordWrap ?? true {
                let excess = textView.frame.width - EditorTheme.maxContentWidth
                horizontal = max(EditorTheme.padding, excess / 2)
            }
            let inset = NSSize(width: horizontal, height: EditorTheme.padding)
            if textView.textContainerInset != inset {
                textView.textContainerInset = inset
            }
        }

        @objc func viewFrameDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateContentInsets(of: textView)
        }

        // MARK: - NSTextViewDelegate

        func undoManager(for view: NSTextView) -> UndoManager? {
            undoManager
        }
    }
}
