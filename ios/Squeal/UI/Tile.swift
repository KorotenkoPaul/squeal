import SwiftUI
import UIKit

/// flex-wrap row (the tile's pills)
struct FlowRow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, w: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > maxW { y += line + spacing; x = 0; line = 0 }
            x += z.width + spacing; line = max(line, z.height); w = max(w, x - spacing)
        }
        return CGSize(width: maxW.isFinite ? maxW : w, height: y + line)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + z.width > bounds.maxX { y += line + spacing; x = bounds.minX; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; line = max(line, z.height)
        }
    }
}

struct Pill: View {
    let text: String
    var body: some View {
        Text(text).font(AppFont.ui(11)).foregroundStyle(Theme.muted)
            .padding(.top, 4).padding(.bottom, 2).padding(.horizontal, 8)
            .background(Capsule().fill(Color(red: 52 / 255, green: 49 / 255, blue: 90 / 255, opacity: 0.85)))
    }
}

struct PadPill: View {
    var label: String
    var body: some View {
        Icons.pad(17).foregroundStyle(Theme.muted)
            .padding(.vertical, 3).padding(.horizontal, 8)
            .background(Capsule().fill(Color(red: 52 / 255, green: 49 / 255, blue: 90 / 255, opacity: 0.85)))
            .accessibilityLabel(label)
    }
}

/// Progress on a cover: one thin line along the bottom; it fills (0.9 s) only when the progress is new to the eye (BUGS #122).
final class BarMemory { static var seen: [String: Double] = [:] }

struct ProgressLine: View {
    let id: String
    let fraction: Double                  // 0...1
    var height: CGFloat = 3
    @State private var shown: Double = -1
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.12))
                Rectangle().fill(Theme.line).frame(width: g.size.width * max(0, shown))
            }
        }
        .frame(height: height)
        .onAppear { arrive(fraction) }
        .onChange(of: fraction) { _, f in arrive(f) }
    }
    private func arrive(_ f: Double) {
        let target = max(0.03, f)
        let before = BarMemory.seen[id]
        BarMemory.seen[id] = f
        if before == f || reduceMotion() { shown = target; return }     // (Reduce Motion: the line is simply there)
        if shown < 0 { shown = 0 }
        if let before, before > 0 {
            withAnimation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.6)) { shown = target }
        } else {
            withAnimation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.9).delay(0.15)) { shown = target }
        }
    }
}

/// A title with a word wider than its card is set a little smaller (17 px, step 0.5, not below 11), so every word fits whole.
func fittedTitleSize(_ title: String, width: CGFloat, start: CGFloat = 17, weight: Int = 600) -> CGFloat {
    let words = title.split(separator: " ").map(String.init)
    var f = start
    while f > 11 {
        let font = AppFont.uiFont(f, weight)
        let widest = words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        if widest <= width + 0.5 { break }
        f -= 0.5
    }
    return f
}

