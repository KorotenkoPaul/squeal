import Foundation

/// The web `store`: every value is kept as JSON text under "squeal:<key>" (UserDefaults), so the rules are the same:
/// a saved value of the wrong kind counts as no value — the app never breaks on an old or broken save (BUGS #113).
final class Store {
    let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The raw saved value (JSON object, array, string, number, bool) or nil.
    func raw(_ key: String) -> Any? {
        guard let text = defaults.string(forKey: "squeal:" + key), let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    func set(_ key: String, _ value: Any?) {
        guard let value, let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let text = String(data: data, encoding: .utf8) else { defaults.removeObject(forKey: "squeal:" + key); return }
        defaults.set(text, forKey: "squeal:" + key)
    }

    func remove(_ key: String) { defaults.removeObject(forKey: "squeal:" + key) }

    // typed reads with the web's "wrong kind = default" rule
    func string(_ key: String, _ d: String) -> String { raw(key) as? String ?? d }
    func bool(_ key: String, _ d: Bool) -> Bool {
        guard let n = raw(key) as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return d }
        return n.boolValue
    }
    func number(_ key: String, _ d: Double) -> Double {
        guard let n = raw(key) as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return d }
        return n.doubleValue
    }
    func strings(_ key: String) -> [String] {
        guard let a = raw(key) as? [Any] else { return [] }
        return a.compactMap { $0 as? String }
    }

    // MARK: - the app's keys (same names as the web prototype)
    static let freeTaps = 100

    var favs: [String] { strings("favs") }
    func setFavs(_ f: [String]) { set("favs", f) }
    var lang: String? { raw("lang") as? String }
    var tab: String { string("tab", "home") }
    var premium: Bool { bool("premium", true) }      // prototype: the owner reads as a subscriber by default
    var taps: Int { Int(number("taps", Double(Self.freeTaps))) }
    func progressRaw(_ id: String) -> Any? { raw("p:" + id) }
}
