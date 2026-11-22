import SwiftUI

/// Home: "Top this week" slider, the genre oval, and the 2-column grid of stories.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var engine: SliderEngine
    @State private var gridGenre: String = "all"
    @State private var gridShown = true
    @State private var rise = false
    @State private var pulls = HomePulls()
    @State private var fresh = 1.0
    var scrollTo: CGFloat? = nil                 // screenshots: start scrolled this far down

    init(clock: SliderClock, scrollTo: CGFloat? = nil) {
        _engine = StateObject(wrappedValue: SliderEngine(clock: clock))
        self.scrollTo = scrollTo
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, side: CGFloat = 18
            let top = model.topOfWeek
            let tileW = (W - 2 * side - 12) / 2
            ZStack(alignment: .top) {
            OwlEyes(pulls: pulls, textTop: 18 + 6 + (18 - 13 * 0.7) / 2)
            HomeShift(pulls: pulls) {
            ScrollViewReader { reader in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                    if let y = scrollTo {      // screenshots: a mark `scrollTo` points down the page
                        VStack(spacing: 0) { Color.clear.frame(width: 1, height: y); Color.clear.frame(width: 1, height: 1).id("shot") }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text(model.tr("top").uppercased(with: Locale(identifier: model.lang)))
                            .font(AppFont.ui(13, 700)).tracking(13 * 0.06).foregroundStyle(Theme.muted)
                            .padding(.top, 6)
                            .opacity(fresh)
                        TopSlider(engine: engine, stories: top, width: W, inset: side)
                            .padding(.horizontal, -side)
                            .opacity(fresh)
                        SliderDots(engine: engine, n: top.count)
                            .padding(.top, -2)
                            .opacity(fresh)
                        GenreChips()                   // the genre row stays put through a refresh: the chosen genre never blinks
                        grid(tileW)
                            .id("grid")
                            .opacity(fresh)
                        PullHint(pulls: pulls)
                            .opacity(fresh)
                    }
                    .padding(.horizontal, side)
                    .padding(.top, 18).padding(.bottom, 24)
                    .background(ScrollFinder { pulls.attach($0) })
                    }
                }
                .onAppear {
                    if scrollTo != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reader.scrollTo("shot", anchor: .top) } }
                }
            }
            }
            ReelView(pulls: pulls)
            }
            .onAppear {
                pulls.model = model; pulls.height = g.size.height
                let a = LaunchArgs(ProcessInfo.processInfo.arguments)
                let pose = (a.value("-pull").flatMap { Double($0) }, a.value("-reel").flatMap { Double($0) })
                if pose.0 != nil || pose.1 != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { pulls.pose(pull: pose.0, reel: pose.1) } }
            }
            .onChange(of: g.size.height) { _, h in pulls.height = h }
            .onDisappear { pulls.detach() }
            .onReceive(pulls.$pulling) { p in engine.covered = covered || p }
            // fresh content fades in right where it is (0.3 s): nothing rides up at the end
            .onChange(of: model.refreshRev) { _, _ in
                fresh = 0
                withAnimation(.easeOut(duration: 0.3)) { fresh = 1 }
            }
            .onAppear { engine.start(count: top.count); engine.covered = covered; engine.frozen = ProcessInfo.processInfo.arguments.contains("-still"); gridGenre = model.genre }
            .onDisappear { engine.stop() }
            .onChange(of: covered) { _, c in engine.covered = c || pulls.pulling }
            .onChange(of: top.map(\.id)) { _, ids in engine.start(count: ids.count) }
            .onChange(of: model.genre) { _, g in swapGrid(g) }
        }
    }

    private var covered: Bool { model.previewID != nil || model.chat != nil || model.tab != "home" }

    @ViewBuilder private func grid(_ tileW: CGFloat) -> some View {
        let list = model.stories.filter { gridGenre == "all" || $0.genre == gridGenre }
        LazyVGrid(columns: [GridItem(.fixed(tileW), spacing: 12), GridItem(.fixed(tileW), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(list) { s in
                TileView(story: s, width: tileW)
                    .opacity(rise ? 0 : 1)
                    .offset(y: rise ? 18 : 0)
            }
        }
        .opacity(gridShown ? 1 : 0)
    }

    /// a genre change swaps only the grid: old tiles fade (0.12 s), new ones rise in (0.32 s); the slider is not touched
    private func swapGrid(_ g: String) {
        withAnimation(.easeIn(duration: 0.12)) { gridShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { gridGenre = g; gridShown = true; rise = true }
            withAnimation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.32)) { rise = false }
        }
    }
}

/// The page under the two pulls: down with the owl's eyes, up with the reel.
struct HomeShift<Content: View>: View {
    @ObservedObject var pulls: HomePulls
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(Theme.bg)
            .offset(y: pulls.down - pulls.lift)
    }
}

/// One line of words under the cards, always in the same place: pull up… → keep pulling → release
struct PullHint: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var pulls: HomePulls
    var body: some View { HintLine(text: model.tr(pulls.hintKey)) }
}
