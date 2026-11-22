import SwiftUI
import QuartzCore
import UIKit

/// The "Top this week" slider: full-width cards that turn by themselves every 4 s (always one step right), can be
/// swiped both ways round and round (copies of the last and first card sit at the ends), and a "worm" in the dots
/// whose white line runs out the time to the next card (template.html startSlider; IDEAS.md «Слайдер»).
@MainActor
final class SliderEngine: ObservableObject {
    static let slideTime = 4.0

    /// position in cards: 0 = first card; -1 = the copy of the last before it; n = the copy of the first after the last
    @Published var pos: Double = 0
    /// the white line in the pill: time run out on the current card, 0...1
    @Published var fill: Double = 0
    private(set) var at = 0                    // the card the clock belongs to
    var n = 1
    var held = false                           // a finger is on the slider
    var covered = false                        // a preview or chat is over Home, or another tab is shown
    var dragging = false

    private var elapsed: Double = 0
    private var tween: (from: Double, to: Double, t0: CFTimeInterval, dur: Double, curve: CubicBezier)? = nil
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var lastPos: Double = 0, stillSince: CFTimeInterval = 0
    private let clock: SliderClock

    init(clock: SliderClock) { self.clock = clock }

    /// Home shows: start where the slider has got to meanwhile (its clock kept running), from the very first frame.
    func start(count: Int) {
        n = max(1, count)
        if let seen = clock.seen {
            let total = clock.elapsed + max(0, Date().timeIntervalSince(seen))
            at = (clock.at + Int(total / Self.slideTime)) % n
            elapsed = total.truncatingRemainder(dividingBy: Self.slideTime)
        } else { at = 0; elapsed = 0 }
        pos = Double(at); tween = nil
        fill = elapsed / Self.slideTime
        last = CACurrentMediaTime()
        if link == nil {
            let l = CADisplayLink(target: DisplayTarget(self), selector: #selector(DisplayTarget.tick))
            l.add(to: .main, forMode: .common)
            link = l
        }
    }

    func stop() { link?.invalidate(); link = nil; save() }

    private func save() { clock.at = at; clock.elapsed = elapsed; clock.seen = Date() }

    // MARK: finger
    private var dragFrom: Double = 0
    func dragBegan() { tween = nil; dragFrom = pos; dragging = true }
    func drag(_ dx: CGFloat, step: CGFloat) {
        guard step > 0 else { return }
        pos = min(Double(n), max(-1, dragFrom - Double(dx / step)))
    }
    func dragEnded(predicted dx: CGFloat, step: CGFloat) {
        dragging = false
        guard step > 0 else { return }
        let target = (dragFrom - Double(dx / step)).rounded()
        let to = min(dragFrom.rounded() + 1, max(dragFrom.rounded() - 1, target))
        glide(to: min(Double(n), max(-1, to)), dur: 0.35, curve: .sheet)
    }

    func cardIndex(at x: Double) -> Int { ((Int(x.rounded()) % n) + n) % n }

    private func glide(to: Double, dur: Double, curve: CubicBezier) {
        tween = (pos, to, CACurrentMediaTime(), dur, curve)
    }

    fileprivate func tick(_ now: CFTimeInterval) {
        let dt = now - last
        last = now
        if let tw = tween {
            let t = min(1, (now - tw.t0) / tw.dur)
            pos = tw.from + (tw.to - tw.from) * tw.curve(t)
            if t >= 1 { tween = nil }
        }
        // on a copy, once no finger holds it, quietly jump to the real card (they look the same)
        if !held && !dragging && tween == nil {
            if pos >= Double(n) - 0.001 { pos -= Double(n) } else if pos <= -0.999 { pos += Double(n) }
        }
        var p = pos < 0 ? pos + Double(n) : pos
        p = max(0, min(Double(n), p))
        let cur = Int(p.rounded()) % n
        let settled = abs(p - p.rounded()) < 0.02
        if cur != at && settled && !held && !dragging { at = cur; elapsed = 0 }
        // guard: never left resting between two cards (BUGS #1)
        if pos != lastPos { lastPos = pos; stillSince = now }
        else if !held && !dragging && !settled && tween == nil && now - stillSince > 0.3 { stillSince = now; glide(to: pos.rounded(), dur: 0.3, curve: .sheet) }
        let busy = covered || held || dragging || !settled || tween != nil || UIApplication.shared.applicationState != .active
        if !busy && dt < 0.25 { elapsed += dt }
        let t = max(0, min(1, elapsed / Self.slideTime))
        if settled && !busy && t >= 1 && n > 1 {
            elapsed = 0
            glide(to: pos.rounded() + 1, dur: 0.5, curve: .easeInOut)           // always one step right
        }
        fill = t
        save()
    }
}

private final class DisplayTarget: NSObject {
    weak var engine: SliderEngine?
    init(_ e: SliderEngine) { engine = e; super.init() }
    @objc func tick(_ l: CADisplayLink) { MainActor.assumeIsolated { engine?.tick(l.targetTimestamp) } }
}

struct TopSlider: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var engine: SliderEngine
    let stories: [Story]
    let width: CGFloat              // the screen's width: cards run edge to edge
    let inset: CGFloat              // side margin of a card (18)

