// Tests for Tilde's document layer: FileEncoding, LineEnding, and the
// document-type decision. Compiled as a plain executable by Tests/run.sh —
// no XCTest, so the suite runs on machines with only the Command Line Tools.

import Foundation

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition { passed += 1; print("  ok  \(name)") }
    else { failed += 1; print("FAIL  \(name)") }
}

// MARK: - FileEncoding

// UTF-8 roundtrip
do {
    let original = "Hello, 世界! 한글 テキスト\n"
    let data = Data(original.utf8)
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == original, "utf8 decode")
    expect(decoded.encoding == FileEncoding(base: .utf8, hasBOM: false), "utf8 detected without BOM")
    expect(decoded.encoding.encode(decoded.string) == data, "utf8 roundtrip is byte-identical")
    expect(!decoded.isLossy, "utf8 decode is not lossy")
}

// UTF-8 with BOM preserved
do {
    var data = Data([0xEF, 0xBB, 0xBF])
    data.append(Data("bom test".utf8))
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == "bom test", "utf8 BOM stripped from text")
    expect(decoded.encoding.hasBOM, "utf8 BOM detected")
    expect(decoded.encoding.encode(decoded.string) == data, "utf8 BOM roundtrip is byte-identical")
}

// UTF-16 LE with BOM
do {
    let original = "utf16 little endian ✓"
    var data = Data([0xFF, 0xFE])
    data.append(original.data(using: .utf16LittleEndian)!)
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == original, "utf16le decode")
    expect(decoded.encoding == FileEncoding(base: .utf16LittleEndian, hasBOM: true), "utf16le BOM detected")
    expect(decoded.encoding.encode(decoded.string) == data, "utf16le roundtrip is byte-identical")
}

// UTF-16 BE with BOM
do {
    let original = "utf16 big endian ✓"
    var data = Data([0xFE, 0xFF])
    data.append(original.data(using: .utf16BigEndian)!)
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == original, "utf16be decode")
    expect(decoded.encoding == FileEncoding(base: .utf16BigEndian, hasBOM: true), "utf16be BOM detected")
    expect(decoded.encoding.encode(decoded.string) == data, "utf16be roundtrip is byte-identical")
}

// UTF-16 LE without BOM: the NUL-alternation heuristic must catch it
// BEFORE the UTF-8 pass (NUL bytes are valid UTF-8 — the bug this suite
// originally caught).
do {
    let original = "plain ascii text for the heuristic to chew on"
    let data = original.data(using: .utf16LittleEndian)!
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == original, "utf16le no-BOM heuristic decode")
    expect(decoded.encoding == FileEncoding(base: .utf16LittleEndian, hasBOM: false), "utf16le no-BOM detected")
    expect(decoded.encoding.encode(decoded.string) == data, "utf16le no-BOM roundtrip adds no BOM")
}

// UTF-16 BE without BOM
do {
    let original = "big endian without a byte order mark"
    let data = original.data(using: .utf16BigEndian)!
    let decoded = FileEncoding.decode(data)
    expect(decoded.string == original, "utf16be no-BOM heuristic decode")
    expect(decoded.encoding == FileEncoding(base: .utf16BigEndian, hasBOM: false), "utf16be no-BOM detected")
}

// Invalid bytes never fail to open — but MUST be flagged lossy, because
// re-encoding the substituted text would corrupt the original file
// (2026-08 app review P1: the document layer blocks saving lossy documents).
do {
    let data = Data([0x48, 0x69, 0xFF, 0xFE, 0x00, 0xD8, 0x41])
    let decoded = FileEncoding.decode(data)
    expect(!decoded.string.isEmpty, "invalid bytes still decode (lossy)")
    expect(decoded.isLossy, "invalid bytes flagged lossy")
    expect(decoded.encoding.encode(decoded.string) != data,
           "lossy roundtrip is NOT byte-identical (why saving is blocked)")
}

// BOM-less UTF-16 Korean text: no NUL bytes for the alternation heuristic
// to catch, and the byte pairs are invalid UTF-8 — the decode falls to the
// lossy path and must say so instead of silently mangling the file.
do {
    let data = "안녕하세요세계".data(using: .utf16LittleEndian)!
    let decoded = FileEncoding.decode(data)
    expect(decoded.isLossy, "BOM-less utf16 Korean flagged lossy")
    expect(decoded.encoding.encode(decoded.string) != data,
           "BOM-less utf16 Korean cannot round-trip")
}

// Odd-length UTF-16 with BOM (file truncated mid-code-unit): Foundation's
// UTF-16 decoder silently DROPS the trailing byte instead of failing, so
// without the even-length guard this decoded as non-lossy and saving
// destroyed the final byte. Must be flagged lossy.
do {
    var le = Data([0xFF, 0xFE])
    le.append("Hello".data(using: .utf16LittleEndian)!)
    le.removeLast()   // truncate mid-code-unit
    let decodedLE = FileEncoding.decode(le)
    expect(decodedLE.isLossy, "odd-length BOM'd utf16le flagged lossy")

    var be = Data([0xFE, 0xFF])
    be.append("Hello".data(using: .utf16BigEndian)!)
    be.removeLast()
    let decodedBE = FileEncoding.decode(be)
    expect(decodedBE.isLossy, "odd-length BOM'd utf16be flagged lossy")
}

