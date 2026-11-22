import SwiftUI
import UIKit

/// Favourites (template.html favourites()): the liked stories as wide rows under their genres. Swipe a row left: it
/// follows the finger and a red "Remove" stretches out behind it; past 60% (or a tap on Remove) the story goes, and
/// everything below glides up into its place. Nothing liked yet: a small picture acts out how to like a story.
struct FavouritesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var rows = FavRows()

    var body: some View {
        let groups = Shelf.favourites(model.stories, favs: model.favs)
        Group {
            if groups.isEmpty {
                EmptyFavourites().id("empty")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groups, id: \.genre) { g in
                            SectionLabel(text: model.genreName(g.genre).uppercased(with: Locale(identifier: model.lang)))
                                .opacity(rows.fadedLabels.contains(g.genre) ? 0 : 1)
                            ForEach(g.stories) { s in
                                FavRow(story: s, rows: rows)
                            }
                        }
                        HintText(text: model.tr("swipe"))
                    }
                    .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 24)
                    .background(ScrollFinder { rows.attach($0) })
                }
            }
        }
        .onAppear { rows.model = model; rows.listen() }
        .onDisappear { rows.unlisten() }
    }
}

/// The rows' swipes (one finger, one row), which row stands open, which are on their way out.
@MainActor
final class FavRows: ObservableObject {
    weak var model: AppModel?
    @Published var x: [String: CGFloat] = [:]
    @Published var removing: Set<String> = []
    @Published var fadedLabels: Set<String> = []
    /// each row's place on screen
    var frames: [String: CGRect] = [:]

    private let pan = HeldPan()
    private var dragID: String? = nil
    private var base: CGFloat = 0, vx = 0.0, lastX: CGFloat = 0, lastT = 0.0
    private(set) var moved: Set<String> = []

    static let snapCurve = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)

    func attach(_ sv: UIScrollView) {
        sv.alwaysBounceVertical = true                    // however few stories, the page springs (IDEAS «Избранное»)
        pan.attach(sv)
        pan.begins = { [weak self] m in MainActor.assumeIsolated { self?.begins(m) ?? false } }
        pan.changed = { [weak self] m in MainActor.assumeIsolated { self?.drag(m) } }
        pan.ended = { [weak self] m, c in MainActor.assumeIsolated { self?.end(m, cancelled: c) } }
    }

    /// as on iPhone: with a row's "Remove" open, the next touch anywhere else (another row, an empty spot, a scroll)
    /// only closes it — nothing under that touch opens
    func listen() {
        Taps.shared.onDown["fav"] = { [weak self] p in
            guard let self, let m = self.model, m.tab == "fav", m.previewID == nil, m.chat == nil else { return }
            guard let open = self.x.first(where: { $0.value != 0 && !self.removing.contains($0.key) })?.key else { return }
            if self.frames[open]?.contains(p) == true { return }        // its own face closes it with its tap; Remove removes
            self.snap(open, 0)
            Taps.shared.eatThisTouch()
        }
    }
    func unlisten() { Taps.shared.onDown["fav"] = nil; pan.detach() }

    func set(_ id: String, _ v: CGFloat) { x[id] = v }
    func snap(_ id: String, _ v: CGFloat) { withAnimation(Self.snapCurve) { x[id] = v } }

    private func begins(_ m: HeldPan.Move) -> Bool {
        guard abs(m.translation.x) > abs(m.translation.y) else { return false }       // up or down: the list scrolls
        guard let id = frames.first(where: { $0.value.contains(m.start) })?.key, !removing.contains(id) else { return false }
        dragID = id; base = x[id] ?? 0; vx = 0; lastX = m.location.x; lastT = m.time
        moved.insert(id)
        return true
    }

    private func drag(_ m: HeldPan.Move) {
        guard let id = dragID else { return }
        let dt = (m.time - lastT) * 1000
        if dt > 0 { vx = 0.7 * vx + 0.3 * Double(m.location.x - lastX) / dt }
        lastX = m.location.x; lastT = m.time
        set(id, CGFloat(RowSwipe.x(base: Double(base), dx: Double(m.translation.x))))
    }

    private func end(_ m: HeldPan.Move, cancelled: Bool) {
        guard let id = dragID else { return }
        dragID = nil
        DispatchQueue.main.async { self.moved.remove(id) }
        if cancelled { snap(id, 0); return }                                // the phone took the touch: nothing is removed without a lift
        let w = Double(frames[id]?.width ?? 357)
        switch RowSwipe.end(x: Double(x[id] ?? 0), width: w, vx: vx, idle: (m.time - lastT) * 1000) {
        case .remove: remove(id)
        case .open: snap(id, -CGFloat(RowSwipe.open + RowSwipe.gap))
        case .shut: snap(id, 0)
        }
    }

    /// the card slides away; if it was the last of its genre, the genre's heading fades with it; then everything below
    /// glides up into the space
    func remove(_ id: String) {
        guard let model, !removing.contains(id), let s = model.story(id) else { return }   // a second tap on "Remove" never puts the story back
        removing.insert(id)
        snap(id, -((frames[id]?.width ?? 357) + CGFloat(RowSwipe.gap)))
        // rows already on their way out do not count: the second of two quick removals takes the genre heading
        let left = model.stories.filter { model.favs.contains($0.id) && $0.genre == s.genre && !removing.contains($0.id) }
        if left.isEmpty { withAnimation(.linear(duration: 0.2)) { _ = fadedLabels.insert(s.genre) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, let model = self.model else { return }
            let onScreen = model.tab == "fav"
            withAnimation(onScreen ? Self.snapCurve : nil) {
                model.toggleFav(id, want: false)
                self.frames[id] = nil
            }
            self.x[id] = nil
            self.fadedLabels.remove(s.genre)
            self.removing.remove(id)
        }
    }
}

