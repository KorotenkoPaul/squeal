import SwiftUI

/// The chat wallpaper's drawings and where they go (template.html DOODLE, wallItems, wallLay). Each part lists the
/// small objects drawn behind its chat; the layout is fixed for each part (seeded by the story and part), so it is
/// the same every time it opens — and the same as in the web prototype.
enum Doodles {
    static let tile: CGFloat = 280                       // WALL_T

    /// A part's wallpaper: the whole story's doodles, and (interactive) each ending's own.
    struct Config: Equatable {
        var common: [String]
        var endings: [Group]? = nil                      // in the file's order
        struct Group: Equatable { let g: String; let names: [String] }

        /// wallGroups(): "*" = the whole story
        var groups: [Group] {
            guard let endings else { return [Group(g: "*", names: common)] }
            return [Group(g: "*", names: common)] + endings
        }
    }

    static func config(_ part: Part) -> Config {
        guard let we = part.wallpaperEndings else { return Config(common: part.wallpaper) }
        let order = part.endingsOrder.count == we.count ? part.endingsOrder : we.keys.sorted()
        return Config(common: part.wallpaper, endings: order.map { Config.Group(g: $0, names: we[$0] ?? []) })
    }

    /// One doodle of the 280 pt tile: name, size, place, turn (degrees), and the group it belongs to.
    struct Item: Equatable {
        let name: String
        let s, px, py, rot: Double
        let g: String
    }

    static func items(_ cfg: Config, seed: String) -> [Item] {
        let groups = cfg.groups.filter { !$0.names.isEmpty }
        if groups.isEmpty { return [] }
        var x: UInt32 = 7
        for c in seed.utf16 { x = x &* 31 &+ UInt32(c) }
        func rnd() -> Double { x = x &* 1664525 &+ 1013904223; return Double(x) / 4294967296 }
        let E = groups.count - (groups[0].g == "*" ? 1 : 0)
        let N = max(5, Int(ceil(sqrt(Double(E + 2)))))
        let NN = N * N
        let C = Double(tile) / Double(N)
        // which group each of the N×N places belongs to
        var label: [Int]? = nil
        if groups.count > 1 {
            var each = groups.filter { $0.g != "*" }.map { _ in max(1, Int(Reading.jsRound(Double(NN) / Double(E + 2)))) }
            var common = NN - each.reduce(0, +)
            while common < 1, let top = each.max(), let k = each.firstIndex(of: top) { each[k] -= 1; common += 1 }
            var rest = each.makeIterator()
            let counts = groups.map { $0.g == "*" ? common : (rest.next() ?? 0) }
            // spread: every group's members evenly along a sequence, then laid on the tile in a scattered order
            var seq: [(gi: Int, at: Double, n: Int)] = []
            for (gi, _) in groups.enumerated() {
                let count = counts[gi]
                for j in 0..<max(0, count) {
                    seq.append((gi: gi, at: (Double(j) + 0.5) / Double(count) + Double(gi) * 1e-6, n: seq.count))
                }
            }
            seq.sort { $0.at != $1.at ? $0.at < $1.at : $0.n < $1.n }
            var step = Int(Reading.jsRound(Double(NN) * 0.38))
            func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
            while gcd(step, NN) != 1 { step += 1 }
            var l = [Int](repeating: 0, count: NN)
            for (i, q) in seq.enumerated() { l[(i * step + 3) % NN] = q.gi }
            label = l
        }
        var used = [Int](repeating: 0, count: groups.count)
        var out: [Item] = []
        for r in 0..<N {
            for c in 0..<N {
                let i = r * N + c
                let gi = label?[i] ?? 0
                let grp = groups[gi]
                let name: String
                if label != nil { name = grp.names[used[gi] % grp.names.count]; used[gi] += 1 }
                else { name = grp.names[(r * N + c + r * 2) % grp.names.count] }
                let s = 22 + rnd() * 10
                let px = Double(c) * C + (C - s) / 2 + (rnd() - 0.5) * 18 + Double(r % 2) * C / 2
                let py = Double(r) * C + (C - s) / 2 + (rnd() - 0.5) * 18
                let rot = (rnd() - 0.5) * 50
                out.append(Item(name: name, s: s, px: px, py: py, rot: rot, g: grp.g))
            }
        }
        return out
    }