struct TileView: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    let width: CGFloat

    @State private var badge = false
    @State private var motion: HeartMotion = .still
    @State private var pressing = false
    @State private var beat: Double = 1
    @State private var token = 0
    /// the touch on the card right now: on the heart badge (its own tap), moved too far to be a tap or a hold,
    /// held long enough to have liked
    private struct Press { var heart = false, moved = false, fired = false }
    @State private var press: Press? = nil
    @State private var holdToken = 0

    var body: some View {
        let height = width * 1.15
        let f = Double(model.percent(story)) / 100
        let _ = model.progressRev
        ZStack(alignment: .bottomLeading) {
            CoverImage(file: story.cover)
            LinearGradient(stops: [.init(color: Theme.deep(0.96), location: 0.15), .init(color: Theme.deep(0.05), location: 0.70)],
                           startPoint: .bottom, endPoint: .top)
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(AppFont.ui(fittedTitleSize(story.title, width: width - 24), 600))
                    .foregroundStyle(.white)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                FlowRow(spacing: 6) {
                    Pill(text: model.genreName(story.genre))
                    Pill(text: model.minutes(story))
                    if story.interactive { PadPill(label: model.tr("interactive")) }
                }
            }
            .padding(12)
            if f > 0 {
                ProgressLine(id: story.id, fraction: f).frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: width, height: height)
        .background(Theme.deep)
        .overlay(alignment: .topTrailing) {
            if badge {
                HeartBadge(box: 39, heart: 21, circle: Theme.accent, motion: motion)
                    .padding(9)
                    .allowsHitTesting(false)            // its tap is read by the card's own press (onHeart below)
            }
        }
        // Tap opens; hold (0.38 s without moving more than 8 pt) likes or unlikes — exactly the web's longPress(): the
        // card sinks while it is held, a drag is neither a tap nor a hold, and the page scrolls under it natively.
        // The finger is read by UIKit (PressSurface), as a button in a scroll view is: a SwiftUI drag gesture on the
        // card kept the page from scrolling on iOS 26 (BUGS #169), and a tap and a long-press recogniser side by side
        // proved unreliable inside a scroll view (the UI tests' hold never liked).
        .overlay {
            PressSurface(began: { p, late in fingerDown(at: p, late: late) },
                         moved: { t in fingerMoved(t) },
                         ended: { cancelled in fingerUp(cancelled: cancelled) })
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .scaleEffect(pressing ? 0.96 : beat)
        .animation(.timingCurve(0.25, 0.8, 0.25, 1, duration: pressing ? 0.5 : 0.3), value: pressing)
        .onAppear { badge = model.isFav(story.id) }
        .onChange(of: model.favs) { _, f in
            let on = f.contains(story.id)
            if motion == .still, on != badge { badge = on }     // changed elsewhere (the preview): no second animation (BUGS #51)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(model.isFav(story.id) ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(story.title)
        .accessibilityValue(f >= 1 ? model.tr("readAll") : f > 0 ? model.tr("pctRead", ["n": String(model.percent(story))]) : "")
        .accessibilityIdentifier("tile-" + story.id)
        .accessibilityAction { model.previewID = story.id }
        // VoiceOver cannot hold a card: the like is an action of its own
        .accessibilityAction(named: Text(model.tr("favourite"))) { model.toggleFav(story.id) }
    }

    // MARK: the finger (PressSurface)

    private func fingerDown(at p: CGPoint, late: Double) {
        // on the heart badge (its finger-sized target): the badge's own tap unlikes, the card stays still
        let onHeart = badge && p.x > width - 68 && p.y < 68
        press = Press(heart: onHeart)
        holdToken += 1
        guard !onHeart else { return }
        pressing = true
        let my = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, 0.38 - late)) {
            guard holdToken == my, let p = press, !p.moved, !p.heart, !p.fired else { return }
            press?.fired = true
            holdLike()
        }
    }

    private func fingerMoved(_ t: CGSize) {
        guard press?.moved == false, hypot(t.width, t.height) > 8 else { return }
        press?.moved = true; holdToken += 1                    // a drag is not a long press
        pressing = false
    }

    /// lifted: a tap opens the card (or, on the badge, unlikes); taken away (the page scrolled, the phone): nothing
    private func fingerUp(cancelled: Bool) {
        let p = press
        press = nil; holdToken += 1; pressing = false
        guard !cancelled, let p, !p.moved, !p.fired else { return }
        if p.heart {
            if Taps.shared.allows("fav:" + story.id) { unlikeByTap() }
        } else if Taps.shared.allows("tile:" + story.id) {
            Taps.shared.openTap(); model.previewID = story.id
        }
    }

    /// hold: like (the card swells, the badge pops and the heart is drawn) or unlike (the heart cracks)
    private func holdLike() {
        pressing = false
        guard Taps.shared.allows("tile:" + story.id) else { return }
        model.toggleFav(story.id, want: !badge)
        let on = model.isFav(story.id)
        token += 1; let my = token
        if reduceMotion() { motion = .still; badge = on; return }      // no swell, no drawing, no crack: the heart is on or off
        playBeat(on)
        if on {
            badge = true; motion = .draw(Date(), 390)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { if token == my { motion = .still } }
        } else {
            motion = .crack(Date(), 320, fadeBadge: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) { if token == my { motion = .still; badge = model.isFav(story.id) } }
        }
    }

    /// a tap on the heart itself unlikes; the card stays still and does not open
    private func unlikeByTap() {
        guard motion == .still || model.isFav(story.id) else { return }
        if model.isFav(story.id) { model.toggleFav(story.id, want: false) }
        token += 1; let my = token
        if reduceMotion() { motion = .still; badge = false; return }
        motion = .crack(Date(), 200, fadeBadge: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) { if token == my { motion = .still; badge = model.isFav(story.id) } }
    }

    /// favBeat: .96 → 1.08 (like) / 1.03 (unlike) → 1, 0.48 s, cubic-bezier(.3,1.2,.5,1)
    private func playBeat(_ on: Bool) {
        beat = 0.96
        withAnimation(.timingCurve(0.3, 1.2, 0.5, 1, duration: 0.19)) { beat = on ? 1.08 : 1.03 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            withAnimation(.timingCurve(0.3, 1.2, 0.5, 1, duration: 0.29)) { beat = 1 }
        }
    }
}
