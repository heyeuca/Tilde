//
//  MarkdownStyler+Links.swift
//  Tilde
//

import Foundation

/// What the editor's ⌘-click needs from the styled buffer: which link sits
/// under a character, and which line a `#fragment` names.
extension MarkdownStyler {
    /// Marks each `[text](url)` the styler tinted — brackets and URL
    /// included — with its raw `(…)` target. Images, code, and frontmatter
    /// never carry it, and since every restyle resets the attributes, a
    /// buffer without Markdown styling carries none at all.
    static let linkTargetKey = NSAttributedString.Key("tildeLinkTarget")

    /// The raw target of the styled link covering `index`, if any.
    static func linkTarget(at index: Int, in text: NSAttributedString) -> String? {
        guard index >= 0, index < text.length else { return nil }
        return text.attribute(linkTargetKey, at: index, effectiveRange: nil) as? String
    }

    // MARK: - Inline links

    /// One `[text](destination)` or `![alt](src)` on a line, as ranges into
    /// that line.
    struct InlineLink {
        let range: NSRange
        let text: NSRange
        let destination: NSRange
        let isImage: Bool
    }

    /// The inline links and images in `range` of one line, left to right.
    ///
    /// A scanner rather than a regex so the shapes Reader follows hold
    /// together (#38): balanced parentheses stay in the destination
    /// (`…/Foo_(bar)`), link text may nest one level of brackets — so a
    /// badge `[![CI](img)](url)` is one link — and backslash-escaped
    /// brackets and parentheses don't count.
    static func inlineLinks(in line: NSString, range: NSRange) -> [InlineLink] {
        var links: [InlineLink] = []
        let end = NSMaxRange(range)
        var i = range.location
        while i < end {
            let c = line.character(at: i)
            if c == Char.backslash { i += 2; continue }
            let isImage = c == Char.bang && i + 1 < end && line.character(at: i + 1) == Char.openBracket
            if c == Char.openBracket || isImage,
               let link = inlineLink(in: line, at: i, end: end, isImage: isImage) {
                links.append(link)
                i = NSMaxRange(link.range)
            } else {
                i += 1
            }
        }
        return links
    }

    private static func inlineLink(in line: NSString, at start: Int, end: Int, isImage: Bool) -> InlineLink? {
        // Text: up to the `]` that closes the opening bracket.
        let textStart = start + (isImage ? 2 : 1)
        var depth = 1
        var i = textStart
        scanText: while i < end {
            switch line.character(at: i) {
            case Char.backslash: i += 1
            case Char.newline, Char.carriageReturn: return nil
            case Char.openBracket:
                depth += 1
                if depth > 2 { return nil }
            case Char.closeBracket:
                depth -= 1
                if depth == 0 { break scanText }
            default: break
            }
            i += 1
        }
        guard depth == 0, i + 1 < end, line.character(at: i + 1) == Char.openParen else { return nil }
        let textEnd = i

        // Destination: up to the `)` that closes the opening parenthesis.
        // Balanced pairs inside belong to the URL, as does all of a `<…>`.
        let destinationStart = textEnd + 2
        depth = 1
        var inAngle = false
        var atStart = true
        i = destinationStart
        scanDestination: while i < end {
            let c = line.character(at: i)
            switch c {
            case Char.backslash: i += 1
            case Char.newline, Char.carriageReturn: return nil
            case _ where inAngle: if c == Char.closeAngle { inAngle = false }
            case Char.openAngle where atStart: inAngle = true
            case Char.openParen: depth += 1
            case Char.closeParen:
                depth -= 1
                if depth == 0 { break scanDestination }
            default: break
            }
            if c != Char.space { atStart = false }
            i += 1
        }
        guard depth == 0 else { return nil }
        return InlineLink(
            range: NSRange(location: start, length: i + 1 - start),
            text: NSRange(location: textStart, length: textEnd - textStart),
            destination: NSRange(location: destinationStart, length: i - destinationStart),
            isImage: isImage
        )
    }

    private enum Char {
        static let backslash = unichar(UInt8(ascii: "\\"))
        static let bang = unichar(UInt8(ascii: "!"))
        static let openBracket = unichar(UInt8(ascii: "["))
        static let closeBracket = unichar(UInt8(ascii: "]"))
        static let openParen = unichar(UInt8(ascii: "("))
        static let closeParen = unichar(UInt8(ascii: ")"))
        static let openAngle = unichar(UInt8(ascii: "<"))
        static let closeAngle = unichar(UInt8(ascii: ">"))
        static let space = unichar(UInt8(ascii: " "))
        static let newline = unichar(UInt8(ascii: "\n"))
        static let carriageReturn = unichar(UInt8(ascii: "\r"))
    }

    private static let atxHeadingPattern = try! NSRegularExpression(pattern: "^ {0,3}#{1,6}(?:[ \\t]+|$)")
    private static let fencePattern = try! NSRegularExpression(pattern: "^ {0,3}(`{3,}|~{3,})")

    /// Where the `#fragment` heading starts in `string`: ATX headings
    /// outside fenced code and frontmatter are slugged in order, duplicates
    /// taking GitHub's `-1`, `-2`… suffixes as in Reader, and the first
    /// whose slug matches wins.
    static func headingLocation(forFragment fragment: String, in string: NSString) -> Int? {
        let target = MarkdownLink.anchorSlug(forFragment: fragment)
        let bodyStart = MarkdownFrontmatter.range(in: string).map(NSMaxRange) ?? 0

        var used: Set<String> = []
        // The styler only knows column-0 ``` fences; here a `# comment` in a
        // `~~~` or list-indented fence would shift every later slug.
        var openFence: String?
        var location = bodyStart
        while location < string.length {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            defer { location = NSMaxRange(line) }

            let lineText = string.substring(with: line).trimmingCharacters(in: .newlines)
            let whole = NSRange(location: 0, length: (lineText as NSString).length)
            if let fence = fencePattern.firstMatch(in: lineText, range: whole) {
                let run = (lineText as NSString).substring(with: fence.range(at: 1))
                let rest = (lineText as NSString).substring(from: NSMaxRange(fence.range))
                if let open = openFence {
                    if run.first == open.first, run.count >= open.count,
                       rest.trimmingCharacters(in: .whitespaces).isEmpty {
                        openFence = nil
                    }
                    continue
                } else if !(run.first == "`" && rest.contains("`")) {
                    // A backtick info string can't hold a backtick: that's a code span.
                    openFence = run
                    continue
                }
            }
            if openFence != nil { continue }

            guard atxHeadingPattern.firstMatch(in: lineText, range: whole) != nil else { continue }
            let slug = MarkdownLink.uniqueAnchor(MarkdownLink.anchorSlug(for: headingText(lineText)), used: &used)
            if slug == target { return line.location }
        }
        return nil
    }

    /// The heading's text as Reader slugs it: parsed with Reader's options,
    /// so closing `#`s, links, emphasis, and entities resolve the same way.
    private static func headingText(_ line: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: line, options: options) else { return line }
        return String(parsed.characters)
    }
}
