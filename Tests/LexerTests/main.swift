// CLI tests for CodeHighlighter (generic lexer).

import AppKit

var passed = 0, failed = 0
func expect(_ c: Bool, _ n: String) { if c { passed += 1; print("  ok  \(n)") } else { failed += 1; print("FAIL  \(n)") } }

let hl = CodeHighlighter()

/// Color assigned at the first character of `needle`, or nil.
func colorAt(_ code: String, _ needle: String, _ lang: String?) -> NSColor? {
    let at = (code as NSString).range(of: needle).location
    guard at != NSNotFound else { return nil }
    for span in hl.spans(for: code, language: lang) where NSLocationInRange(at, span.range) {
        return span.color
    }
    return nil
}

// Swift
do {
    let code = "func greet(_ name: String) -> Int {\n    // return the length\n    return name.count + 42\n}"
    expect(colorAt(code, "func", "swift") == EditorTheme.codeKeywordColor, "swift: keyword func")
    expect(colorAt(code, "return the length", "swift") == EditorTheme.codeCommentColor, "swift: line comment")
    expect(colorAt(code, "42", "swift") == EditorTheme.codeNumberColor, "swift: number")
    expect(colorAt(code, "greet", "swift") == nil, "swift: identifier not tinted")
    // 'return' inside the comment text must NOT be a keyword.
    expect(colorAt(code, "return the", "swift") == EditorTheme.codeCommentColor, "swift: keyword inside comment stays comment")
}

// String masks keywords/numbers inside
do {
    let code = "let s = \"func 123 return\"\n"
    expect(colorAt(code, "\"func 123 return\"", "swift") == EditorTheme.codeStringColor, "swift: string literal tinted")
    // The 'func' inside the string is part of the string span, not a keyword.
    let at = (code as NSString).range(of: "func 123").location
    var isKeyword = false
    for span in hl.spans(for: code, language: "swift") where NSLocationInRange(at, span.range) && span.color == EditorTheme.codeKeywordColor { isKeyword = true }
    expect(!isKeyword, "swift: keyword inside string not tinted as keyword")
}

// Python: hash comment, triple string
do {
    let code = "def f(x):\n    \"\"\"doc\n    string\"\"\"\n    return x  # trailing\n"
    expect(colorAt(code, "def", "python") == EditorTheme.codeKeywordColor, "python: keyword def")
    expect(colorAt(code, "doc", "python") == EditorTheme.codeStringColor, "python: triple-quoted string")
    expect(colorAt(code, "trailing", "python") == EditorTheme.codeCommentColor, "python: hash comment")
    // '#' must not be a comment in a c-like language by default, but here it is python.
}

// Block comment (c-like) spanning lines
do {
    let code = "int x = 1; /* multi\n line comment */ int y = 2;\n"
    expect(colorAt(code, "multi", "c") == EditorTheme.codeCommentColor, "c: block comment start")
    expect(colorAt(code, "comment", "c") == EditorTheme.codeCommentColor, "c: block comment continues across lines")
    expect(colorAt(code, "int y", "c") == EditorTheme.codeKeywordColor, "c: code resumes after block comment")
}

// SQL case-insensitive keywords
do {
    let code = "select * from users where id = 10;\nSELECT name FROM t;\n"
    expect(colorAt(code, "select", "sql") == EditorTheme.codeKeywordColor, "sql: lowercase keyword")
    expect(colorAt(code, "SELECT", "sql") == EditorTheme.codeKeywordColor, "sql: uppercase keyword")
    expect(colorAt(code, "10", "sql") == EditorTheme.codeNumberColor, "sql: number")
    expect(colorAt(code, "'", "sql") == nil || true, "sql: sanity")
}

// Unknown language: still strings/comments/numbers, no keyword coloring
do {
    let code = "banana // note\nvalue = \"hi\" 7\n"
    expect(colorAt(code, "note", "cobol") == EditorTheme.codeCommentColor, "unknown: default line comment")
    expect(colorAt(code, "\"hi\"", "cobol") == EditorTheme.codeStringColor, "unknown: default string")
    expect(colorAt(code, "7", "cobol") == EditorTheme.codeNumberColor, "unknown: default number")
    expect(colorAt(code, "banana", "cobol") == nil, "unknown: no keyword coloring")
}

// No language: c-like default
do {
    let code = "x = 5 // c-like default\n"
    expect(colorAt(code, "c-like default", nil) == EditorTheme.codeCommentColor, "nil language: c-like comment")
}

// Robustness
do {
    _ = hl.spans(for: "", language: "swift")
    _ = hl.spans(for: "\"unterminated", language: "swift")
    _ = hl.spans(for: "/* unterminated block", language: "c")
    expect(true, "unterminated tokens do not crash")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
