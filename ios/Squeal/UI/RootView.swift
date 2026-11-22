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
                ChatPlaceholder(story: s, route: c)
                    .transition(.move(edge: c.from))
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

/// Stage 2 builds the chat; "Read" opens this empty stand-in, sliding in from the right (or from below on a swipe up).
struct ChatPlaceholder: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    let route: ChatRoute
    var body: some View {
        let part = story.parts[min(route.ep, story.parts.count - 1)]
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("‹").font(AppFont.ui(30)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .onTapGesture { back() }
                    .accessibilityLabel(model.tr("back"))
                Circle().fill(Theme.accent).frame(width: 38, height: 38)
                    .overlay(Text(String(part.left.prefix(1))).font(AppFont.ui(16, 700)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 0) {
                    Text(part.left).font(AppFont.ui(16, 600)).foregroundStyle(.white).lineLimit(1)
                    Text(model.tr("online")).font(AppFont.ui(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Theme.tabbar)
            Spacer()
            Text(part.prologue).font(AppFont.ui(13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .background(Theme.bg.ignoresSafeArea())
        .shadow(color: .black.opacity(0.35), radius: 20, x: -20)
        .onAppear {
            // the story page under the chat is gone: back returns to the screen the story was opened from (BUGS #12)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { if model.chat != nil { model.previewID = nil } }
        }
    }

    private func back() {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)) { model.chat = nil }
    }
}
