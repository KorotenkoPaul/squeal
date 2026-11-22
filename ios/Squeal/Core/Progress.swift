import Foundation

/// Reading progress of one story: every part keeps its own place (template.html prog()).
struct Progress: Equatable {
    var ep: Int                 // the part being read
    var pos: [Int]              // messages read per part
    var path: [String]? = nil   // interactive: the nodes passed

    /// What is saved: { ep, pos, path?, v } (setProg)
    func saved(v: String) -> [String: Any] {
        var d: [String: Any] = ["ep": ep, "pos": pos, "v": v]
        if let path { d["path"] = path }
        return d
    }
}

enum Reading {
    /// Three messages or fewer is no progress (owner, 2026-11-14): only the part open in the chat keeps its count.
    static let stub = 3
    /// seconds to read one message (owner, 2026-11-09)
    static let readSec = 3.0

    /// JavaScript's unary `+x` for the values a JSON save can hold (NaN where JS gives NaN).
    static func jsNumber(_ x: Any?) -> Double {
        switch x {
        case nil, is NSNull: return x == nil ? .nan : 0
        case let n as NSNumber: return n.doubleValue
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return 0 }
            return Double(t) ?? .nan
        case let a as [Any]:
            if a.isEmpty { return 0 }
            guard a.count == 1 else { return .nan }
            switch a[0] {
            case is NSNull: return 0
            case let n as NSNumber: return CFGetTypeID(n) == CFBooleanGetTypeID() ? .nan : n.doubleValue
            case is String, is [Any]: return jsNumber(a[0])
            default: return .nan
            }
        default: return .nan
        }
    }
    /// `Math.floor(+x) || 0`
    static func floorOr0(_ x: Any?) -> Double { let f = jsNumber(x).rounded(.down); return f.isNaN || f == 0 ? 0 : f }
    /// `x || 0` for a number-ish value
    private static func or0(_ x: Any?) -> Any? {
        switch x {
        case nil, is NSNull: return 0
        case let n as NSNumber: return n.doubleValue == 0 || n.doubleValue.isNaN ? 0 : n
        case let s as String: return s.isEmpty ? 0 : s
        default: return x
        }
    }

    /// template.html prog(): the saved progress, made safe and current.
    /// - `liveEp`: the part open in the chat right now (it keeps a count of 3 or fewer), or nil.
    static func prog(_ s: Story, raw: Any?, liveEp: Int? = nil) -> Progress {
        let n = s.parts.count
        let len = { (k: Int) in s.parts[k].messages.count }
        var p = raw as? [String: Any] ?? ["ep": 0, "pos": [Any]()]
        if let pv = p["v"], truthy(pv), !s.v.isEmpty, (pv as? String) != s.v { p = ["ep": 0, "pos": [Any]()] }
        var posRaw: [Any?]
        if let a = p["pos"] as? [Any] {
            posRaw = a.map { Optional($0) }
        } else {
            // old save { ep, i }: parts before ep count as read
            let epRaw = jsNumber(p["ep"])                       // `k < p.ep` compares with the raw value
            let epIsNumber = (p["ep"] as? NSNumber).map { CFGetTypeID($0) != CFBooleanGetTypeID() } ?? false
            p["ep"] = min(jsNumber(or0(p["ep"])), Double(n - 1))
            let i = or0(p["i"])
            posRaw = (0..<n).map { k -> Any? in
                if Double(k) < epRaw { return len(k) }
                if epIsNumber && Double(k) == epRaw { return i }
                return 0
            }
        }
        var pos = (0..<n).map { k -> Int in
            let x = k < posRaw.count ? floorOr0(posRaw[k]) : 0
            return Int(max(0, min(Double(len(k)), x)))
        }
        let ep = Int(max(0, min(Double(n - 1), floorOr0(p["ep"]))))
        let live = liveEp ?? -1
        pos = pos.enumerated().map { k, x in k != live && x <= stub && x < len(k) ? 0 : x }
        var out = Progress(ep: ep, pos: pos)
        if let path = p["path"] as? [Any] { out.path = path.compactMap { $0 as? String } }
        return out
    }

    private static func truthy(_ x: Any) -> Bool {
        switch x {
        case is NSNull: return false
        case let n as NSNumber: return n.doubleValue != 0 && !n.doubleValue.isNaN
        case let s as String: return !s.isEmpty
        default: return true
        }
    }

    static func partPct(_ s: Story, _ p: Progress, _ k: Int) -> Double {
        let m = s.parts[k].messages.count
        return m == 0 ? 1 : Double(p.pos[k]) / Double(m)
    }

    /// The part to carry on with: the current one or the next unfinished after it; else an unfinished one before it;
    /// all read: the part last read (2026-11-11).
    static func nextPart(_ s: Story, _ p: Progress) -> Int {
        let n = s.parts.count
        let open = { (k: Int) in partPct(s, p, k) < 1 }
        for k in p.ep..<n where open(k) { return k }
        for k in 0..<p.ep where open(k) { return k }
        return p.ep
    }

    /// Whole-story progress in percent: 100 only when every message is read, never 0 once one is.
    static func percent(_ s: Story, _ p: Progress) -> Int {
        let n = p.pos.reduce(0, +), t = s.totalMessages
        if n >= t { return 100 }
        if n == 0 { return 0 }
        let r = Double(n) * 100 / Double(t)
        return max(1, min(99, Int(jsRound(r))))
    }

    /// JavaScript Math.round (halves go up)
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    // MARK: - reading time (IDEAS.md: waiting + READ_SEC per message, rounded to minutes, at least 1)

    /// ms the other side takes before a message appears (the chat's own delays)
    static func msgWait(_ m: Message) -> Double {
        if m.voice != nil || m.video != nil { return Double(m.dur ?? 3) * 1000 + 1100 }
        return min(1800, 450 + Double(m.text.utf16.count) * 22)
    }

    /// every message a part holds: interactive — all branches, all endings and every answer
    static func partAll(_ e: Part) -> [Message] {
        guard let nodes = e.nodes else { return e.messages }
        return nodes.keys.sorted().flatMap { key -> [Message] in
            let n = nodes[key]!
            return n.messages + (n.choices ?? []).map { Message(from: e.right, text: $0.text, voice: nil, video: nil, dur: nil) }
        }
    }

    static func partSec(_ e: Part) -> Double {
        partAll(e).reduce(0.0) { t, m in t + readSec + (m.from == e.right ? 0 : msgWait(m) / 1000) }
    }

    static func storySec(_ s: Story) -> Double { s.parts.reduce(0.0) { $0 + partSec($1) } }
    static func minutes(_ sec: Double) -> Int { max(1, Int(jsRound(sec / 60))) }
    static func storyMinutes(_ s: Story) -> Int { minutes(storySec(s)) }
}
