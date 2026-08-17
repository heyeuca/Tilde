//
//  MarkdownRenderer.swift
//  Tilde
//

import AppKit

/// Renders Markdown source into a styled `NSAttributedString` for the
/// read-only Preview mode (⌘⇧P).
///
/// Apple's `AttributedString(markdown:, .full)` parser identifies block
/// structure as `PresentationIntent` metadata but applies no visual
/// styling; this renderer walks that metadata and builds the styled text
/// using the same `EditorTheme` tokens as the editor, so toggling into
/// Preview reads as the syntax markers dissolving rather than a different
/// app.
///
/// Tables and images are handled in later milestones; this milestone covers
/// paragraphs, headings, lists (including nesting), blockquotes, code
/// blocks, thematic breaks, links, and inline styles.
struct MarkdownRenderer {
    var fontSize: CGFloat = EditorTheme.defaultFontSize

    /// Indentation added per list-nesting level and for blockquotes.
    private let indentUnit: CGFloat = 22

    // MARK: - Entry point

    func render(_ markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            // The parser should never throw under this policy, but never
            // fail to show something: fall back to plain body text.
            return NSAttributedString(
                string: markdown,
                attributes: EditorTheme.bodyAttributes(monospaced: false, size: fontSize)
            )
        }
        return build(from: parsed)
    }

    // MARK: - Block grouping

    /// A leaf block (paragraph, heading, code block, …) with its runs.
    private struct Block {
        var intent: PresentationIntent?
        var runs: [(text: String, inline: InlinePresentationIntent?, link: URL?)] = []
    }

    private func build(from parsed: AttributedString) -> NSAttributedString {
        // Group runs into leaf blocks by the identity of their innermost
        // presentation-intent component.
        var blocks: [Block] = []
        var previousLeafIdentity: Int?
        for run in parsed.runs {
            let text = String(parsed[run.range].characters)
            let intent = run.presentationIntent
            let leafIdentity = intent?.components.first?.identity
            if blocks.isEmpty || leafIdentity != previousLeafIdentity {
                blocks.append(Block(intent: intent))
            }
            previousLeafIdentity = leafIdentity
            blocks[blocks.count - 1].runs.append((text, run.inlinePresentationIntent, run.link))
        }

        let result = NSMutableAttributedString()
        var index = 0
        var afterTable = false
        while index < blocks.count {
            let block = blocks[index]
            if let tableID = tableIdentity(of: block.intent) {
                // Consume every block belonging to this table.
                var tableBlocks: [Block] = []
                while index < blocks.count, tableIdentity(of: blocks[index].intent) == tableID {
                    tableBlocks.append(blocks[index])
                    index += 1
                }
                appendTable(tableBlocks, to: result, isFirst: result.length == 0)
                afterTable = true
                continue
            }
            // A text block's paragraphSpacing is swallowed by the table
            // layout, so the gap below a table is added as leading space on
            // the block that follows it.
            append(block, to: result, isFirst: index == 0, extraSpacingBefore: afterTable)
            afterTable = false
            index += 1
        }
        return result
    }

    // MARK: - Tables

    private func tableIdentity(of intent: PresentationIntent?) -> Int? {
        intent?.components.first(where: { if case .table = $0.kind { return true }; return false })?.identity
    }

    private func appendTable(_ blocks: [Block], to result: NSMutableAttributedString, isFirst: Bool) {
        // Column geometry from the shared table intent.
        var columns: [PresentationIntent.TableColumn] = []
        for component in blocks.first?.intent?.components ?? [] {
            if case .table(let cols) = component.kind { columns = cols }
        }
        let columnCount = max(columns.count, 1)

        let table = NSTextTable()
        table.numberOfColumns = columnCount

        let blockStart = result.length
        for cell in blocks {
            var column = 0
            var row = 0
            var isHeader = false
            for component in cell.intent?.components ?? [] {
                switch component.kind {
                case .tableCell(let c): column = c
                case .tableHeaderRow: isHeader = true; row = 0
                case .tableRow(let ordinal): row = ordinal
                default: break
                }
            }

            let tableBlock = NSTextTableBlock(
                table: table, startingRow: row, rowSpan: 1,
                startingColumn: column, columnSpan: 1
            )
            tableBlock.setBorderColor(.separatorColor)
            tableBlock.setWidth(1, type: .absoluteValueType, for: .border)
            tableBlock.setWidth(6, type: .absoluteValueType, for: .padding)

            let style = NSMutableParagraphStyle()
            style.textBlocks = [tableBlock]
            style.alignment = alignment(for: column, in: columns)

            let baseFont = isHeader
                ? EditorTheme.boldBodyFont(size: fontSize)
                : EditorTheme.bodyFont(monospaced: false, size: fontSize)

            let cellStart = result.length
            for run in cell.runs {
                result.append(inlineAttributed(run, baseFont: baseFont, quoted: false))
            }
            result.append(NSAttributedString(string: "\n"))
            result.addAttribute(.paragraphStyle,
                                value: style,
                                range: NSRange(location: cellStart, length: result.length - cellStart))
        }
        _ = (blockStart, isFirst)
    }

    private func alignment(for column: Int, in columns: [PresentationIntent.TableColumn]) -> NSTextAlignment {
        guard column < columns.count else { return .left }
        switch columns[column].alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        @unknown default: return .left
        }
    }

    // MARK: - Block rendering

    private func append(_ block: Block, to result: NSMutableAttributedString, isFirst: Bool, extraSpacingBefore: Bool = false) {
        let components = block.intent?.components ?? []
        let leafKind = components.first?.kind

        switch leafKind {
        case .thematicBreak:
            appendThematicBreak(to: result)
            return
        case .codeBlock(let language):
            appendCodeBlock(block, language: language, to: result)
            return
        default:
            break
        }

        // Header level, if any.
        var headerLevel = 0
        for component in components {
            if case .header(let level) = component.kind { headerLevel = level }
        }

        // List context: the nearest list container defines the marker; the
        // count of list containers is the nesting depth.
        var listOrdinal: Int?
        var listOrdered: Bool?
        var listDepth = 0
        for component in components {
            switch component.kind {
            case .listItem(let ordinal):
                if listOrdinal == nil { listOrdinal = ordinal }
            case .orderedList:
                if listOrdered == nil { listOrdered = true }
                listDepth += 1
            case .unorderedList:
                if listOrdered == nil { listOrdered = false }
                listDepth += 1
            default:
                break
            }
        }

        let isQuote = components.contains { if case .blockQuote = $0.kind { return true }; return false }

        // Base font for this block's body runs.
        let baseFont: NSFont = headerLevel > 0
            ? EditorTheme.headingFont(level: headerLevel, size: fontSize)
            : EditorTheme.bodyFont(monospaced: false, size: fontSize)

        let blockStart = result.length

        // List / prefix marker.
        var markerLength = 0
        if let ordered = listOrdered {
            let marker = ordered ? "\(listOrdinal ?? 1).\t" : "•\t"
            result.append(NSAttributedString(string: marker, attributes: [
                .font: EditorTheme.listMarkerFont(size: fontSize),
                .foregroundColor: isQuote ? EditorTheme.quoteColor : NSColor.textColor,
            ]))
            markerLength = (marker as NSString).length
        }

        // Body runs with inline styling.
        for run in block.runs {
            result.append(inlineAttributed(run, baseFont: baseFont, quoted: isQuote))
        }
        result.append(NSAttributedString(string: "\n"))

        // Paragraph style for the whole block.
        let style = NSMutableParagraphStyle()
        style.lineSpacing = EditorTheme.lineSpacing(for: baseFont)
        style.paragraphSpacing = EditorTheme.lineSpacing(for: baseFont)
        if !isFirst {
            if headerLevel > 0 {
                style.paragraphSpacingBefore = EditorTheme.lineSpacing(for: baseFont) * 1.5
            } else if extraSpacingBefore {
                style.paragraphSpacingBefore = EditorTheme.lineSpacing(for: baseFont)
            }
        }

        let listIndent = CGFloat(listDepth) * indentUnit
        let quoteIndent = isQuote ? indentUnit : 0
        if listDepth > 0 {
            style.firstLineHeadIndent = CGFloat(listDepth - 1) * indentUnit + quoteIndent
            style.headIndent = listIndent + quoteIndent
            style.tabStops = [NSTextTab(textAlignment: .left, location: listIndent + quoteIndent)]
        } else if isQuote {
            style.firstLineHeadIndent = quoteIndent
            style.headIndent = quoteIndent
        }

        let blockRange = NSRange(location: blockStart, length: result.length - blockStart)
        result.addAttribute(.paragraphStyle, value: style, range: blockRange)
        _ = markerLength
    }

    private func appendCodeBlock(_ block: Block, language: String?, to result: NSMutableAttributedString) {
        let blockStart = result.length
        var text = block.runs.map(\.text).joined()
        // The parser keeps a trailing newline inside the code block; drop it
        // so the block separator is the only gap after.
        if text.hasSuffix("\n") { text.removeLast() }

        result.append(NSAttributedString(string: text, attributes: [
            .font: EditorTheme.codeFont(size: fontSize),
            .foregroundColor: NSColor.textColor,
            .backgroundColor: EditorTheme.codeBackgroundColor,
        ]))
        result.append(NSAttributedString(string: "\n"))

        let style = NSMutableParagraphStyle()
        style.lineSpacing = EditorTheme.lineSpacing(for: EditorTheme.codeFont(size: fontSize))
        style.paragraphSpacing = EditorTheme.lineSpacing(for: EditorTheme.bodyFont(monospaced: false, size: fontSize))
        style.firstLineHeadIndent = indentUnit
        style.headIndent = indentUnit
        result.addAttribute(.paragraphStyle,
                            value: style,
                            range: NSRange(location: blockStart, length: result.length - blockStart))
    }

    private func appendThematicBreak(to result: NSMutableAttributedString) {
        let width = EditorTheme.maxContentWidth - 2 * EditorTheme.padding
        let image = NSImage(size: NSSize(width: width, height: 1))
        image.lockFocus()
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: 1).fill()
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: 0, width: width, height: 1)

        let blockStart = result.length
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: "\n"))

        let style = NSMutableParagraphStyle()
        let bodyFont = EditorTheme.bodyFont(monospaced: false, size: fontSize)
        style.paragraphSpacing = EditorTheme.lineSpacing(for: bodyFont)
        style.paragraphSpacingBefore = EditorTheme.lineSpacing(for: bodyFont)
        result.addAttribute(.paragraphStyle,
                            value: style,
                            range: NSRange(location: blockStart, length: result.length - blockStart))
    }

    // MARK: - Inline rendering

    private func inlineAttributed(
        _ run: (text: String, inline: InlinePresentationIntent?, link: URL?),
        baseFont: NSFont,
        quoted: Bool
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [:]
        let inline = run.inline

        if inline?.contains(.code) == true {
            attributes[.font] = EditorTheme.codeFont(size: baseFont.pointSize)
            attributes[.backgroundColor] = EditorTheme.codeBackgroundColor
        } else {
            attributes[.font] = styledFont(base: baseFont, inline: inline)
        }

        if inline?.contains(.strikethrough) == true {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let link = run.link {
            attributes[.foregroundColor] = EditorTheme.linkColor
            attributes[.link] = link
        } else {
            attributes[.foregroundColor] = quoted ? EditorTheme.quoteColor : NSColor.textColor
        }

        return NSAttributedString(string: run.text, attributes: attributes)
    }

    private func styledFont(base: NSFont, inline: InlinePresentationIntent?) -> NSFont {
        guard let inline else { return base }
        var font = base
        let manager = NSFontManager.shared
        if inline.contains(.stronglyEmphasized) {
            font = manager.convert(font, toHaveTrait: .boldFontMask)
        }
        if inline.contains(.emphasized) {
            font = manager.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }
}
