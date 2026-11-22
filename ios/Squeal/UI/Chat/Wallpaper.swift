import SwiftUI

/// The chat wallpaper's doodles, alive (template.html WALL). One keeper knows where every doodle is and what it is
/// doing, so part switches and choices, at any moment, carry on smoothly instead of restarting:
/// - a chat opens with no doodles; the part's doodles fly in from all four sides and settle exactly where the
///   wallpaper has them; then the plain wallpaper takes over;
/// - a part switch: doodles flying in or resting stop where they are and fall off the bottom (≈2800 pt/s², not all
///   at once); doodles already falling just finish; the new part's doodles start flying in as the falling ends;
///   doodles still waiting off screen never appear;
/// - interactive: a choice that closes off endings makes those endings' doodles fall; going back to a choice (or
///   starting over) brings them flying back.
/// It all runs behind the messages and takes no taps.
final class WallKeeper: ObservableObject {
    final class Piece {
        let item: Doodles.Item
        let x, y: Double                       // where the wallpaper has it
        enum Phase { case rest, flyIn, fall }
        var phase: Phase = .rest
        var cx = 0.0, cy = 0.0, crot = 0.0     // where it is now
        var sx = 0.0, sy = 0.0, srot = 0.0, t0 = 0.0, dur = 0.0            // flying in
        var fx0 = 0.0, fy0 = 0.0, frot = 0.0, ft0 = 0.0, spin = 0.0        // falling
        var gone = false
        init(_ p: Doodles.Placed) { item = p.item; x = p.x; y = p.y }
    }

    static let gravity = 2800.0                // pt/s²: a brisk, natural fall on a phone screen

    private(set) var pieces: [Piece] = []
    private(set) var rest: (cfg: Doodles.Config, seed: String)? = nil
    /// the groups wanted on screen (nil = all)
    private(set) var vis: Set<String>? = nil
    /// what the plain wallpaper draws right now: nothing (`bgOn` false), or the groups in `bgVis` (nil = all)
    private(set) var bgOn = false
    private(set) var bgVis: Set<String>? = nil
    /// bumped when the plain wallpaper changes (the still layer redraws only then)
    @Published private(set) var bgRev = 0
    /// bumped every frame something moves
    @Published private(set) var frame = 0

    private var size: CGSize = .zero
    private var waiting: (() -> Void)? = nil
    private var seed: UInt32 = 9
    private lazy var loop = FrameLoop { [weak self] now in self?.tick(now) }

    private func rnd() -> Double { seed = seed &* 1664525 &+ 1013904223; return Double(seed) / 4294967296 }

    /// the chat's size is known (or changed)
    func resize(_ s: CGSize) {
        guard s.width > 0, s.height > 0, s != size else { return }
        size = s
        if let w = waiting { waiting = nil; w() } else { bgRev += 1 }
    }

    /// what the still layer draws
    var still: [Doodles.Placed] {
        guard bgOn, let rest, size.width > 0 else { return [] }
        return Doodles.lay(rest.cfg, seed: rest.seed, size: size, vis: bgVis)
    }

    /// Show a part's doodles (a fresh chat, or the same story's chat after a part switch).
    /// `switching`: this story's chat was already showing a part; `same`: the same part again (read again, back to
    /// a choice, start over): it carries on, only endings that came back into reach (or went out of it) move.
    func show(_ cfg: Doodles.Config, seed: String, vis: Set<String>?, switching: Bool, same: Bool) {
        if size.width <= 0 { waiting = { [weak self] in self?.show(cfg, seed: seed, vis: vis, switching: switching, same: same) }; return }
        if Doodles.items(cfg, seed: seed).isEmpty { clear(); return }
        let now = chatNow()
        if reduceMotion() {
            pieces = []; loop.stop()
            rest = (cfg, seed); self.vis = vis; bgOn = true; bgVis = vis; bgRev += 1; frame += 1
            return
        }
        let switching = switching && rest != nil
        if switching && same { setVis(vis); return }
        if !switching { loop.stop(); pieces = []; bgOn = false; bgVis = nil }
        if switching {
            unrest(nil)                                              // the old part's resting doodles become pieces
            drop(now) { _ in true }
        }
        rest = (cfg, seed); self.vis = vis; bgOn = false; bgVis = nil; bgRev += 1
        bring(cfg, seed, vis, now)
        loop.start()
    }

    func clear() { loop.stop(); pieces = []; rest = nil; vis = nil; bgOn = false; bgVis = nil; bgRev += 1; frame += 1 }

    /// interactive: the endings within reach changed (a choice, or back to a choice)
    func setVis(_ v: Set<String>?) {
        guard rest != nil else { return }
        let was = vis
        vis = v
        guard let v, let was else { return }
        if reduceMotion() { bgVis = v; bgOn = true; bgRev += 1; return }
        let gone = was.subtracting(v), back = v.subtracting(was)
        if gone.isEmpty && back.isEmpty { return }
        let now = chatNow()
        if !gone.isEmpty { unrest(gone); drop(now) { gone.contains($0.item.g) } }
        if !back.isEmpty, let rest { bring(rest.cfg, rest.seed, back, now) }
        if !pieces.isEmpty { loop.start() }
    }

