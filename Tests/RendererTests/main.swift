// CLI test runner for MarkdownRenderer: render markdown, assert attributes.

import AppKit

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition { passed += 1; print("  ok  \(name)") }
    else { failed += 1; print("FAIL  \(name)") }
}

let renderer = MarkdownRenderer()

func render(_ md: String) -> NSAttributedString { renderer.render(md) }

func font(_ s: NSAttributedString, at i: Int) -> NSFont? {
    s.attribute(.font, at: i, effectiveRange: nil) as? NSFont
}
func color(_ s: NSAttributedString, at i: Int) -> NSColor? {
    s.attribute(.foregroundColor, at: i, effectiveRange: nil) as? NSColor
}
func background(_ s: NSAttributedString, at i: Int) -> NSColor? {
    s.attribute(.backgroundColor, at: i, effectiveRange: nil) as? NSColor
}
func paragraphStyle(_ s: NSAttributedString, at i: Int) -> NSParagraphStyle? {
    s.attribute(.paragraphStyle, at: i, effectiveRange: nil) as? NSParagraphStyle
}
func isBold(_ f: NSFont?) -> Bool { f?.fontDescriptor.symbolicTraits.contains(.bold) ?? false }
func isItalic(_ f: NSFont?) -> Bool { f?.fontDescriptor.symbolicTraits.contains(.italic) ?? false }
func isMono(_ f: NSFont?) -> Bool { f?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false }
func offset(of needle: String, in s: NSAttributedString) -> Int {
    (s.string as NSString).range(of: needle).location
}

// MARK: - Headings

do {
    let s = render("# Title\n\nbody text\n")
    let titleAt = offset(of: "Title", in: s)
    let bodyAt = offset(of: "body", in: s)
    expect(font(s, at: titleAt)?.pointSize == EditorTheme.headingFont(level: 1, size: 14).pointSize, "h1 sized")
    expect(isBold(font(s, at: titleAt)), "h1 bold")
    expect(font(s, at: bodyAt)?.pointSize == 14, "body after heading is body size")
    expect(!s.string.contains("#"), "heading marker removed in preview")
}

do {
    let s = render("### Small\n")
    let at = offset(of: "Small", in: s)
    expect(font(s, at: at)?.pointSize == EditorTheme.headingFont(level: 3, size: 14).pointSize, "h3 sized")
}

// MARK: - Inline styles

