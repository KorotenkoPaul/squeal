import SwiftUI

/// Home: "Top this week" slider, the genre oval, and the 2-column grid of stories.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var engine: SliderEngine
    @State private var gridGenre: String = "all"
    @State private var gridShown = true
    @State private var rise = false
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
            ScrollViewReader { reader in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                    if let y = scrollTo {      // screenshots: a mark `scrollTo` points down the page
                        VStack(spacing: 0) { Color.clear.frame(width: 1, height: y); Color.clear.frame(width: 1, height: 1).id("shot") }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text(model.tr("top").uppercased())
                            .font(AppFont.ui(13, 700)).tracking(13 * 0.06).foregroundStyle(Theme.muted)
                            .padding(.top, 6)
                        TopSlider(engine: engine, stories: top, width: W, inset: side)
                            .padding(.horizontal, -side)
                        SliderDots(engine: engine, n: top.count)
                            .padding(.top, -2)
                        GenreChips()
                        grid(tileW)
                            .id("grid")
                        Text(model.tr("pull"))
                            .font(AppFont.ui(13)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                        Color.clear.frame(height: 0).id("end")
                    }
                    .padding(.horizontal, side)
                    .padding(.top, 18).padding(.bottom, 24)
                    }
                }
                .onAppear {
                    if scrollTo != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reader.scrollTo("shot", anchor: .top) } }
                }
            }
            .onAppear { engine.start(count: top.count); engine.covered = covered; engine.frozen = ProcessInfo.processInfo.arguments.contains("-still"); gridGenre = model.genre }
            .onDisappear { engine.stop() }
            .onChange(of: covered) { _, c in engine.covered = c }
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
