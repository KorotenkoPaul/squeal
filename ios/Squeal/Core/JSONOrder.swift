import Foundation

/// The keys of one object inside a JSON text, in the order they are written there.
enum JSONOrder {
    /// `path`: the way down from the root — a String for an object's key, an Int for a place in an array.
    /// Anything unexpected on the way gives an empty list.
    static func keys(_ data: Data, at path: [Any]) -> [String] {
        var s = Walker(b: [UInt8](data))
        for step in path {
            if let key = step as? String {
                guard s.intoObject(key) else { return [] }
            } else if let index = step as? Int {
                guard s.intoArray(index) else { return [] }
            } else { return [] }
        }
        return s.objectKeys()
    }

    private struct Walker {
        let b: [UInt8]
        var i = 0

        mutating func ws() { while i < b.count, b[i] == 0x20 || b[i] == 0x0a || b[i] == 0x0d || b[i] == 0x09 { i += 1 } }

        /// at a `"`: reads the string and steps past it
        mutating func string() -> String? {
            guard i < b.count, b[i] == 0x22 else { return nil }
            let from = i
            i += 1
            while i < b.count, b[i] != 0x22 { i += b[i] == 0x5c ? 2 : 1 }
            guard i < b.count else { return nil }
            i += 1
            return (try? JSONSerialization.jsonObject(with: Data(b[from..<i]), options: [.fragmentsAllowed])) as? String
        }

        mutating func skipValue() {
            ws()
            guard i < b.count else { return }
            switch b[i] {
            case 0x22: _ = string()
            case 0x7b:                                   // {
                i += 1; ws()
                if i < b.count, b[i] == 0x7d { i += 1; return }
                while i < b.count {
                    ws(); _ = string(); ws()
                    if i < b.count, b[i] == 0x3a { i += 1 }
                    skipValue(); ws()
                    if i < b.count, b[i] == 0x2c { i += 1; continue }
                    if i < b.count, b[i] == 0x7d { i += 1 }
                    return
                }
            case 0x5b:                                   // [
                i += 1; ws()
                if i < b.count, b[i] == 0x5d { i += 1; return }
                while i < b.count {
                    skipValue(); ws()
                    if i < b.count, b[i] == 0x2c { i += 1; continue }
                    if i < b.count, b[i] == 0x5d { i += 1 }
                    return
                }
            default:
                while i < b.count, b[i] != 0x2c, b[i] != 0x5d, b[i] != 0x7d { i += 1 }
            }
        }

        /// at an object: stops at the value of `key`
        mutating func intoObject(_ key: String) -> Bool {
            ws()
            guard i < b.count, b[i] == 0x7b else { return false }
            i += 1
            while i < b.count {
                ws()
                guard let k = string() else { return false }
                ws()
                guard i < b.count, b[i] == 0x3a else { return false }
                i += 1
                if k == key { ws(); return true }
                skipValue(); ws()
                guard i < b.count, b[i] == 0x2c else { return false }
                i += 1
            }
            return false
        }

        /// at an array: stops at its element number `index`
        mutating func intoArray(_ index: Int) -> Bool {
            ws()
            guard i < b.count, b[i] == 0x5b else { return false }
            i += 1
            var n = 0
            while i < b.count {
                ws()
                if i < b.count, b[i] == 0x5d { return false }
                if n == index { return true }
                skipValue(); ws()
                guard i < b.count, b[i] == 0x2c else { return false }
                i += 1; n += 1
            }
            return false
        }

        mutating func objectKeys() -> [String] {
            ws()
            guard i < b.count, b[i] == 0x7b else { return [] }
            i += 1
            var out: [String] = []
            while i < b.count {
                ws()
                guard let k = string() else { return out }
                out.append(k); ws()
                guard i < b.count, b[i] == 0x3a else { return out }
                i += 1
                skipValue(); ws()
                guard i < b.count, b[i] == 0x2c else { return out }
                i += 1
            }
            return out
        }
    }
}
