import Foundation

/// Search (template.html norm / oneEditAway / matchScore / searchStories) and the fear filter.
/// Search forgives one typo, never more: a title matches if it contains what you typed, or a piece of it that is one
/// letter off (one wrong, missing, extra, or two swapped letters). Short queries (under 4 letters) must match exactly.
/// Exact matches come first. Any alphabet; accents do not matter (é = e, ü = u, ё = е); ß = ss.
enum Search {
    private static let junk = try! NSRegularExpression(pattern: "[^\\p{L}\\p{N} ]+")
    private static let spaces = try! NSRegularExpression(pattern: "\\s+")

    static func norm(_ text: String) -> String {
        var t = text.lowercased().replacingOccurrences(of: "ß", with: "ss").decomposedStringWithCanonicalMapping
        t = String(String.UnicodeScalarView(t.unicodeScalars.filter { !(0x0300...0x036f).contains($0.value) }))
        for q in ["’", "'", "`"] { t = t.replacingOccurrences(of: q, with: "") }
        t = junk.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
        t = spaces.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Damerau-Levenshtein distance <= 1
    static func oneEditAway(_ a: [UInt16], _ b: [UInt16]) -> Bool {
        if a == b { return true }
        let la = a.count, lb = b.count
        if abs(la - lb) > 1 { return false }
        if la == lb {
            let d = (0..<la).filter { a[$0] != b[$0] }
            return d.count == 1 || (d.count == 2 && d[1] == d[0] + 1 && a[d[0]] == b[d[1]] && a[d[1]] == b[d[0]])
        }
        let (s1, s2) = la < lb ? (a, b) : (b, a)          // one letter extra in s2
        var i = 0
        while i < s1.count && s1[i] == s2[i] { i += 1 }
        return Array(s1[i...]) == Array(s2[(i + 1)...])
    }

    /// 2: the title contains the query; 1: one typo away; 0: no match
    static func matchScore(_ title: String, _ q: String) -> Int {
        let t = Array(norm(title).utf16), w = Array(norm(q).utf16)
        if w.isEmpty { return 0 }
        if contains(t, w) { return 2 }
        if w.count < 4 { return 0 }                       // from 3 letters, "cat" or "red" found a third of all stories
        for len in (w.count - 1)...(w.count + 1) {
            var i = 0
            while i + len <= t.count {
                if oneEditAway(Array(t[i..<(i + len)]), w) { return 1 }
                i += 1
            }
        }
        return 0
    }

    private static func contains(_ t: [UInt16], _ w: [UInt16]) -> Bool {
        guard w.count <= t.count else { return false }
        for i in 0...(t.count - w.count) where Array(t[i..<(i + w.count)]) == w { return true }
        return false
    }

    /// the title in the reader's language, and the original English one too; exact matches first, else the stories' own order
    static func stories(_ list: [Story], english: [Story], _ q: String) -> [Story] {
        let en = Dictionary(english.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
        let scored: [(Story, Int)] = list.map { s in
            let other = en[s.id].flatMap { $0 != s.title ? matchScore($0, q) : nil } ?? 0
            return (s, max(matchScore(s.title, q), other))
        }
        return scored.filter { $0.1 > 0 }.enumerated().sorted { a, b in
            a.element.1 != b.element.1 ? a.element.1 > b.element.1 : a.offset < b.offset
        }.map { $0.element.0 }
    }
}

/// How scary a story is, 1 to 5: internal, set per story ("fear"), used only by the fear row in Search, never shown as
/// a label. One row of the five level names; the name that stops in the middle is the filter.
enum Fear {
    /// the old dial's arc, violet-blue to red, read at each level
    static let colours: [UInt32] = [0x7b57c9, 0x8c5baf, 0x9d5f94, 0xa95a78, 0xb5525b]
    static let nameWidth = 132.0, rowHeight = 50.0

    static func stories(_ list: [Story], level: Int) -> [Story] { list.filter { $0.fear == level } }

    /// paint(): each name grows and brightens as it nears the middle. `scroll`: how far the row is scrolled;
    /// level k (0-based) stands in the exact middle at scroll = k * nameWidth.
    static func paint(scroll: Double) -> (scale: [Double], opacity: [Double], near: Int) {
        var best = 0, bestD = Double.infinity
        var s: [Double] = [], o: [Double] = []
        for i in 0..<5 {
            let d = abs(Double(i) * nameWidth - scroll) / nameWidth, k = min(d, 1)
            s.append(1 - 0.34 * k); o.append(1 - 0.45 * k)
            if d < bestD { bestD = d; best = i }
        }
        return (s, o, best + 1)
    }
}