    @GestureState private var touching = false
    @State private var axis: Bool? = nil           // true: sideways (ours)
    @State private var downCard: Int? = nil

    var body: some View {
        let cardW = width - 2 * inset, step = cardW + inset, n = stories.count
        ZStack(alignment: .topLeading) {
            ForEach(-1...n, id: \.self) { k in
                let s = stories[((k % n) + n) % n]
                let x = inset + (CGFloat(k) - CGFloat(engine.pos)) * step
                if x > -cardW - step && x < width + step {
                    HeroCard(story: s, size: CGSize(width: cardW, height: 190), pressing: touching && downCard == ((k % n) + n) % n)
                        .offset(x: x)
                        .accessibilityHidden(k < 0 || k >= n)
                }
            }
        }
        .frame(width: width, height: 190, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, st, _ in st = true }
                .onChanged { v in
                    if downCard == nil { downCard = engine.cardIndex(at: engine.pos) }
                    if axis == nil && (abs(v.translation.width) > 8 || abs(v.translation.height) > 8) {
                        axis = abs(v.translation.width) > abs(v.translation.height)
                        if axis == true { engine.dragBegan() }
                    }
                    if axis == true { engine.drag(v.translation.width, step: step) }
                }
                .onEnded { v in
                    if axis == true { engine.dragEnded(predicted: v.predictedEndTranslation.width, step: step) }
                    else if axis == nil, let k = downCard { model.previewID = stories[k].id }   // a tap opens the card the finger came down on (BUGS #128)
                    axis = nil; downCard = nil
                })
        .onChange(of: touching) { _, t in
            engine.held = t
            // the touch was taken away (no onEnded): let go anyway, after onEnded had its chance
            if !t { DispatchQueue.main.async { if axis == true { engine.dragEnded(predicted: 0, step: step) }; axis = nil; downCard = nil } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.tr("top5"))
    }
}

struct HeroCard: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    let size: CGSize
    var pressing = false
    var body: some View {
        ZStack {
            CoverImage(file: story.cover)
            LinearGradient(stops: [.init(color: Theme.deep(0.95), location: 0.10), .init(color: Theme.deep(0), location: 0.75)], startPoint: .bottom, endPoint: .top)
            HeroLettering(id: story.id, title: story.title, lang: model.lang, card: size)
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.deep)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(pressing ? 0.96 : 1)
        .animation(.timingCurve(0.25, 0.8, 0.25, 1, duration: pressing ? 0.5 : 0.3), value: pressing)
        .accessibilityLabel(story.title)
        .accessibilityAddTraits(.isButton)
    }
}

