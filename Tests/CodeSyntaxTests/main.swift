// CLI tests for CodeSyntaxStyler: keys tinted, values/punctuation default.

import AppKit

var passed = 0, failed = 0
func expect(_ c: Bool, _ n: String) { if c { passed += 1; print("  ok  \(n)") } else { failed += 1; print("FAIL  \(n)") } }

func styled(_ text: String, _ lang: CodeSyntaxStyler.Language) -> NSTextStorage {
    let s = NSTextStorage(string: text)
    let styler = CodeSyntaxStyler()
    styler.language = lang
    styler.restyleAll(s)
    return s
}
func color(_ s: NSTextStorage, at i: Int) -> NSColor? {
    s.attribute(.foregroundColor, at: i, effectiveRange: nil) as? NSColor
}
func offset(_ needle: String, in s: NSTextStorage) -> Int { (s.string as NSString).range(of: needle).location }

// MARK: - JSON

do {
    let json = "{\n  \"name\": \"tilde\",\n  \"count\": 42,\n  \"ok\": true\n}\n"
    let s = styled(json, .json)
    expect(color(s, at: offset("name", in: s)) == EditorTheme.syntaxKeyColor, "json: key tinted")
    // The value string "tilde" must NOT be tinted as a key.
    expect(color(s, at: offset("tilde", in: s)) != EditorTheme.syntaxKeyColor, "json: value string not tinted")
    expect(color(s, at: offset("42", in: s)) != EditorTheme.syntaxKeyColor, "json: number not tinted")
    expect(color(s, at: offset("true", in: s)) != EditorTheme.syntaxKeyColor, "json: boolean not tinted")
    expect(color(s, at: offset("count", in: s)) == EditorTheme.syntaxKeyColor, "json: second key tinted")
}

do {
    // A string value that itself contains a colon must not be seen as a key.
    let json = "{ \"url\": \"http://example.com\" }\n"
    let s = styled(json, .json)
    expect(color(s, at: offset("url", in: s)) == EditorTheme.syntaxKeyColor, "json: key before colon tinted")
    expect(color(s, at: offset("http", in: s)) != EditorTheme.syntaxKeyColor, "json: url value not tinted")
}

// MARK: - YAML

do {
    let yaml = "name: tilde\ncount: 42\n# a comment\nnested:\n  key: value\nlist:\n  - item\n"
    let s = styled(yaml, .yaml)
    expect(color(s, at: offset("name", in: s)) == EditorTheme.syntaxKeyColor, "yaml: top-level key tinted")
    expect(color(s, at: offset("tilde", in: s)) != EditorTheme.syntaxKeyColor, "yaml: value not tinted")
    expect(color(s, at: offset("key", in: s)) == EditorTheme.syntaxKeyColor, "yaml: nested key tinted")
    expect(color(s, at: offset("a comment", in: s)) == EditorTheme.syntaxCommentColor, "yaml: comment dimmed")
    expect(color(s, at: offset("# a comment", in: s)) == EditorTheme.syntaxCommentColor, "yaml: comment hash dimmed")
}

do {
    // Trailing comment after a value.
    let yaml = "port: 8080 # the server port\n"
    let s = styled(yaml, .yaml)
    expect(color(s, at: offset("port", in: s)) == EditorTheme.syntaxKeyColor, "yaml: key with trailing comment tinted")
    expect(color(s, at: offset("the server port", in: s)) == EditorTheme.syntaxCommentColor, "yaml: trailing comment dimmed")
    expect(color(s, at: offset("8080", in: s)) != EditorTheme.syntaxKeyColor, "yaml: value before comment not key")
}

// MARK: - TOML

do {
    let toml = "# a comment\nname = \"tilde\"\nversion = \"1.0.0\"\ncount = 42\n\n[settings]\nfontSize = 14  # points\n\n[[items]]\nid = 1\n"
    let s = styled(toml, .toml)
    expect(color(s, at: offset("name", in: s)) == EditorTheme.syntaxKeyColor, "toml: bare key tinted")
    expect(color(s, at: offset("tilde", in: s)) != EditorTheme.syntaxKeyColor, "toml: value not tinted")
    expect(color(s, at: offset("42", in: s)) != EditorTheme.syntaxKeyColor, "toml: number value not tinted")
    expect(color(s, at: offset("[settings]", in: s)) == EditorTheme.syntaxKeyColor, "toml: table header tinted")
    expect(color(s, at: offset("[[items]]", in: s)) == EditorTheme.syntaxKeyColor, "toml: array-of-tables header tinted")
    expect(color(s, at: offset("fontSize", in: s)) == EditorTheme.syntaxKeyColor, "toml: key inside table tinted")
    expect(color(s, at: offset("points", in: s)) == EditorTheme.syntaxCommentColor, "toml: trailing comment dimmed")
    expect(color(s, at: offset("a comment", in: s)) == EditorTheme.syntaxCommentColor, "toml: full-line comment dimmed")
}

// MARK: - Robustness

do {
    let s = styled("", .json)
    expect(s.length == 0, "empty json ok")
    let s2 = styled("not : really ] valid { yaml\n\n:::\n", .yaml)
    expect(s2.length > 0, "malformed yaml does not crash")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
