//
//  CodeHighlighter.swift
//  Tilde
//

import AppKit

/// A tiny, zero-dependency, generic lexical highlighter for fenced code
/// blocks in the Markdown preview.
///
/// It is deliberately not a full language parser (no `highlight.js`, no
/// tree-sitter). Like CotEditor's regex-rule model but lighter, it colors
/// the four token kinds every language shares — comments, strings, numbers,
/// and (for known languages) keywords — via a single left-to-right scan.
/// Anything it doesn't recognize simply stays default-colored.
struct CodeHighlighter {
    struct Span {
        let range: NSRange
        let color: NSColor
    }

    /// Per-language lexing rules. Unknown languages fall back to a C-like
    /// default (which still gets strings/comments/numbers, just no keywords).
    struct Syntax {
        var lineComments: [String] = ["//"]
        var blockComments: [(open: String, close: String)] = [("/*", "*/")]
        /// String delimiter characters (each a single UTF-16 unit).
        var stringDelims: Set<unichar> = [0x22, 0x27, 0x60]   // " ' `
        var tripleStrings: [String] = []
        var keywords: Set<String> = []
        var caseInsensitiveKeywords = false
    }

    func spans(for code: String, language: String?) -> [Span] {
        let syntax = Self.syntax(for: language)
        let s = code as NSString
        let n = s.length
        guard n > 0 else { return [] }
        var spans: [Span] = []
        var i = 0

        func char(_ idx: Int) -> unichar { s.character(at: idx) }
        func matches(_ token: String, at idx: Int) -> Bool {
            let t = token as NSString
            guard t.length > 0, idx + t.length <= n else { return false }
            return s.substring(with: NSRange(location: idx, length: t.length)) == token
        }
        func isDigit(_ c: unichar) -> Bool { c >= 0x30 && c <= 0x39 }
        func isHex(_ c: unichar) -> Bool {
            isDigit(c) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66)
        }
        func isIdentStart(_ c: unichar) -> Bool {
            (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F || c == 0x24
        }
        func isIdent(_ c: unichar) -> Bool { isIdentStart(c) || isDigit(c) }

        scan: while i < n {
            let c = char(i)

            // Block comments.
            for block in syntax.blockComments where matches(block.open, at: i) {
                var j = i + (block.open as NSString).length
                while j < n && !matches(block.close, at: j) { j += 1 }
                let end = j < n ? j + (block.close as NSString).length : n
                spans.append(Span(range: NSRange(location: i, length: end - i), color: EditorTheme.codeCommentColor))
                i = end
                continue scan
            }

            // Line comments.
            for delim in syntax.lineComments where matches(delim, at: i) {
                var j = i
                while j < n && char(j) != 0x0A { j += 1 }
                spans.append(Span(range: NSRange(location: i, length: j - i), color: EditorTheme.codeCommentColor))
                i = j
                continue scan
            }

            // Triple-quoted (multi-line) strings.
            for triple in syntax.tripleStrings where matches(triple, at: i) {
                let len = (triple as NSString).length
                var j = i + len
                while j < n && !matches(triple, at: j) { j += 1 }
                let end = j < n ? j + len : n
                spans.append(Span(range: NSRange(location: i, length: end - i), color: EditorTheme.codeStringColor))
                i = end
                continue scan
            }

            // Single-delimiter strings (with backslash escapes). A normal
            // quote ends at the line break; a backtick may span lines.
            if syntax.stringDelims.contains(c) {
                let quote = c
                var j = i + 1
                while j < n {
                    let d = char(j)
                    if d == 0x5C { j += 2; continue }          // backslash escape
                    if d == quote { j += 1; break }
                    if d == 0x0A && quote != 0x60 { break }     // unterminated normal string
                    j += 1
                }
                let end = min(j, n)
                spans.append(Span(range: NSRange(location: i, length: end - i), color: EditorTheme.codeStringColor))
                i = end
                continue scan
            }

            // Numbers (not immediately after an identifier char).
            if isDigit(c), i == 0 || !isIdent(char(i - 1)) {
                var j = i
                if c == 0x30, j + 1 < n, char(j + 1) == 0x78 || char(j + 1) == 0x58 {   // 0x…
                    j += 2
                    while j < n && (isHex(char(j)) || char(j) == 0x5F) { j += 1 }
                } else {
                    while j < n && (isDigit(char(j)) || char(j) == 0x2E || char(j) == 0x5F) { j += 1 }
                    if j < n, char(j) == 0x65 || char(j) == 0x45 {   // exponent
                        j += 1
                        if j < n, char(j) == 0x2B || char(j) == 0x2D { j += 1 }
                        while j < n && isDigit(char(j)) { j += 1 }
                    }
                }
                spans.append(Span(range: NSRange(location: i, length: j - i), color: EditorTheme.codeNumberColor))
                i = j
                continue scan
            }

            // Identifiers → keyword if known.
            if isIdentStart(c) {
                var j = i + 1
                while j < n && isIdent(char(j)) { j += 1 }
                if !syntax.keywords.isEmpty {
                    var word = s.substring(with: NSRange(location: i, length: j - i))
                    if syntax.caseInsensitiveKeywords { word = word.lowercased() }
                    if syntax.keywords.contains(word) {
                        spans.append(Span(range: NSRange(location: i, length: j - i), color: EditorTheme.codeKeywordColor))
                    }
                }
                i = j
                continue scan
            }

            i += 1
        }
        return spans
    }