struct FavRow: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    @ObservedObject var rows: FavRows

    var body: some View {
        let x = rows.x[story.id] ?? 0
        let w = CGFloat(RowSwipe.buttonWidth(Double(x))), lab = RowSwipe.label(Double(x))
        let f = Double(model.percent(story)) / 100
        let _ = model.progressRev
        face(f)
            .offset(x: x)
            .background(alignment: .trailing) {
                if w > 0 {
                    Text(model.tr("remove")).font(AppFont.ui(16, 600)).foregroundStyle(.white)
                        .fixedSize()
                        .opacity(lab.opacity).scaleEffect(lab.scale)
                        .frame(width: w).frame(maxHeight: .infinity)
                        .background(Theme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                        .tap("remove:" + story.id) { rows.remove(story.id) }
                }
            }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { rows.frames[story.id] = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, r in rows.frames[story.id] = r }
        })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(story.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.previewID = story.id }
        .accessibilityAction(named: Text(model.tr("remove"))) { rows.remove(story.id) }
    }

    private func face(_ f: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title).font(AppFont.ui(24, 600)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            MetaLine(story: story, size: 13, tracking: 0.04)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background {
            GeometryReader { g in
                CoverImage(file: story.cover)
                    .frame(width: g.size.width * 0.6, height: g.size.height)
                    .offset(x: g.size.width * 0.4)
                LinearGradient(stops: [.init(color: Theme.deep, location: 0.42), .init(color: Theme.deep(0), location: 0.85)],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
        .overlay(alignment: .bottom) { if f > 0 { ProgressLine(id: story.id, fraction: f) } }
        .background(Theme.deep)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .tap("row:" + story.id) {
            if rows.removing.contains(story.id) || rows.moved.contains(story.id) { return }
            if (rows.x[story.id] ?? 0) != 0 { rows.snap(story.id, 0); return }
            Taps.shared.openTap()
            model.previewID = story.id
        }
    }
}

/// Nothing liked yet. The picture acts out adding a favourite, once each time the page appears: all four squares the
/// same; one is held, it grows a little, sinks under the finger, settles, and the heart appears in its corner — the
/// circle pops, a pen draws the heart, the ink fills it (the app's own favourite move).
struct EmptyFavourites: View {
    @EnvironmentObject var model: AppModel
    @State private var born = Date()
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if reduceMotion() { picture(at: 1) }
                else {
                    TimelineView(.animation) { tl in
                        picture(at: min(1, max(0, (tl.date.timeIntervalSince(born) - 0.35) / 1.8)))
                    }
                }
            }
            .frame(width: 265, height: 225)
            .modifier(EmptyIn(shown: shown, delay: 0))
            .accessibilityHidden(true)
            Text(model.tr("emptyT")).font(AppFont.ui(20, 700)).foregroundStyle(.white).multilineTextAlignment(.center)
                .padding(.top, 20)
                .modifier(EmptyIn(shown: shown, delay: 0.1))
            Text(model.tr("emptyS")).font(AppFont.ui(16)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .padding(.top, 16)
                .modifier(EmptyIn(shown: shown, delay: 0.18))
        }
        .padding(.horizontal, 18).padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { born = Date(); shown = true }
    }

    /// the SVG of template.html (viewBox -22 -2 132 112), `t`: how far the 1.8 s act has got
    private func picture(at t: Double) -> some View {
        let app = CubicBezier.app, ease = CubicBezier.ease, out = CubicBezier.easeOut
        let sq = keyframes(t, [(0, 0.714), (0.06, 0.714), (0.28, 1.03), (0.36, 1), (0.58, 1), (0.82, 0.714), (1, 0.714)], ease: app)
        let lit = keyframes(t, [(0, 0), (0.06, 0), (0.28, 1), (1, 1)], ease: ease)
        let badge = keyframes(t, [(0, 0), (0.36, 0), (0.41, 1.12), (0.44, 1), (1, 1)], ease: out)
        let badgeOn = keyframes(t, [(0, 0), (0.36, 0), (0.37, 1), (1, 1)], ease: out)
        let pen = CubicBezier(0.45, 0.05, 0.35, 1)
        let drawn = 1 - keyframes(t, [(0, 1), (0.385, 1), (0.39, 0.97), (0.51, 0), (1, 0)], ease: pen)
        let penOn = keyframes(t, [(0, 0), (0.385, 0), (0.39, 1), (1, 1)], ease: pen)
        let ink = keyframes(t, [(0, 0), (0.47, 0), (0.58, 1), (1, 1)], ease: out)
        let inkScale = keyframes(t, [(0, 0.6), (0.47, 0.6), (0.58, 1), (1, 1)], ease: out)
        let grey = Color(hex: 0x5f5b7d)
        let u: CGFloat = 265.0 / 132.0
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ r: CGFloat, _ c: Color) -> some View {
            RoundedRectangle(cornerRadius: r * u, style: .circular).fill(c)
                .frame(width: w * u, height: w * u).position(x: (x + 22 + w / 2) * u, y: (y + 2 + w / 2) * u)
        }
        let heartW = 24 * 0.437 * u
        return ZStack(alignment: .topLeading) {
            rect(0, 20, 40, 8, grey)
            rect(0, 68, 40, 8, grey)
            rect(48, 68, 40, 8, grey)
            // the held square and its badge scale together about the square's bottom left corner (48, 60)
            ZStack(alignment: .topLeading) {
                rect(48, 4, 56, 10.3, Color(.sRGB, red: lerp(0x5f, 0xa7, lit) / 255, green: lerp(0x5b, 0xa3, lit) / 255, blue: lerp(0x7d, 0xbb, lit) / 255))
                    .shadow(color: .black.opacity(0.35), radius: 3 * u * sq, x: 0, y: 3 * u * sq)
                ZStack {
                    Circle().fill(Theme.accent)
                    ZStack {
                        SVGShape(d: IconPath.heart).fill(.white).opacity(ink).scaleEffect(inkScale, anchor: UnitPoint(x: 0.5, y: 0.6))
                        SVGShape(d: IconPath.heart).trim(from: 0, to: drawn)
                            .stroke(.white, style: StrokeStyle(lineWidth: 1.9 * 0.437 * u, lineCap: .round, lineJoin: .round)).opacity(penOn)
                    }
                    .frame(width: heartW, height: heartW)
                    .offset(x: (85.92 + 12 * 0.437 - 91.17) * u, y: (11.37 + 12 * 0.437 - 16.83) * u)
                }
                .frame(width: 9.74 * 2 * u, height: 9.74 * 2 * u)
                .scaleEffect(badge).opacity(badgeOn)
                .position(x: (91.17 + 22) * u, y: (16.83 + 2) * u)
            }
            .frame(width: 265, height: 225, alignment: .topLeading)
            .scaleEffect(sq, anchor: UnitPoint(x: (48 + 22) * u / 265, y: (60 + 2) * u / 225))
        }
        .frame(width: 265, height: 225, alignment: .topLeading)
    }
}

/// emptyIn: each line of the empty page comes in (0.6 s): fades, rises 10 px, grows from .98
private struct EmptyIn: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        let on = shown || reduceMotion()
        content.opacity(on ? 1 : 0).offset(y: on ? 0 : 10).scaleEffect(on ? 1 : 0.98)
            .animation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.6).delay(delay), value: shown)
    }
}
