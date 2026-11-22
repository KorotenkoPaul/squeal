import Foundation

/// "Top this week": every opening of a story's chat counts one read; the count starts again each (ISO) week.
/// The slider shows featured stories first, then the most read; ties by rating, then by the English title,
/// so the same five show in every language (BUGS #156).
enum TopWeek {
    /// rating = 4.2 + (sum of the id's char codes % 8) / 10, one decimal
    static func rating(_ id: String) -> Double {
        let sum = id.utf16.reduce(0) { $0 + Int($1) }
        return ((4.2 + Double(sum % 8) / 10) * 10).rounded() / 10
    }

    /// ISO week key, e.g. "2026-W47" (template.html weekKey)
    static func weekKey(_ d: Date = Date(), calendar: Calendar = .current) -> String {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let c = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return String(format: "%d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    /// this week's counts from the saved {week, n:{id: count}} (anything else: an empty new week)
    static func counts(_ raw: Any?, week: String) -> [String: Int] {
        guard let r = raw as? [String: Any], r["week"] as? String == week, let n = r["n"] as? [String: Any] else { return [:] }
        return n.compactMapValues { ($0 as? NSNumber)?.intValue }
    }

    static func countRead(_ id: String, store: Store, now: Date = Date()) {
        let week = weekKey(now)
        var n = counts(store.raw("reads"), week: week)
        n[id, default: 0] += 1
        store.set("reads", ["week": week, "n": n])
    }

    /// the five stories of the slider
    static func top(_ stories: [Story], english: [Story], counts n: [String: Int]) -> [Story] {
        let enTitle = Dictionary(english.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
        let sorted = stories.sorted { a, b in
            let ca = n[a.id] ?? 0, cb = n[b.id] ?? 0
            if ca != cb { return ca > cb }
            let ra = rating(a.id), rb = rating(b.id)
            if ra != rb { return ra > rb }
            let ta = enTitle[a.id] ?? a.title, tb = enTitle[b.id] ?? b.title
            return ta.compare(tb, options: [.caseInsensitive], locale: Locale(identifier: "en")) == .orderedAscending
        }
        let pinned = stories.filter(\.featured)
        return Array((pinned + sorted.filter { !$0.featured }).prefix(5))
    }
}