    /// the doodles drawn by the plain wallpaper come back as pieces at rest, so they can move
    private func unrest(_ groups: Set<String>?) {
        guard let rest, bgOn else { return }                        // nothing is drawn by the plain wallpaper
        let v: Set<String>?
        if let groups { v = bgVis.map { $0.intersection(groups) } ?? groups } else { v = bgVis }
        for p in Doodles.lay(rest.cfg, seed: rest.seed, size: size, vis: v) {
            let d = Piece(p)
            d.phase = .rest; d.cx = p.x; d.cy = p.y; d.crot = p.item.rot
            pieces.append(d)
        }
        if let groups {
            if let b = bgVis { bgVis = b.subtracting(groups); if bgVis?.isEmpty == true { bgOn = false; bgVis = nil } }
        } else { bgOn = false; bgVis = nil }
        bgRev += 1
    }

    /// make these doodles go: the ones still waiting off screen just vanish, the rest fall from where they are
    private func drop(_ now: Double, _ test: (Piece) -> Bool) {
        pieces.removeAll { test($0) && $0.phase == .flyIn && now < $0.t0 }
        for d in pieces where test(d) && d.phase != .fall {
            d.phase = .fall; d.fx0 = d.cx; d.fy0 = d.cy; d.frot = d.crot
            d.ft0 = now + rnd() * 0.45
            d.spin = (rnd() - 0.5) * 80
        }
    }

    /// bring doodles flying in once whatever is falling has gone
    private func bring(_ cfg: Doodles.Config, _ seedText: String, _ v: Set<String>?, _ now: Double) {
        let W = Double(size.width), H = Double(size.height)
        var fallEnd = now
        var falling = false
        for d in pieces where d.phase == .fall {
            falling = true
            fallEnd = max(fallEnd, d.ft0 + sqrt(2 * max(0, H + 40 - d.fy0) / Self.gravity))
        }
        let start = falling ? max(now + 0.2, fallEnd) : now + 0.12  // the new ones set off when the fall has ended
        for p in Doodles.lay(cfg, seed: seedText, size: size, vis: v) {
            let side = Int(rnd() * 4), off = p.item.s + 24
            let d = Piece(p)
            d.phase = .flyIn
            d.sx = side == 0 ? -off : side == 1 ? W + off : p.x
            d.sy = side == 2 ? -off : side == 3 ? H + off : p.y
            d.srot = p.item.rot + (rnd() - 0.5) * 120
            d.t0 = start + rnd() * 0.9
            d.dur = 0.65 + rnd() * 0.35
            d.cx = d.sx; d.cy = d.sy; d.crot = d.srot
            pieces.append(d)
        }
    }

    private func tick(_ now: Double) {
        let H = Double(size.height)
        var busy = false
        for d in pieces {
            switch d.phase {
            case .fall:
                let t = max(0, now - d.ft0)
                d.cx = d.fx0; d.cy = d.fy0 + 0.5 * Self.gravity * t * t; d.crot = d.frot + d.spin * min(1, t / 0.8)
                if d.cy > H + 40 { d.gone = true } else { busy = true }
            case .flyIn:
                let q = max(0, min(1, (now - d.t0) / d.dur)), e = 1 - pow(1 - q, 3)
                d.cx = lerp(d.sx, d.x, e); d.cy = lerp(d.sy, d.y, e); d.crot = lerp(d.srot, d.item.rot, e)
                if q >= 1 { d.phase = .rest } else { busy = true }
            case .rest: break
            }
        }
        pieces.removeAll { $0.gone }
        if !busy {
            // all landed: the plain wallpaper (of what is in reach) takes over
            loop.stop()
            pieces = []; bgOn = true; bgVis = vis; bgRev += 1
        }
        frame += 1
    }
}

/// The wallpaper behind a chat: the plain one (drawn once) and, over it, whatever is flying or falling.
struct WallpaperView: View {
    @ObservedObject var keeper: WallKeeper

    var body: some View {
        GeometryReader { g in
            ZStack {
                StillWall(placed: keeper.still, rev: keeper.bgRev)
                    .equatable()
                Canvas { ctx, _ in
                    for d in keeper.pieces {
                        Doodles.draw(d.item.name, in: &ctx, x: d.cx, y: d.cy, s: d.item.s, rot: d.crot)
                    }
                }
            }
            .onAppear { keeper.resize(g.size) }
            .onChange(of: g.size) { _, s in keeper.resize(s) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StillWall: View, Equatable {
    let placed: [Doodles.Placed]
    let rev: Int
    static func == (a: StillWall, b: StillWall) -> Bool { a.rev == b.rev }
    var body: some View {
        Canvas { ctx, _ in
            for p in placed { Doodles.draw(p.item.name, in: &ctx, x: p.x, y: p.y, s: p.item.s, rot: p.item.rot) }
        }
    }
}