    /// A doodle standing on the wallpaper of a W×H chat: its tile place repeated over the whole chat.
    struct Placed { let item: Item; let x, y: Double }

    /// vis: the groups to draw ("*" and the endings still within reach); nil = all
    static func lay(_ cfg: Config, seed: String, size: CGSize, vis: Set<String>?) -> [Placed] {
        let T = Double(tile), W = Double(size.width), H = Double(size.height)
        var out: [Placed] = []
        for it in items(cfg, seed: seed) {
            if let vis, !vis.contains(it.g) { continue }
            var ox = -T
            while ox < W + T {
                var oy = 0.0
                while oy < H + T {
                    let x = ox + it.px, y = oy + it.py
                    if x > -it.s && x < W && y > -it.s && y < H { out.append(Placed(item: it, x: x, y: y)) }
                    oy += T
                }
                ox += T
            }
        }
        return out
    }

    // MARK: - drawing

    /// One doodle ready to draw, on its 24×24 grid: thin lines (some dashed), and the odd word.
    struct Art {
        var lines: [(path: Path, dash: [CGFloat])] = []
        var words: [(text: String, at: CGPoint, size: CGFloat)] = []
    }

    private static var cache: [String: Art] = [:]

    static func art(_ name: String) -> Art {
        if let a = cache[name] { return a }
        var a = Art()
        for el in (DoodleData.all[name] ?? "").split(separator: ";") {
            let f = el.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            func num(_ k: Int) -> CGFloat { k < f.count ? CGFloat(Double(f[k]) ?? 0) : 0 }
            func matrix(_ k: Int) -> CGAffineTransform? {
                guard k < f.count else { return nil }
                let m = f[k].split(separator: " ").compactMap { Double($0) }.map { CGFloat($0) }
                return m.count == 6 ? CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]) : nil
            }
            switch f.first ?? "" {
            case "P":
                var p = SVGPath.parse(f.count > 1 ? f[1] : "")
                if let m = matrix(2) { p = p.applying(m) }
                let dash = f.count > 3 ? f[3].split(separator: " ").compactMap { Double($0) }.map { CGFloat($0) } : []
                a.lines.append((p, dash))
            case "C":
                let r = num(3)
                a.lines.append((Path(ellipseIn: CGRect(x: num(1) - r, y: num(2) - r, width: 2 * r, height: 2 * r)), []))
            case "R":
                let rect = CGRect(x: num(1), y: num(2), width: num(3), height: num(4))
                var p = num(5) > 0 ? Path(roundedRect: rect, cornerRadius: num(5), style: .circular) : Path(rect)
                if let m = matrix(6) { p = p.applying(m) }
                a.lines.append((p, []))
            case "T":
                a.words.append((f.count > 1 ? f[1] : "", CGPoint(x: num(2), y: num(3)), num(4)))
            default: break
            }
        }
        cache[name] = a
        return a
    }

    /// Draws one doodle with its top left corner at (x, y), `s` points big, turned `rot` degrees about its middle:
    /// white lines 1.5 thick on the 24 grid, very faint (7.5 %).
    static func draw(_ name: String, in ctx: inout GraphicsContext, x: Double, y: Double, s: Double, rot: Double) {
        let a = art(name)
        var c = ctx
        c.translateBy(x: x + s / 2, y: y + s / 2)
        c.rotate(by: .degrees(rot))
        c.translateBy(x: -s / 2, y: -s / 2)
        c.scaleBy(x: s / 24, y: s / 24)
        let ink = Color.white.opacity(0.075)
        for l in a.lines {
            c.stroke(l.path, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: l.dash))
        }
        for w in a.words {
            c.draw(Text(w.text).font(.system(size: w.size)).foregroundColor(ink), at: w.at, anchor: .bottom)
        }
    }
}