    // MARK: - Language table

    private static func syntax(for language: String?) -> Syntax {
        guard let language = language?.lowercased(), !language.isEmpty else { return cLike }
        return table[language] ?? cLike
    }

    private static let cLike = Syntax()

    private static func kw(_ list: String) -> Set<String> {
        Set(list.split(separator: " ").map(String.init))
    }

    private static let hashLine = ["#"]

    private static let table: [String: Syntax] = {
        var t: [String: Syntax] = [:]

        let swift = Syntax(
            stringDelims: [0x22],
            tripleStrings: ["\"\"\""],
            keywords: kw("func let var if else guard for while repeat return switch case default break continue struct class enum protocol extension import init deinit self super nil true false throw throws try catch async await actor where as is in do defer public private internal fileprivate open final static lazy weak unowned mutating override some any associatedtype typealias")
        )
        for k in ["swift"] { t[k] = swift }

        let js = Syntax(
            keywords: kw("function let const var if else for while do return switch case default break continue class extends new this super import export from as async await try catch finally throw typeof instanceof in of null undefined true false void delete yield get set static")
        )
        for k in ["javascript", "js", "typescript", "ts", "jsx", "tsx"] { t[k] = js }

        let python = Syntax(
            lineComments: hashLine,
            blockComments: [],
            stringDelims: [0x22, 0x27],
            tripleStrings: ["\"\"\"", "'''"],
            keywords: kw("def class if elif else for while return import from as try except finally raise with lambda yield global nonlocal pass break continue in is not and or None True False async await del assert")
        )
        for k in ["python", "py"] { t[k] = python }

        let ruby = Syntax(
            lineComments: hashLine, blockComments: [], stringDelims: [0x22, 0x27],
            keywords: kw("def class module if elsif else unless while until for do return yield begin rescue ensure raise end then case when nil true false and or not self super require require_relative attr_accessor attr_reader attr_writer")
        )
        for k in ["ruby", "rb"] { t[k] = ruby }

        let shell = Syntax(
            lineComments: hashLine, blockComments: [], stringDelims: [0x22, 0x27, 0x60],
            keywords: kw("if then else elif fi for while do done case esac in function return export local echo cd exit set unset source")
        )
        for k in ["bash", "sh", "shell", "zsh"] { t[k] = shell }

        let go = Syntax(
            stringDelims: [0x22, 0x60],
            keywords: kw("func var const type struct interface map chan package import if else for range return switch case default break continue go defer select fallthrough nil true false iota make new")
        )
        for k in ["go", "golang"] { t[k] = go }

        let rust = Syntax(
            stringDelims: [0x22],
            keywords: kw("fn let mut const struct enum trait impl if else for while loop match return use mod pub crate self super where as in ref move async await dyn unsafe true false Some None Ok Err")
        )
        for k in ["rust", "rs"] { t[k] = rust }

        let java = Syntax(
            keywords: kw("class interface enum extends implements public private protected static final abstract void int long double float boolean char byte short if else for while do return switch case default break continue new this super import package try catch finally throw throws null true false instanceof synchronized volatile transient")
        )
        for k in ["java", "kotlin", "kt", "scala"] { t[k] = java }

        let cfamily = Syntax(
            keywords: kw("int long double float char void short unsigned signed const static struct union enum typedef if else for while do return switch case default break continue sizeof goto extern volatile register inline class public private protected virtual template namespace using new delete this true false nullptr")
        )
        for k in ["c", "cpp", "c++", "objectivec", "objective-c", "objc", "cs", "csharp", "c#"] { t[k] = cfamily }

        let json = Syntax(lineComments: [], blockComments: [], stringDelims: [0x22], keywords: kw("true false null"))
        for k in ["json"] { t[k] = json }

        let sql = Syntax(
            lineComments: ["--"], stringDelims: [0x27],
            keywords: kw("select from where insert update delete into values create table alter drop index view join inner left right outer on group by order having limit offset union all as distinct and or not null is in like between count sum avg min max primary key foreign references default"),
            caseInsensitiveKeywords: true
        )
        t["sql"] = sql

        let css = Syntax(lineComments: [], stringDelims: [0x22, 0x27])
        for k in ["css", "scss", "less"] { t[k] = css }

        let markup = Syntax(lineComments: [], blockComments: [("<!--", "-->")], stringDelims: [0x22, 0x27])
        for k in ["html", "xml", "svg"] { t[k] = markup }

        let hashConfig = Syntax(lineComments: hashLine, blockComments: [], stringDelims: [0x22, 0x27], keywords: kw("true false null yes no"))
        for k in ["yaml", "yml", "toml", "ini"] { t[k] = hashConfig }

        return t
    }()
}
