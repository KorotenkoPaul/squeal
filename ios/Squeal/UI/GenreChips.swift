import SwiftUI
import UIKit

/// The genre oval's own motion (template.html wireHome): its centre follows the finger 1:1; let go and it glides to
/// the nearest genre, which becomes the genre; a tap glides it to the tapped one. Press on another genre and the oval
/// at once slides over to it (0.18 s, after a blink of 90 ms or the first sideways move — so a touch that turns into
/// a pull down never twitches it) and follows the finger from there.
///
/// One touch, one job (BUGS #48, #50): the sideways drag is not a SwiftUI gesture but part of Home's own UIKit pan
/// (`HomePulls`, mode `.genre`), which the page's scrolling waits for — once the oval has the touch, the page neither
/// scrolls nor pulls down until the finger lifts; a touch that goes down first is the page's and the oval stays put.
@MainActor
final class GenreOval: ObservableObject {
    /// the oval's centre in the row's own coordinates; below 0: it stands on the chosen genre
    @Published private(set) var pos: CGFloat = -1

    /// each genre's width and centre, kept up to date by the row
    var widths: [CGFloat] = []
    var centres: [CGFloat] = []
    /// where the row is on screen: what shows of it, and its (scrolling) content
    var rowFrame = CGRect.zero
    var contentFrame = CGRect.zero
    var chosen: () -> Int = { 0 }
    var choose: (Int) -> Void = { _ in }

    private var base: CGFloat = 0, target: CGFloat = 0
    private var pull: (res: CGFloat, t0: Double, ms: Double)? = nil
    private var glide: (from: CGFloat, to: CGFloat, t0: Double, ms: Double)? = nil
    private var pending = -1
    private var pressed = false, moved = false
    private var press = 0
    private lazy var loop = FrameLoop { [weak self] now in self?.frame(now) }

    private var home: CGFloat { centres.indices.contains(chosen()) ? centres[chosen()] : (centres.first ?? 0) }
    /// where the oval's centre is right now
    var at: CGFloat { pos < 0 ? home : pos }

    private func place(_ x: CGFloat) {
        guard let a = centres.first, let b = centres.last else { return }
        pos = min(b, max(a, x))
    }

    func nearest() -> Int {
        let x = at
        return centres.indices.min { abs(centres[$0] - x) < abs(centres[$1] - x) } ?? 0
    }

    /// which genre is under a point of the screen (nil: none; the 8 pt between two belong to neither)
    func chip(at p: CGPoint) -> Int? {
        guard rowFrame.insetBy(dx: 0, dy: -6).contains(p) else { return nil }
        let x = p.x - contentFrame.minX
        return centres.indices.first { abs(x - centres[$0]) <= widths[$0] / 2 }
    }

    /// The oval glides to genre `k` (cubic ease-out, 160–340 ms by the way to go; at once with Reduce Motion), and
    /// that genre is chosen.
    func glideTo(_ k: Int) {
        guard centres.indices.contains(k) else { return }
        pull = nil; pending = -1
        let from = at, to = centres[k]
        let ms = reduceMotion() ? 0 : min(340, 160 + Double(abs(to - from)) * 0.6)
        choose(k)
        if ms == 0 || abs(to - from) < 0.01 { glide = nil; rest(); return }
        pos = from
        glide = (from, to, chatNow(), ms / 1000)
        loop.start()
    }

    /// nothing moves it any more: standing on the chosen genre, it simply is that genre's oval (so a change of
    /// language, which changes every width, cannot leave it beside its word)
    private func rest() {
        guard glide == nil, pull == nil, !pressed else { return }
        loop.stop()
        if nearest() == chosen() || pos < 0 { pos = -1 } else { pos = centres[nearest()] }
    }

    private func frame(_ now: Double) {
        if let g = glide {
            let t = max(0, min(1, (now - g.t0) / g.ms))
            place(g.from + (g.to - g.from) * CGFloat(1 - pow(1 - t, 3)))
            if t >= 1 { glide = nil }
        } else if let p = pull {
            let t = max(0, min(1, (now - p.t0) / p.ms))
            place(target + p.res * CGFloat(pow(1 - t, 3)))
            if t >= 1 { pull = nil }
        }
        if glide == nil && pull == nil { loop.stop(); if !pressed { rest() } }
    }

    // MARK: the finger

