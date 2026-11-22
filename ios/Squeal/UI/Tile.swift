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
        return CGSize(width: w, height: y + line)
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
        if before == f { shown = target; return }
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
                    .contentShape(Rectangle().inset(by: -10))
                    .onTapGesture { unlikeByTap() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .scaleEffect(pressing ? 0.96 : beat)
        .animation(.timingCurve(0.25, 0.8, 0.25, 1, duration: pressing ? 0.5 : 0.3), value: pressing)
        .onTapGesture { model.previewID = story.id }
        .onLongPressGesture(minimumDuration: 0.38, maximumDistance: 8, perform: holdLike, onPressingChanged: { pressing = $0 })
        .onAppear { badge = model.isFav(story.id) }
        .onChange(of: model.favs) { _, f in
            let on = f.contains(story.id)
            if motion == .still, on != badge { badge = on }     // changed elsewhere (the preview): no second animation (BUGS #51)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(story.title)
    }

    /// hold: like (the card swells, the badge pops and the heart is drawn) or unlike (the heart cracks)
    private func holdLike() {
        pressing = false
        model.toggleFav(story.id, want: !badge)
        let on = model.isFav(story.id)
        playBeat(on)
        token += 1; let my = token
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
