//
//  FileEncoding.swift
//  Tilde
//

import Foundation

/// A text encoding Tilde can read and write back unchanged.
///
/// Detection order on read: BOM → strict UTF-8 → UTF-16 heuristic → lossy UTF-8.
/// Whatever comes in goes back out: the original encoding (including the
/// presence or absence of a BOM) is preserved on save.
struct FileEncoding: Equatable {
    enum Base: Equatable {
        case utf8
        case utf16BigEndian
        case utf16LittleEndian
    }

    var base: Base
    var hasBOM: Bool

    /// Default for new documents: UTF-8, no BOM.
    static let `default` = FileEncoding(base: .utf8, hasBOM: false)

    // MARK: - Decoding

    static func decode(_ data: Data) -> (string: String, encoding: FileEncoding) {
        // 1. BOM
        if data.starts(with: [0xEF, 0xBB, 0xBF]),
           let string = String(data: data.dropFirst(3), encoding: .utf8) {
            return (string, FileEncoding(base: .utf8, hasBOM: true))
        }
        if data.starts(with: [0xFE, 0xFF]),
           let string = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
            return (string, FileEncoding(base: .utf16BigEndian, hasBOM: true))
        }
        if data.starts(with: [0xFF, 0xFE]),
           let string = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
            return (string, FileEncoding(base: .utf16LittleEndian, hasBOM: true))
        }

        // 2. UTF-16 without BOM: mostly-ASCII text has NULs in alternating
        // positions. This must run before the UTF-8 check — NUL bytes are
        // valid UTF-8, so UTF-16 data would otherwise pass as UTF-8.
        if data.count >= 2, data.count.isMultiple(of: 2) {
            let sample = data.prefix(512)
            var zerosAtEven = 0
            var zerosAtOdd = 0
            for (offset, byte) in sample.enumerated() where byte == 0 {
                if offset.isMultiple(of: 2) { zerosAtEven += 1 } else { zerosAtOdd += 1 }
            }
            let threshold = sample.count / 4
            if zerosAtEven > threshold,
               let string = String(data: data, encoding: .utf16BigEndian) {
                return (string, FileEncoding(base: .utf16BigEndian, hasBOM: false))
            }
            if zerosAtOdd > threshold,
               let string = String(data: data, encoding: .utf16LittleEndian) {
                return (string, FileEncoding(base: .utf16LittleEndian, hasBOM: false))
            }
        }

        // 3. Strict UTF-8
        if let string = String(data: data, encoding: .utf8) {
            return (string, FileEncoding(base: .utf8, hasBOM: false))
        }

        // 4. Last resort: lossy UTF-8. Never refuse to open a text file.
        return (String(decoding: data, as: UTF8.self), FileEncoding(base: .utf8, hasBOM: false))
    }

    // MARK: - Encoding

    func encode(_ string: String) -> Data {
        var data = Data()
        if hasBOM {
            switch base {
            case .utf8: data.append(contentsOf: [0xEF, 0xBB, 0xBF])
            case .utf16BigEndian: data.append(contentsOf: [0xFE, 0xFF])
            case .utf16LittleEndian: data.append(contentsOf: [0xFF, 0xFE])
            }
        }
        switch base {
        case .utf8:
            data.append(contentsOf: string.utf8)
        case .utf16BigEndian:
            data.append(string.data(using: .utf16BigEndian) ?? Data(string.utf8))
        case .utf16LittleEndian:
            data.append(string.data(using: .utf16LittleEndian) ?? Data(string.utf8))
        }
        return data
    }
}
