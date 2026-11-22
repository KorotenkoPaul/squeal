import SwiftUI

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
                    case "fav": PlaceholderTab(title: model.tr("tabFav"))
                    case "search": PlaceholderTab(title: model.tr("search"))
                    case "menu": MenuPlaceholder()
                    default: HomeView(clock: model.slider, scrollTo: homeScroll)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                TabBar()
            }
            if let id = model.previewID, let s = model.story(id) {
                PreviewView(story: s).id(id)
                    .zIndex(1)
            }
            if let c = model.chat, let s = model.story(c.storyID) {
                ChatScreen(model: model, story: s, route: c)
                    .id(c.token)
                    .zIndex(2)
            }
        }
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
            .onTapGesture { model.tab = key }
            .accessibilityElement().accessibilityLabel(model.tr(label))
            .accessibilityAddTraits(model.tab == key ? [.isButton, .isSelected] : .isButton)
    }
}

/// Favourites and Search come in stage 3 of ios/PLAN.md.
struct PlaceholderTab: View {
    let title: String
    var body: some View {
        Text(title).font(AppFont.ui(20, 600)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Menu (stage 3); for now just the language list, so every language can be seen.
struct MenuPlaceholder: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 44) {
            ForEach(L10n.langNames, id: \.0) { code, name in
                Text(name).font(AppFont.ui(20, 600)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .overlay(alignment: .trailing) {
                        if model.lang == code {
                            StrokeIcon(paths: ["M4.5 12.5l5 5L20 7"], width: 2.6, size: 18).foregroundStyle(Theme.me).offset(x: 20)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { model.setLang(code) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