do {
    let s = render("normal **bold** and *italic* and `code` and ~~gone~~\n")
    expect(isBold(font(s, at: offset(of: "bold", in: s))), "bold run is bold")
    expect(isItalic(font(s, at: offset(of: "italic", in: s))), "italic run is italic")
    expect(isMono(font(s, at: offset(of: "code", in: s))), "code run is monospaced")
    expect(background(s, at: offset(of: "code", in: s)) != nil, "inline code has background")
    let goneAt = offset(of: "gone", in: s)
    expect((s.attribute(.strikethroughStyle, at: goneAt, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue, "strikethrough applied")
    expect(!isBold(font(s, at: offset(of: "normal", in: s))), "plain run stays regular")
    expect(!s.string.contains("**") && !s.string.contains("~~"), "inline markers removed")
}

// MARK: - Links

do {
    let s = render("see [the docs](https://example.com) now\n")
    let at = offset(of: "the docs", in: s)
    expect(color(s, at: at) == EditorTheme.linkColor, "link text tinted")
    expect((s.attribute(.link, at: at, effectiveRange: nil) as? URL)?.absoluteString == "https://example.com", "link URL attached")
    expect(!s.string.contains("https://"), "link URL hidden in preview")
}

// MARK: - Lists

do {
    let s = render("- alpha\n- beta\n")
    expect(s.string.contains("•\t"), "unordered bullet inserted")
    let alphaAt = offset(of: "alpha", in: s)
    let ps = paragraphStyle(s, at: alphaAt)
    expect(ps != nil && ps!.headIndent > 0, "list item is indented")
}

do {
    let s = render("1. first\n2. second\n")
    expect(s.string.contains("1.\t") && s.string.contains("2.\t"), "ordered markers with ordinals")
}

do {
    let s = render("- top\n  1. nested\n")
    let nestedAt = offset(of: "nested", in: s)
    let topAt = offset(of: "top", in: s)
    let nestedPS = paragraphStyle(s, at: nestedAt)
    let topPS = paragraphStyle(s, at: topAt)
    expect(nestedPS != nil && topPS != nil && nestedPS!.headIndent > topPS!.headIndent, "nested list indented deeper")
    expect(s.string.contains("1.\t"), "nested ordered marker present")
}

// MARK: - Blockquote

do {
    let s = render("> quoted line\n")
    let at = offset(of: "quoted", in: s)
    expect(color(s, at: at) == EditorTheme.quoteColor, "quote text uses quote color")
    let ps = paragraphStyle(s, at: at)
    expect(ps?.textBlocks.isEmpty == false, "quote has a bar text block")
    expect(!s.string.contains(">"), "quote marker removed")
}

// MARK: - Code block

do {
    let s = render("intro\n\n```swift\nlet x = 1\nprint(x)\n```\n\noutro\n")
    let codeAt = offset(of: "let x", in: s)
    expect(isMono(font(s, at: codeAt)), "code block is monospaced")
    expect(paragraphStyle(s, at: codeAt)?.textBlocks.first?.backgroundColor != nil, "code block has a filled background block")
    expect(s.string.contains("let x = 1\nprint(x)"), "code block preserves internal newlines")
    expect(!s.string.contains("```"), "code fence markers removed")
    expect(font(s, at: offset(of: "outro", in: s))?.pointSize == 14, "body resumes after code block")
}

// MARK: - Thematic break

do {
    let s = render("above\n\n---\n\nbelow\n")
    // The break is an attachment; find it.
    var foundAttachment = false
    s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { value, _, _ in
        if value != nil { foundAttachment = true }
    }
    expect(foundAttachment, "thematic break rendered as attachment")
    expect(!s.string.contains("---"), "break markers removed")
}

// MARK: - Tables

func textBlocks(_ s: NSAttributedString, at i: Int) -> [NSTextBlock] {
    (s.attribute(.paragraphStyle, at: i, effectiveRange: nil) as? NSParagraphStyle)?.textBlocks ?? []
}
func alignment(_ s: NSAttributedString, at i: Int) -> NSTextAlignment? {
    (s.attribute(.paragraphStyle, at: i, effectiveRange: nil) as? NSParagraphStyle)?.alignment
}

do {
    let s = render("| Left | Right |\n| :--- | ---: |\n| a | b |\n| c | d |\n")
    let headerAt = offset(of: "Left", in: s)
    let cellAt = offset(of: "a", in: s)
    expect(!textBlocks(s, at: headerAt).isEmpty, "table header cell has a text block")
    expect(!textBlocks(s, at: cellAt).isEmpty, "table body cell has a text block")
    expect(isBold(font(s, at: headerAt)), "table header cell is bold")
    expect(!isBold(font(s, at: cellAt)), "table body cell is not bold")
    // Right column alignment (column index 1).
    let rightAt = offset(of: "Right", in: s)
    expect(alignment(s, at: rightAt) == .right, "right-aligned column honored")
    expect(alignment(s, at: headerAt) == .left, "left-aligned column honored")
    expect(!s.string.contains("|"), "table pipes removed in preview")
    // All four data cells present.
    expect(["a","b","c","d"].allSatisfy { s.string.contains($0) }, "all table cells rendered")
}

do {
    // A table followed by a paragraph must not swallow the paragraph.
    let s = render("| H |\n| --- |\n| x |\n\nafter table\n")
    let afterAt = offset(of: "after table", in: s)
    expect(textBlocks(s, at: afterAt).isEmpty, "paragraph after table is not in a table block")
    expect(font(s, at: afterAt)?.pointSize == 14, "paragraph after table is body text")
}

// MARK: - Images

func attachment(_ s: NSAttributedString, at i: Int) -> NSTextAttachment? {
    s.attribute(.attachment, at: i, effectiveRange: nil) as? NSTextAttachment
}

do {
    // Remote image: never fetched, alt text shown as a link.
    let s = render("![a remote pic](https://example.com/x.png)\n")
    let at = offset(of: "a remote pic", in: s)
    expect(color(s, at: at) == EditorTheme.linkColor, "remote image alt tinted as link")
    expect((s.attribute(.link, at: at, effectiveRange: nil) as? URL)?.host == "example.com", "remote image link retained")
    var hasAttachment = false
    s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, _, _ in if v != nil { hasAttachment = true } }
    expect(!hasAttachment, "remote image not loaded as attachment")
}

do {
    // Missing local image: quiet placeholder with alt text.
    let s = render("![my diagram](nope/missing.png)\n")
    let at = offset(of: "my diagram", in: s)
    expect(color(s, at: at) == EditorTheme.quoteColor, "missing local image shows quiet placeholder")
    expect(s.string.contains("my diagram"), "placeholder includes alt text")
}

do {
    // Real local image resolved against baseURL → attachment.
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tilde-img-\(getpid())")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let imgURL = dir.appendingPathComponent("pic.png")
    let img = NSImage(size: NSSize(width: 40, height: 20))
    img.lockFocus(); NSColor.systemBlue.setFill(); NSRect(x: 0, y: 0, width: 40, height: 20).fill(); img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try? rep.representation(using: .png, properties: [:])!.write(to: imgURL)

    let localRenderer = MarkdownRenderer(baseURL: dir)
    let s = localRenderer.render("![pic](pic.png)\n")
    var found: NSTextAttachment?
    s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, _, _ in
        if let a = v as? NSTextAttachment { found = a }
    }
    expect(found?.image != nil, "local image loaded as attachment")
    expect((found?.bounds.width ?? 0) > 0, "attachment has non-zero width")
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - Robustness

do {
    let s = render("")
    expect(s.length == 0, "empty input renders empty")
}
do {
    // Malformed / partial markdown must not crash and must produce text.
    let s = render("# unterminated **bold and [broken](\n\n```\nno close")
    expect(s.length > 0, "malformed markdown still renders")
}
do {
    let s = render("plain text no markdown at all\n")
    expect(font(s, at: 0)?.pointSize == 14, "plain paragraph is body font")
}

// MARK: - Fuzz: renderer must never crash

do {
    var seed: UInt64 = 0xF022
    func rand(_ n: Int) -> Int {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Int((seed >> 33) % UInt64(n))
    }
    let pieces = ["# ", "## ", "- ", "1. ", "> ", "```", "**", "*", "`", "~~",
                  "[", "](", ")", "![", "|", "---", "\n", "\n\n", "text ", "\t",
                  "http://x.y/z", "café ☕ 日本語 ", "  ", "\\", "<div>"]
    var crashes = 0
    for i in 0..<500 {
        var md = ""
        let parts = 3 + rand(40)
        for _ in 0..<parts { md += pieces[rand(pieces.count)] }
        // Occasionally inject raw random bytes as scalars.
        if rand(4) == 0 { md += String(UnicodeScalar(0x20 + rand(0x2000)) ?? " ") }
        let out = renderer.render(md)
        // Any non-crashing result (including empty) is acceptable.
        if out.length < 0 { crashes += 1 }
        _ = i
    }
    expect(crashes == 0, "fuzz: 500 random/malformed inputs render without crashing")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
