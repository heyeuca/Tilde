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
struct TextEditorView: NSViewRepresentable {
    @ObservedObject var document: TextDocument

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

        context.coordinator.apply(desiredSettings, to: textView, in: scrollView)
        textView.string = document.text
        context.coordinator.restyleAll(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.undoManager = context.environment.undoManager

        guard let textView = scrollView.documentView as? NSTextView else { return }

        if context.coordinator.applied != desiredSettings {
            context.coordinator.apply(desiredSettings, to: textView, in: scrollView)
            context.coordinator.restyleAll(textView)
        }

        // Push external changes (e.g. Revert To) into the view
        // without clobbering in-flight local edits.
        if !context.coordinator.isEditing, textView.string != document.text {
            textView.string = document.text
            context.coordinator.restyleAll(textView)
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
        var isEditing = false
        /// Attribute-only Markdown styling; present while styling is active.
        var styler: MarkdownStyler?
        var applied: AppliedSettings?

        init(parent: TextEditorView) {
            self.parent = parent
        }

        // MARK: - Settings

        func apply(_ settings: AppliedSettings, to textView: NSTextView, in scrollView: NSScrollView) {
            if settings.stylerActive {
                let styler = self.styler ?? MarkdownStyler()
                styler.fontSize = settings.fontSize
                self.styler = styler
                textView.textStorage?.delegate = styler
            } else {
                styler = nil
                textView.textStorage?.delegate = nil
            }

            textView.typingAttributes = EditorTheme.bodyAttributes(
                monospaced: !parent.document.isMarkdown,
                size: settings.fontSize
            )
            textView.defaultParagraphStyle = EditorTheme.paragraphStyle

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
        func restyleAll(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            if let styler {
                styler.restyleAll(textStorage)
            } else {
                let attributes = EditorTheme.bodyAttributes(
                    monospaced: !parent.document.isMarkdown,
                    size: applied?.fontSize ?? parent.fontSize
                )
                textStorage.setAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        /// Markdown documents keep their content no wider than
        /// `EditorTheme.maxContentWidth`, centered; plain text uses the full width.
        func updateContentInsets(of textView: NSTextView) {
            var horizontal = EditorTheme.padding
            if parent.document.isMarkdown, applied?.wordWrap ?? true {
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

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.document.text = textView.string
            isEditing = false
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            undoManager
        }
    }
}