/// The dots: a "worm" pill stretches its head to the next dot as the slide moves, then pulls its tail after it;
/// across last ⇄ first it does not crawl back: the pill shrinks while the far dot grows (template.html frame()).
struct SliderDots: View {
    @ObservedObject var engine: SliderEngine
    let n: Int
    private let W: CGFloat = 22, DOT: CGFloat = 6, GAP: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            let m = layout(g.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(0..<n, id: \.self) { k in
                    Capsule().fill(m.dotColor[k]).frame(width: m.ws[k], height: 6).offset(x: m.L[k])
                }
                Capsule().fill(Color(hex: 0x5d5888))
                    .overlay(alignment: .leading) {
                        Capsule().fill(LinearGradient(colors: [Color(hex: 0xb9a3ff), .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: m.fill)
                            .shadow(color: Color(red: 185 / 255, green: 163 / 255, blue: 1, opacity: 0.65), radius: 5)
                    }
                    .clipShape(Capsule())
                    .frame(width: m.right - m.left, height: 6)
                    .offset(x: m.left)
                    .opacity(m.wormOpacity)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private struct M { var ws: [CGFloat]; var L: [CGFloat]; var left: CGFloat; var right: CGFloat; var fill: CGFloat; var wormOpacity: Double; var dotColor: [Color] }

    private func layout(_ boxW: CGFloat) -> M {
        let nn = Double(n), raw = engine.pos, at = engine.at
        let unwrapped: Double = raw < 0 ? raw + nn : raw
        let p: Double = max(0, min(nn, unwrapped))
        let wrap = p > nn - 1
        let i = n > 1 ? min(n - 2, Int(min(p, nn - 1))) : 0
        let f = n > 1 ? min(p, nn - 1) - Double(i) : 0
        var ws: [CGFloat] = []
        for k in 0..<n {
            let near: Double = 1 - abs(p - Double(k))
            let wrapNear: Double = k == 0 ? 1 - abs(p - nn) : 0
            let share: Double = max(0, near, wrapNear)
            ws.append(DOT + (W - DOT) * CGFloat(share))
        }
        let gaps: CGFloat = GAP * CGFloat(n - 1)
        let total: CGFloat = ws.reduce(0, +) + gaps
        var L: [CGFloat] = [], R: [CGFloat] = []
        var x = (boxW - total) / 2
        for w in ws { L.append(x); R.append(x + w); x += w + GAP }
        let kc = at == 0 ? 0 : n - 1
        let dotColor = (0..<n).map { k -> Color in
            guard wrap && (k == n - 1 || k == 0) else { return Color(hex: 0x4a4670) }
            let share: Double = k == 0 ? p - (nn - 1) : nn - p
            return mix(Color(hex: 0x5d5888), Color(hex: 0x4a4670), share)
        }
        let edgeShare: Double = kc == 0 ? p - (nn - 1) : nn - p
        let wormOpacity: Double = wrap ? max(0, min(1, edgeShare / 0.15)) : 1
        var right: CGFloat = R[0], left: CGFloat = L[0]
        if wrap { right = R[kc]; left = L[kc] }
        else if n > 1 {
            let head = CGFloat(min(1, f * 2)), tail = CGFloat(max(0, f * 2 - 1))
            right = R[i] + (R[i + 1] - R[i]) * head
            left = L[i] + (L[i + 1] - L[i]) * tail
        }
        let wrapAway: Double = at == 0 ? abs(nn - p) : 1
        let away: Double = min(1, abs(p - Double(at)), wrapAway)
        let fillW: CGFloat = W * CGFloat(engine.fill * (1 - away))
        return M(ws: ws, L: L, left: left, right: right, fill: fillW, wormOpacity: wormOpacity, dotColor: dotColor)
    }

    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca: [CGFloat] = UIColor(a).cgColor.components ?? [0, 0, 0, 1]
        let cb: [CGFloat] = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
        let u = CGFloat(max(0, min(1, t))), v = 1 - u
        let r: CGFloat = ca[0] * u + cb[0] * v
        let g: CGFloat = ca[1] * u + cb[1] * v
        let bl: CGFloat = ca[2] * u + cb[2] * v
        return Color(red: Double(r), green: Double(g), blue: Double(bl))
    }
}