// A lone surrogate in BOM'd UTF-16 makes the strict decoder fail → lossy.
do {
    let data = Data([0xFF, 0xFE, 0x00, 0xD8, 0x41, 0x00])
    let decoded = FileEncoding.decode(data)
    expect(decoded.isLossy, "lone surrogate utf16 flagged lossy")
}

// Legacy encoding outside the detection list (EUC-KR "안녕하세요"):
// opens lossily, flagged so it can never be saved over the original.
do {
    let data = Data([0xBE, 0xC8, 0xB3, 0xE7, 0xC7, 0xCF, 0xBC, 0xBC, 0xBF, 0xE4])
    let decoded = FileEncoding.decode(data)
    expect(!decoded.string.isEmpty, "EUC-KR bytes still open")
    expect(decoded.isLossy, "EUC-KR flagged lossy")
}

// Every non-lossy detection path must round-trip byte-identically AND
// report not-lossy — the pair of guarantees the save path relies on.
do {
    var samples: [Data] = [
        Data("plain ascii\n".utf8),
        Data([0xEF, 0xBB, 0xBF]) + Data("bom utf8".utf8),
        Data([0xFF, 0xFE]) + "utf16le ✓".data(using: .utf16LittleEndian)!,
        Data([0xFE, 0xFF]) + "utf16be ✓".data(using: .utf16BigEndian)!,
        "ascii heuristic text".data(using: .utf16LittleEndian)!,
        "ascii heuristic text".data(using: .utf16BigEndian)!,
    ]
    samples.append(Data("emoji 🌊 and 한글\n".utf8))
    let allFaithful = samples.allSatisfy { data in
        let decoded = FileEncoding.decode(data)
        return !decoded.isLossy && decoded.encoding.encode(decoded.string) == data
    }
    expect(allFaithful, "all non-lossy paths round-trip byte-identically")
}

// Empty file
do {
    let decoded = FileEncoding.decode(Data())
    expect(decoded.string.isEmpty, "empty file decodes to empty string")
    expect(decoded.encoding == .default, "empty file gets default encoding")
    expect(!decoded.isLossy, "empty file is not lossy")
}

// MARK: - LineEnding

// LF stays untouched
do {
    let result = LineEnding.normalizeToLF("a\nb\nc\n")
    expect(result.text == "a\nb\nc\n", "lf text unchanged")
    expect(result.lineEnding == .lf, "lf detected")
}

// CRLF detected, normalized, restored
do {
    let original = "a\r\nb\r\nc\r\n"
    let result = LineEnding.normalizeToLF(original)
    expect(result.text == "a\nb\nc\n", "crlf normalized to lf")
    expect(result.lineEnding == .crlf, "crlf detected")
    expect(result.lineEnding.restore(in: result.text) == original, "crlf restored byte-identical")
}

// Classic Mac CR
do {
    let original = "a\rb\rc"
    let result = LineEnding.normalizeToLF(original)
    expect(result.text == "a\nb\nc", "cr normalized to lf")
    expect(result.lineEnding == .cr, "cr detected")
    expect(result.lineEnding.restore(in: result.text) == original, "cr restored byte-identical")
}

// Mixed: dominant wins
do {
    let result = LineEnding.normalizeToLF("a\r\nb\r\nc\r\nd\ne\r\n")
    expect(result.lineEnding == .crlf, "dominant crlf wins in mixed file")
    expect(result.text == "a\nb\nc\nd\ne\n", "mixed file fully normalized")
}

// No line endings at all
do {
    let result = LineEnding.normalizeToLF("single line")
    expect(result.text == "single line", "single line unchanged")
    expect(result.lineEnding == .lf, "no EOL defaults to lf")
}

// Empty string
do {
    let result = LineEnding.normalizeToLF("")
    expect(result.text == "" && result.lineEnding == .lf, "empty string defaults")
}

// MARK: - Markdown-ness follows the live extension (2026-08 app review P2)

// A document opened as Markdown then saved as .txt/.json must LEAVE
// Markdown mode, and the reverse switch must work too; the open-time type
// only decides for extension-less files and untitled documents.
do {
    let md = URL(fileURLWithPath: "/tmp/a.md")
    let txt = URL(fileURLWithPath: "/tmp/a.txt")
    let json = URL(fileURLWithPath: "/tmp/a.json")
    let bare = URL(fileURLWithPath: "/tmp/README")
    expect(TextDocument.isMarkdown(openedAsMarkdown: true, fileURL: txt) == false,
           "markdown saved as .txt leaves markdown mode")
    expect(TextDocument.isMarkdown(openedAsMarkdown: true, fileURL: json) == false,
           "markdown saved as .json leaves markdown mode")
    expect(TextDocument.isMarkdown(openedAsMarkdown: false, fileURL: md) == true,
           "text saved as .md enters markdown mode")
    expect(TextDocument.isMarkdown(openedAsMarkdown: true, fileURL: bare) == true,
           "extension-less file keeps its opened type")
    expect(TextDocument.isMarkdown(openedAsMarkdown: false, fileURL: bare) == false,
           "extension-less plain file stays plain")
    expect(TextDocument.isMarkdown(openedAsMarkdown: false, fileURL: nil) == false,
           "untitled document defaults to plain")
    expect(TextDocument.isMarkdown(openedAsMarkdown: true,
                                   fileURL: URL(fileURLWithPath: "/tmp/b.MARKDOWN")) == true,
           "markdown extension match is case-insensitive")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
