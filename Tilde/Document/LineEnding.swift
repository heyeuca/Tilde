//
//  LineEnding.swift
//  Tilde
//

import Foundation

/// Line-ending style of a document.
///
/// The in-memory buffer is always LF-normalized; the original style is
/// detected on load and restored on save.
enum LineEnding: String {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"

    /// Detects the dominant line ending and returns the string normalized to LF.
    static func normalizeToLF(_ string: String) -> (text: String, lineEnding: LineEnding) {
        var lf = 0, crlf = 0, cr = 0
        let scalars = string.unicodeScalars
        var index = scalars.startIndex
        while index < scalars.endIndex {
            switch scalars[index] {
            case "\r":
                let next = scalars.index(after: index)
                if next < scalars.endIndex, scalars[next] == "\n" {
                    crlf += 1
                    index = scalars.index(after: next)
                    continue
                }
                cr += 1
            case "\n":
                lf += 1
            default:
                break
            }
            index = scalars.index(after: index)
        }

        guard crlf > 0 || cr > 0 else { return (string, .lf) }

        let dominant: LineEnding
        if crlf >= lf && crlf >= cr {
            dominant = .crlf
        } else if cr > lf {
            dominant = .cr
        } else {
            dominant = .lf
        }

        let normalized = string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return (normalized, dominant)
    }

    /// Restores this line ending in an LF-normalized string for saving.
    func restore(in string: String) -> String {
        guard self != .lf else { return string }
        return string.replacingOccurrences(of: "\n", with: rawValue)
    }
}
