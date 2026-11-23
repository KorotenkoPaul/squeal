import SwiftUI
import UIKit

/// The app shell: the tab's page over the indigo background, the tab bar (Home, Favourites, Search, Menu),
/// and the story page and chat over everything.
struct RootView: View {
    @EnvironmentObject var model: AppModel
    var homeScroll: CGFloat? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Group {
                    switch model.tab {
                    case "fav": FavouritesView()
                    case "search": SearchView()
                    case "menu": MenuView()
                    default: HomeView(clock: model.slider, scrollTo: homeScroll)
                    }
                }
                .id(model.tabRev)                      // a tap on a tab draws its page afresh, the tab you are on too (the web's render())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                TabBar()
                    .zIndex(6)
            }
            .ignoresSafeArea(.keyboard)                // the keyboard comes up over the page: nothing is squeezed
            if let text = model.toast {
                ToastLine(text: text)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 84)
                    .zIndex(1)
            }
            if let id = model.previewID, let s = model.story(id) {
                PreviewView(story: s).id(id)
                    .zIndex(2)
            }
            if let c = model.chat, let s = model.story(c.storyID) {
                ChatScreen(model: model, story: s, route: c)
                    .id(c.token)
                    .zIndex(3)
            }
        }
        .overlay(alignment: .topLeading) { if TouchProbe.on { TouchProbe() } }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: model.lang))
    }
}

struct TabBar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            item("home", "tabHome") { Icons.home(26) }
            item("fav", "tabFav") { Icons.heart(26) }
            item("search", "tabSearch") { Icons.search(26) }
            item("menu", "tabMenu") { Icons.menu(26) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.tabbar.ignoresSafeArea(edges: .bottom))
    }

    private func item<I: View>(_ key: String, _ label: String, @ViewBuilder icon: () -> I) -> some View {
        icon()
            .foregroundStyle(model.tab == key ? Theme.text : Theme.tabOff)
            .padding(6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .tap("tab:" + key) { model.show(tab: key) }
            .accessibilityElement().accessibilityLabel(model.tr(label))
            .accessibilityIdentifier("tab-" + key)
            .accessibilityAction { model.show(tab: key) }
            .accessibilityAddTraits(model.tab == key ? [.isButton, .isSelected] : .isButton)
    }
}

/// UI tests only (-uitest 1): one invisible element whose value says what the app knows — how many touches the
/// window watcher has seen (so a broken watcher fails a test, not a reader), and the saved state the tests check.
struct TouchProbe: View {
    @EnvironmentObject var model: AppModel
    static let on = ProcessInfo.processInfo.arguments.contains("-uitest")
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            Color.clear.frame(width: 2, height: 2)
                .accessibilityElement()
                .accessibilityIdentifier("probe")
                .accessibilityLabel("probe")
                .accessibilityValue(text)
        }
        .allowsHitTesting(false)
    }
    private var text: String {
        let chat = model.chat.map { $0.storyID + ":" + String($0.ep) } ?? "-"
        return ["touches=" + String(Taps.shared.seen), "watching=" + (UIWindow.watchesTouches ? "1" : "0"),
                "tab=" + model.tab, "lang=" + model.lang, "genre=" + model.genre, "fear=" + String(model.fearLevel),
                "favs=" + model.favs.joined(separator: ","), "premium=" + (model.store.premium ? "1" : "0"),
                "taps=" + String(model.store.taps), "pv=" + (model.previewID ?? "-"), "chat=" + chat].joined(separator: ";")
    }
}

/// CI only (-letterings <page>): four slider cards per page, every story in turn, to check each title's lettering.
struct LetteringPages: View {
    @EnvironmentObject var model: AppModel
    let page: Int
    var body: some View {
        GeometryReader { g in
            let W = g.size.width - 36
            VStack(spacing: 14) {
                ForEach(Array(model.stories.dropFirst(page * 4).prefix(4))) { s in
                    HeroCard(story: s, size: CGSize(width: W, height: 190))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}
