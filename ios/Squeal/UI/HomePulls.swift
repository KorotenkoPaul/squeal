import SwiftUI
import UIKit

/// Plays `step` frame by frame for `ms` (template.html tween()).
@MainActor
func tween(_ ms: Double, _ ease: @escaping (Double) -> Double, _ step: @escaping (Double) -> Void) async {
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        let t0 = CACurrentMediaTime()
        let length = reduceMotion() ? 0 : ms                 // Reduce Motion: nothing glides, it is simply there
        var loop: FrameLoop?
        loop = FrameLoop { now in
            let t = max(0, min(1, (now - t0) * 1000 / max(1, length)))
            step(ease(t))
            if t >= 1 { loop?.stop(); loop = nil; done.resume() }
        }
        loop?.start()
    }
}
@MainActor func wait(_ ms: Double) async { try? await Task.sleep(nanoseconds: UInt64(ms * 1_000_000)) }
private let easeInQuad: (Double) -> Double = { $0 * $0 }
private let easeOutQuad: (Double) -> Double = { 1 - (1 - $0) * (1 - $0) }
private let cubicOut: (Double) -> Double = { 1 - pow(1 - $0, 3) }

/// Home's two pulls (template.html pullToRefresh, pullForRandom). A fling into the top or the bottom bounces with the
/// phone's own spring; a finger pull at an edge is ours — the owl's eyes at the top, the random-story reel at the
/// bottom. The two never run at once: once a pull is ours the phone's scrolling never gets that touch.
///
/// The same one pan also carries Home's two sideways drags — the genre oval and the slider: one touch, one job
/// (BUGS #48, #50, #54). The finger's first clear move decides whose the touch is, and it stays theirs to the lift:
/// sideways on the genre row or on the slider, the page never scrolls or pulls under it; down or up, it is the
/// page's, and neither the oval nor the slider moves.
@MainActor
final class HomePulls: ObservableObject {
    weak var model: AppModel?
    /// the page's height (down to the tab bar)
    var height: CGFloat = 0
    var hintHeight: CGFloat = 18

    // the owl
    @Published private(set) var down: CGFloat = 0           // the page is pulled this far down
    @Published private(set) var settling = false            // gliding (0.38 s), not under the finger
    @Published private(set) var lids = 1.0                  // 1 shut, 0 open
    @Published private(set) var evil = false                // the eyes are red
    /// the page is pulled down, refreshing or on its way back: the slider's clock stands still
    @Published private(set) var pulling = false
    private var refreshBusy = false

    // the reel
    @Published private(set) var reelOn = false
    @Published private(set) var reelTop: CGFloat = 0
    @Published private(set) var lift: CGFloat = 0           // the page is lifted this far up
    @Published private(set) var dropping = false            // the page slides back down (0.35 s)
    @Published private(set) var strip = 0.0                 // how far the rows have turned
    @Published private(set) var list: [Story] = []
    @Published private(set) var chosen = false
    @Published private(set) var hintKey = "pull"

    /// the genre oval and the slider (with where the slider is on screen and how far apart its cards are)
    weak var genre: GenreOval?
    weak var slider: SliderEngine?
    var sliderFrame = CGRect.zero
    var sliderStep: CGFloat = 0

    private let pan = HeldPan()
    private enum Mode { case none, refresh, reel, genre, slider }
    private var mode = Mode.none
    private var d = 0.0, ov = 0.0, lastRaw = 0.0, rawBase = 0.0, spin: Double? = nil, offset = 0.0, vy = 0.0, lastLift = 0.0
    private var reelBusy = false, sinking = false, caught = false
    private lazy var sinkLoop = FrameLoop { [weak self] now in self?.sinkFrame(now) }
    private var sink = (x0: 0.0, v0: 0.0, t0: 0.0)
    private var token = 0

    var geo: ReelGeometry {
        let H = Double(height)
        return ReelGeometry(tabsTop: H, hintBottom: H - 24 - 13, hintGap: max(8, 14 + 13))
    }