    /// a finger comes down somewhere on the screen (`Taps.onDown`)
    func down(at p: CGPoint) {
        guard rowFrame.insetBy(dx: 0, dy: -6).contains(p), !centres.isEmpty else { return }
        glide = nil; pull = nil; loop.stop()
        let x = at
        pos = x; base = x; target = x
        pressed = true; moved = false; pending = -1
        press += 1
        guard let k = chip(at: p), k != nearest(), !reduceMotion() else { return }
        pending = k
        let my = press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self, self.press == my, self.pressed else { return }
            self.slideOver()
        }
    }

    /// the oval slides over to the pressed genre; a drag that starts meanwhile just carries on (the slide's
    /// remainder fades into the finger's place)
    private func slideOver() {
        guard pending >= 0, pressed, centres.indices.contains(pending) else { pending = -1; return }
        let k = pending; pending = -1
        let from = at
        base = centres[k]
        target += base - from
        pull = (from - target, chatNow(), 0.18)
        loop.start()
    }

    /// the touch went down first: it is the page's (a scroll, a refresh) — the oval goes home
    func pageTookIt() {
        guard pressed else { return }
        pending = -1; pressed = false
        if abs(base - home) > 0.01 || pull != nil || abs(at - home) > 0.01 { glideTo(chosen()) } else { rest() }
    }

    /// the touch went sideways first: it is the oval's until the finger lifts
    func dragBegan() {
        if !pressed { let x = at; pos = x; base = x; target = x; pull = nil; glide = nil; pressed = true }
        moved = true
        if pending >= 0 { slideOver() }
    }

    func drag(_ dx: CGFloat) {
        guard moved else { return }
        target = base + dx
        if pull == nil { place(target) }                    // while sliding over, the frame loop places it
    }

    /// let go (or the phone took the touch): it settles on the nearest genre, where it is — never back
    func dragEnded() {
        guard moved else { return }
        moved = false; pressed = false; pull = nil
        glideTo(nearest())
    }

    /// the last finger has left the screen with no drag: a tap on a genre has glided the oval there by now
    /// (`glideTo`); a press that came to nothing (a tap the double-tap rule refused, a finger that only rested
    /// between two genres) leaves the oval on a genre that is not the chosen one — it goes home
    func lifted() {
        guard pressed, !moved else { return }
        pressed = false; pending = -1
        let my = press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.press == my, !self.pressed, self.glide == nil else { return }
            if self.pull != nil || abs(self.at - self.home) > 0.01 { self.glideTo(self.chosen()) } else { self.rest() }
        }
    }
}

/// Genres on Home (All / Horror / Thriller / Romance): one violet oval under the words, like the part disc in the chat.
/// Drag it 1:1 (its width blends between neighbours), let go — it glides to the nearest and the genre switches;
/// tap a genre — it glides there (IDEAS.md «Жанры на главной»). The row is one view for as long as Home lives: a
/// refresh never rebuilds or fades it (BUGS #52).
struct GenreChips: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var oval: GenreOval
    static let keys = ["all", "horror", "thriller", "romance"]

    private let font = AppFont.uiFont(14, 600)
    private var widths: [CGFloat] {
        Self.keys.map { ceil((model.genreName($0) as NSString).size(withAttributes: [.font: font]).width) + 32 }
    }
    private func centres(_ ws: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = 0
        return ws.map { w in defer { x += w + 8 }; return x + w / 2 }
    }
    private var height: CGFloat { ceil(font.lineHeight) + 14 }

    var body: some View {
        let ws = widths, cs = centres(ws)
        let index = Self.keys.firstIndex(of: model.genre) ?? 0
        let _ = sync(ws, cs)
        let at = oval.pos < 0 ? cs[index] : oval.pos
        let sh = shape(at, ws, cs), ovalW = sh.0, near = sh.1
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        ForEach(Array(Self.keys.enumerated()), id: \.offset) { k, key in
                            Capsule().fill(Theme.field).frame(width: ws[k], height: height).id(key)
                        }
                    }
                    Capsule().fill(Theme.accent).frame(width: ovalW, height: height).offset(x: at - ovalW / 2)
                    HStack(spacing: 8) {
                        ForEach(Array(Self.keys.enumerated()), id: \.offset) { k, key in
                            Text(model.genreName(key)).font(Font(font))
                                .foregroundStyle(k == near ? Theme.text : Theme.muted)
                                .animation(reduceMotion() ? nil : .linear(duration: 0.15), value: near)
                                .frame(width: ws[k], height: height)
                                .contentShape(Rectangle().inset(by: -6))
                                .tap("chip:\(k)") { oval.glideTo(k) }
                                .accessibilityIdentifier("genre-" + key)
                                .accessibilityAddTraits(k == index ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                .frame(height: height)
                .background(GeometryReader { g in
                    Color.clear.onAppear { oval.contentFrame = g.frame(in: .global) }
                        .onChange(of: g.frame(in: .global)) { _, r in oval.contentFrame = r }
                })
            }
            .scrollDisabled(true)
            // on a narrow phone the row scrolls by itself to keep the oval in sight
            .onChange(of: near) { _, k in withAnimation(reduceMotion() ? nil : .easeOut(duration: 0.2)) { reader.scrollTo(Self.keys[k]) } }
        }
        .frame(height: height)
        .background(GeometryReader { g in
            Color.clear.onAppear { oval.rowFrame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, r in oval.rowFrame = r }
        })
        .onAppear {
            oval.chosen = { [weak model] in Self.keys.firstIndex(of: model?.genre ?? "all") ?? 0 }
            oval.choose = { [weak model] k in if let model, model.genre != Self.keys[k] { model.genre = Self.keys[k] } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.tr("genre"))
    }

    /// the row tells the oval where every genre is (plain values: nothing is redrawn by this)
    private func sync(_ ws: [CGFloat], _ cs: [CGFloat]) {
        if oval.widths != ws { oval.widths = ws }
        if oval.centres != cs { oval.centres = cs }
    }

    /// the oval's width blended between the two chips it is between; the chip it is nearest to is lit
    private func shape(_ c: CGFloat, _ ws: [CGFloat], _ cs: [CGFloat]) -> (CGFloat, Int) {
        let x = min(cs.last!, max(cs.first!, c))
        var i = 0
        while i < cs.count - 2 && x > cs[i + 1] { i += 1 }
        let f = (x - cs[i]) / (cs[i + 1] - cs[i])
        return (ws[i] + (ws[i + 1] - ws[i]) * f, f > 0.5 ? i + 1 : i)
    }
}
