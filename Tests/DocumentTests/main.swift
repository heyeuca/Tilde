// Tests for Tilde's document layer: FileEncoding and LineEnding.
// Compiled as a plain executable by Tests/run.sh — no XCTest, so the suite
// runs on machines with only the Command Line Tools.

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

// Invalid bytes never fail to open
do {
    let data = Data([0x48, 0x69, 0xFF, 0xFE, 0x00, 0xD8, 0x41])
    let decoded = FileEncoding.decode(data)
    expect(!decoded.string.isEmpty, "invalid bytes still decode (lossy)")
}

// Empty file
do {
    let decoded = FileEncoding.decode(Data())
    expect(decoded.string.isEmpty, "empty file decodes to empty string")
    expect(decoded.encoding == .default, "empty file gets default encoding")
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

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