    func attach(_ sv: UIScrollView) {
        pan.attach(sv)
        pan.begins = { [weak self] m in MainActor.assumeIsolated { self?.begins(m) ?? false } }
        pan.changed = { [weak self] m in MainActor.assumeIsolated { self?.changed(m) } }
        pan.ended = { [weak self] m, c in MainActor.assumeIsolated { self?.ended(m, cancelled: c) } }
        // the genre row hears of a finger the moment it comes down (a press on another genre brings the oval over)
        Taps.shared.onDown["genre"] = { [weak self] p in
            guard let self, self.onHome, self.mode == .none else { return }
            self.genre?.down(at: p)
        }
        Taps.shared.onFingersUp["genre"] = { [weak self] in
            guard let self, self.mode != .genre else { return }
            self.genre?.lifted()
        }
        // sinking back is a spring that can be caught: a new touch takes the reel from where it is
        Taps.shared.onDown["reel"] = { [weak self] _ in
            guard let self, self.sinking else { return }
            self.sinkLoop.stop(); self.sinking = false; self.reelBusy = false; self.ov = 0
            self.rawBase = self.d; self.lastRaw = self.d; self.spin = self.d * 0.9; self.vy = 0; self.caught = true
            self.dropping = false
        }
        Taps.shared.onFingersUp["reel"] = { [weak self] in
            guard let self, self.caught, self.mode != .reel else { return }
            self.caught = false; self.endReel(cancelled: false)          // only touched: it sinks on from there
        }
    }

    func detach() {
        token += 1
        pan.detach(); sinkLoop.stop()
        Taps.shared.onDown["reel"] = nil; Taps.shared.onFingersUp["reel"] = nil
        Taps.shared.onDown["genre"] = nil; Taps.shared.onFingersUp["genre"] = nil
    }

    private var onHome: Bool { model.map { $0.tab == "home" && $0.previewID == nil && $0.chat == nil } ?? false }

    private func begins(_ m: HeldPan.Move) -> Bool {
        guard let sv = pan.scrollView, onHome else { return false }
        let t = m.translation
        if caught { mode = .reel; caught = false; return true }
        // the genre row and the slider: sideways first, the touch is theirs; down or up first, it is the page's
        if let g = genre, g.rowFrame.insetBy(dx: 0, dy: -6).contains(m.start) {
            if abs(t.x) > abs(t.y) { g.dragBegan(); mode = .genre; return true }
            g.pageTookIt()
        } else if let s = slider, sliderStep > 0, sliderFrame.contains(m.start), abs(t.x) > abs(t.y) {
            s.dragBegan(); mode = .slider
            return true
        }
        let top = -sv.adjustedContentInset.top, y = sv.contentOffset.y
        let end = max(top, sv.contentSize.height + sv.adjustedContentInset.bottom - sv.bounds.height)
        // while the phone is still bouncing (scrolled past an edge) the touch is left to it
        if !refreshBusy, abs(y - top) <= 0.5, t.y > 0, t.y >= abs(t.x) {
            mode = .refresh; d = 0
            pulling = true; settling = false
            return true
        }
        if !reelBusy, y >= end - 2, y <= end + 0.5, t.y < 0, abs(t.y) >= abs(t.x) {
            mode = .reel; d = 0; ov = 0; lastRaw = 0; rawBase = 0; spin = 0; vy = 0
            return true
        }
        return false
    }

    private func changed(_ m: HeldPan.Move) {
        switch mode {
        case .refresh:
            d = RefreshPull.shown(Double(m.translation.y))
            settling = false
            down = CGFloat(d); lids = RefreshPull.lids(d)               // the eyes open as you pull
        case .reel: moveReel(raw: rawBase - Double(m.translation.y), speed: -Double(m.velocity.y))
        case .genre: genre?.drag(m.translation.x)
        case .slider: slider?.drag(m.translation.x, step: sliderStep)
        case .none: break
        }
    }

    private func ended(_ m: HeldPan.Move, cancelled: Bool) {
        let was = mode; mode = .none
        switch was {
        case .refresh: endRefresh(cancelled: cancelled)
        case .reel: endReel(cancelled: cancelled)
        case .genre: genre?.dragEnded()                     // (taken by the phone: it settles where it is, not back)
        case .slider:
            // a flick carries on to the next card, as the finger's speed says; a touch the phone took settles on the nearest
            slider?.dragEnded(predicted: m.translation.x + (cancelled ? 0 : m.velocity.x * 0.25), step: sliderStep)
        case .none: break
        }
    }

