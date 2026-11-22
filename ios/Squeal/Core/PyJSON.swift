import Foundation
import CryptoKit

/// Python's `json.dumps(x, ensure_ascii=False, sort_keys=True)` for values read with JSONSerialization.
/// web/build.py fingerprints a story's text with it (the story "version" `v`), so the app must produce the
/// very same bytes to get the same version: separators ", " and ": ", keys sorted by code point, only
/// `"`, `\`, and control characters escaped.
enum PyJSON {
    static func dumps(_ x: Any?) -> String {
        var out = ""
        write(x, into: &out)
        return out
    }

    private static func write(_ x: Any?, into out: inout String) {
        switch x {
        case nil, is NSNull:
            out += "null"
        case let s as String:
            writeString(s, into: &out)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                out += n.boolValue ? "true" : "false"
            } else if CFNumberIsFloatType(n as CFNumber) {
                let d = n.doubleValue
                out += d == d.rounded() && abs(d) < 1e16 ? String(format: "%.1f", d) : "\(d)"
            } else {
                out += n.stringValue
            }
        case let a as [Any]:
            out += "["
            for (i, v) in a.enumerated() {
                if i > 0 { out += ", " }
                write(v, into: &out)
            }
            out += "]"
        case let d as [String: Any]:
            out += "{"
            let keys = d.keys.sorted { Array($0.unicodeScalars.map(\.value)).lexicographicallyPrecedes($1.unicodeScalars.map(\.value)) }
            for (i, k) in keys.enumerated() {
                if i > 0 { out += ", " }
                writeString(k, into: &out)
                out += ": "
                write(d[k], into: &out)
            }
            out += "}"
        default:
            out += "null"
        }
    }

    private static func writeString(_ s: String, into out: inout String) {
        out += "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        out += "\""
    }

    /// First 10 hex digits of SHA-1 of the UTF-8 text (build.py: `hashlib.sha1(body.encode()).hexdigest()[:10]`).
    static func sha1Prefix(_ text: String, _ n: Int = 10) -> String {
        let digest = Insecure.SHA1.hash(data: Data(text.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(n))
    }
}