    // MARK: - pull to refresh: the owl's eyes
    // Pull the page down and the owl's eyes come down from above with it, opening as you pull. Let go past the line:
    // they open white, shut once — the page refreshes while they are shut (a slow network just keeps them shut
    // longer) — open red, and the page goes back up with them still open.

    private func glide(to v: Double) {
        if reduceMotion() { settling = false; down = CGFloat(v); return }
        settling = true
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.38)) { down = CGFloat(v) }
    }

    private func endRefresh(cancelled: Bool) {
        let my = token
        if d < RefreshPull.line || cancelled {                         // not far enough: eyes shut, page glides back
            let from = RefreshPull.lids(d)
            Task { await tween(200, easeOutQuad) { [weak self] t in if let s = self, s.token == my, !s.refreshBusy, s.mode != .refresh { s.lids = lerp(from, 1, t) } } }
            d = 0; glide(to: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion() ? 0 : 0.38)) { [weak self] in
                guard let self, !self.refreshBusy, self.mode != .refresh else { return }
                self.pulling = false                                   // the page is back: the clock runs again
            }
            return
        }
        refreshBusy = true
        let from = RefreshPull.lids(d)
        d = RefreshPull.rest; glide(to: d)
        Task {
            guard let model else { return }
            async let loaded: Void = model.reload()                    // reload now, in the background of the animation
            // white eyes, closed eyes, red eyes: nothing else
            await tween(280 * from + 1, easeOutQuad) { [weak self] t in self?.lids = from * (1 - t) }
            await wait(380)
            await tween(120, easeInQuad) { [weak self] t in self?.lids = t }          // shut…
            async let least: Void = wait(60)
            _ = await (loaded, least)                                  // …a slow network keeps them shut…
            if my == token, model.tab == "home" { model.showFresh() }  // (another tab opened meanwhile: nothing is redrawn)
            evil = true
            await tween(220, easeOutQuad) { [weak self] t in self?.lids = 1 - t }     // …open, red
            await wait(500)
            // a finger resting on the screen holds the page down; the eyes wait with it, and both go up together
            // (never for ever: should the end of a touch ever be missed, the page goes back after 8 s — BUGS #114)
            var held = 0.0
            while Taps.shared.fingers > 0 && my == token && held < 8000 { await wait(50); held += 50 }
            d = 0; glide(to: 0)
            await wait(reduceMotion() ? 0 : 380)
            evil = false; lids = 1
            refreshBusy = false; pulling = false
        }
    }

    // MARK: - the random story: pull up at the very bottom
    // The whole page slides up by exactly as much as you pull, and a reel of stories (cover + title) rises in the space
    // under it, turning with your finger. All the way up, let go: the reel settles on the nearest row, which is
    // outlined and opens. Not far enough: it sinks back behind the tabs.

    private func deal() {
        guard let model else { return }
        let pool = Shelf.randomPool(model.stories, genre: model.genre,
                                    started: { model.prog($0).pos.contains { $0 != 0 } }, percent: { model.percent($0) })
        list = pool.shuffled()                                         // whatever row is in the window when you let go is the story
        offset = 0; strip = 0
    }

    private func show(_ raw: Double, liftAs: Double? = nil) {
        let g = geo
        let l = liftAs ?? g.lift(raw), k = min(1, raw / g.line)
        lastLift = l
        reelOn = raw > 0
        reelTop = CGFloat(g.top(raw, lift: l))
        lift = raw != 0 ? CGFloat(l + ReelGeometry.ovPx(ov)) : 0
        // one line of words, always in the hint's place: pull up… → keep pulling → release
        if !(reelBusy && liftAs == nil && raw != 0) { hintKey = raw == 0 ? "pull" : k >= 1 ? "release" : "keep" }
        if raw != 0 { strip = offset + (spin ?? raw * 0.9) }           // the reel turns with your finger
    }

    private func moveReel(raw: Double, speed: Double) {
        let step = raw - lastRaw; lastRaw = raw
        vy = speed                                                     // finger speed upwards, pt/s
        if d == 0 && raw <= 0 { return }
        if d == 0 { deal(); spin = 0; dropping = false }
        let full = geo.full
        var s = step
        // back down after stretching: the page comes down first, 1:1 with the finger, then the reel
        if s < 0 && ov > 0 { let vis = ReelGeometry.ovPx(ov) + s; if vis > 0 { ov = ReelGeometry.ovInv(vis); s = 0 } else { ov = 0; s = vis } }
        var eff = d + s
        if eff > full { ov += eff - full; eff = full }                 // past the top: the page stretches, the reel holds
        eff = max(0, eff)
        spin = (spin ?? 0) + step * 0.9                                // the rows turn with every move of the finger, stretched or not
        if eff <= 0 && ov == 0 { d = 0; spin = 0; show(0); return }
        d = eff; show(d)
    }

    private func endReel(cancelled: Bool) {
        if d == 0 && ov == 0 && !sinking { spin = nil; return }        // only touched: nothing to put back
        if let sp = spin { offset += sp - d * 0.9; spin = nil }        // the rows keep their turn as the finger lets go
        let g = geo
        if d < g.line || cancelled {
            // a critically damped spring from the finger's own speed: no drop, no snap; page and reel land together
            if d > g.full { offset += (d - g.full) * 0.9; d = g.full }
            if reduceMotion() { d = 0; ov = 0; show(0); return }      // Reduce Motion: it is simply gone
            sink = (d, max(-1500, min(1500, vy * 0.6)), CACurrentMediaTime())
            reelBusy = true; sinking = true
            sinkLoop.start()
            return
        }
        reelBusy = true
        let my = token
        let from = offset + d * 0.9, n = max(1, list.count)
        let (to, index) = ReelGeometry.settle(from, rows: n)
        let pick = list.isEmpty ? nil : list[index]
        Task {
            if ov > 0 {                                                // the stretched page springs back while the reel settles
                let v0 = ReelGeometry.ovPx(ov)
                Task { await tween(380, cubicOut) { [weak self] e in
                    guard let self, self.token == my else { return }
                    self.ov = e >= 1 ? 0 : ReelGeometry.ovInv(v0 * (1 - e))
                    if self.d != 0 { self.lift = CGFloat(self.lastLift + ReelGeometry.ovPx(self.ov)) }
                } }
            }
            // no spin: the reel only ever turns with your finger; letting go, it settles on the nearest row in a blink
            await tween(ReelGeometry.settleMs(from: from, to: to), cubicOut) { [weak self] t in self?.strip = lerp(from, to, t) }
            withAnimation(reduceMotion() ? nil : .timingCurve(0.25, 0.8, 0.25, 1, duration: 0.35)) { chosen = true }       // the chosen one pops forward a little
            await wait(380)
            // another tab opened while the reel settled: no story page pops up over it
            if my == token, onHome, let pick { model?.previewID = pick.id }
            chosen = false; reelBusy = false; ov = 0; d = 0
            dropping = true
            withAnimation(reduceMotion() ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) { show(0) }
        }
    }

    private func sinkFrame(_ now: Double) {
        let tt = now - sink.t0, x = ReelGeometry.sink(x0: sink.x0, v0: sink.v0, t: tt)
        d = x
        if tt > 0.08 && x < 0.4 { sinkLoop.stop(); sinking = false; reelBusy = false; d = 0; show(0); return }
        show(x)                                                        // the same 1:1 rule on the way back: the gap holds
    }

    /// CI screenshots: the owl pulled down `px`, or the reel pulled up `px`
    func pose(pull px: Double?, reel r: Double?) {
        if r != nil, let sv = pan.scrollView {
            sv.contentOffset.y = max(0, sv.contentSize.height + sv.adjustedContentInset.bottom - sv.bounds.height)
        }
        if let px { d = RefreshPull.shown(px); down = CGFloat(d); lids = RefreshPull.lids(d); pulling = true }
        if let r { deal(); spin = nil; d = min(r, geo.full); offset = max(0, r - geo.full) * 0.9; show(d) }
    }
}

/// The owl's eyes (owlEyes()): the app icon's eyes, 74 pt wide; each lid is a big tilted ellipse sliding along the
/// eye's slant; after the blink they are red, with a glow.
struct OwlEyes: View {
    @ObservedObject var pulls: HomePulls
    /// the first line of the page ("Top this week"): where its letters begin, from the page's top
    var textTop: CGFloat

    private static func art(_ name: String) -> UIImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "brand").flatMap { UIImage(contentsOfFile: $0.path) }
    }
    private static let base = art("eyes-base"), red = art("eyes-evil"), shadow = art("eyes-shadow")

    var body: some View {
        let w: CGFloat = 74, h = w * 187 / 360
        // centred between the top of the page and its first line as it stands when pulled down: the eyes span 13–326 of the art's 480
        let eyeMid = h * (13 + 326) / 2 / 480
        let top = (CGFloat(RefreshPull.rest) + textTop) / 2 - eyeMid
        ZStack(alignment: .top) {
            ZStack {
                if let b = Self.base { Image(uiImage: b).resizable() }
                if pulls.evil, let r = Self.red {
                    Image(uiImage: r).resizable().blur(radius: 7 * w / 360).opacity(0.85)
                    Image(uiImage: r).resizable()
                }
                if let s = Self.shadow { Image(uiImage: s).resizable() }
            }
            .frame(width: w, height: h)
            .mask(Lids(t: pulls.lids).frame(width: w + 80, height: h + 80))
            .padding(.top, top)
        }
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .top)
        .offset(y: CGFloat(RefreshPull.eyesY(Double(pulls.down))))
        .animation(pulls.settling ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.38) : nil, value: pulls.down)
        .frame(height: 76, alignment: .top).clipped()
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    /// everything but the two lids (1 shut, 0 open), in the art's own 360 × 187 drawing
    private struct Lids: View {
        let t: Double
        var body: some View {
            Canvas { ctx, size in
                let k = (size.width - 80) / 360, S = 360.0 / 924
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                ctx.blendMode = .destinationOut
                for (cx, rot) in [(236.8, 30.0), (787.2, -30.0)] {
                    let c = CGPoint(x: (cx - 50) * S, y: (419.8 - 250) * S)
                    let a = rot * .pi / 180, n = CGPoint(x: -sin(a), y: cos(a)), D = 307.2 * S * (1 - t)
                    let x = c.x - n.x * D, y = c.y - n.y * D + 8 * S
                    var tr = CGAffineTransform(translationX: 40 + x * k, y: 40 + y * k).rotated(by: a)
                    tr = tr.scaledBy(x: k, y: k)
                    let e = Path(ellipseIn: CGRect(x: -345.6 * S, y: -243.2 * S, width: 2 * 345.6 * S, height: 2 * 243.2 * S)).applying(tr)
                    ctx.fill(e, with: .color(.white))
                }
            }
        }
    }
}

/// The reel: a window exactly one story tall and as wide as the page; its rows look like search results.
struct ReelView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var pulls: HomePulls

    var body: some View {
        let n = pulls.list.count, row = CGFloat(ReelGeometry.row)
        GeometryReader { g in
            if pulls.reelOn && n > 0 {
                let o = CGFloat(ReelGeometry.wrap(pulls.strip, rows: n)), first = Int((o / row).rounded(.down))
                ZStack(alignment: .topLeading) {
                    ForEach([first, first + 1], id: \.self) { k in
                        let s = pulls.list[((k % n) + n) % n]
                        HStack(spacing: 14) {
                            Thumb(story: s)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).font(AppFont.ui(18, 600)).foregroundStyle(.white).lineLimit(1)
                                MetaLine(story: s)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: row)
                        .offset(y: CGFloat(k) * row - o)
                    }
                }
                .frame(width: g.size.width - 36, height: row, alignment: .topLeading)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // picked: the same thin outline as the selected part in the preview; no fill, no glow
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5).opacity(pulls.chosen ? 1 : 0))
                .scaleEffect(pulls.chosen && !reduceMotion() ? 1.04 : 1)
                .position(x: g.size.width / 2, y: pulls.reelTop + row / 2)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
