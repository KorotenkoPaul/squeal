import SwiftUI
import UIKit

/// The app's state, shared by every screen (the web prototype's globals: LANG, STORIES, tab, genre, favs, store).
@MainActor
final class AppModel: ObservableObject {
    let library: StoryLibrary
    let store: Store

    @Published private(set) var lang: String
    @Published private(set) var stories: [Story] = []
    @Published var tab: String { didSet { store.set("tab", tab) } }
    @Published var genre: String = "all"
    @Published private(set) var favs: [String]
    /// bumped whenever saved progress changes, so every screen redraws its bars
    @Published private(set) var progressRev = 0
    /// the story whose preview is open
    @Published var previewID: String? = nil
    /// the chat on screen (stage 1: a placeholder)
    @Published var chat: ChatRoute? = nil

    let slider = SliderClock()

    init(library: StoryLibrary = .bundled(), store: Store = Store()) {
        self.library = library
        self.store = store
        lang = store.lang.flatMap { L10n.text[$0] != nil ? $0 : nil } ?? L10n.firstLanguage()
        tab = ["home", "fav", "search", "menu"].contains(store.tab) ? store.tab : "home"
        favs = store.favs
        stories = library.stories(lang)
    }

    func setLang(_ l: String) {
        lang = L10n.text[l] != nil ? l : "en"
        store.set("lang", lang)
        stories = library.stories(lang)
    }

    func tr(_ key: String, _ vars: [String: String] = [:]) -> String { L10n.tr(lang, key, vars) }
    func genreName(_ g: String) -> String { tr(g) }

    func story(_ id: String) -> Story? { stories.first { $0.id == id } }
    var english: [Story] { library.stories("en") }

    // MARK: favourites
    func isFav(_ id: String) -> Bool { favs.contains(id) }
    /// `want`: the state the reader asked for, as seen on screen
    func toggleFav(_ id: String, want: Bool? = nil) {
        let on = want ?? !favs.contains(id)
        let f = store.favs
        favs = on ? (f.contains(id) ? f : f + [id]) : f.filter { $0 != id }
        store.setFavs(favs)
        Haptics.tap()                                  // like or unlike, from any screen: one light tap
    }

    // MARK: progress
    func prog(_ s: Story) -> Progress { Reading.prog(s, raw: store.progressRaw(s.id), liveEp: chat?.storyID == s.id ? chat?.ep : nil) }
    func percent(_ s: Story) -> Int { Reading.percent(s, prog(s)) }
    func setProg(_ s: Story, _ p: Progress) { store.set("p:" + s.id, p.saved(v: s.v)); progressRev += 1 }
    func resetAll(_ s: Story) { store.set("p:" + s.id, ["ep": 0, "pos": s.parts.map { _ in 0 }]); progressRev += 1 }
    func minutes(_ s: Story) -> String { tr("min", ["n": String(Reading.storyMinutes(s))]) }

    // MARK: top of the week
    var topOfWeek: [Story] {
        TopWeek.top(stories, english: english, counts: TopWeek.counts(store.raw("reads"), week: TopWeek.weekKey()))
    }

    // MARK: opening a story
    func openStory(_ id: String, part: Int?, from: Edge = .trailing) {
        guard let s = story(id) else { return }
        TopWeek.countRead(id, store: store)            // one opening, one read (BUGS #121)
        let p = prog(s)
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)) {
            chat = ChatRoute(storyID: id, ep: part ?? Reading.nextPart(s, p), from: from)
        }
    }
}

struct ChatRoute: Equatable {
    let storyID: String
    var ep: Int
    var from: Edge
}

/// The slider's own clock: it lives outside the home screen, so coming back to Home it is where it has got to (BUGS #2).
final class SliderClock {
    var at = 0
    var elapsed: Double = 0
    var seen: Date? = nil
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// a growing buzz while the reset ring fills (0.3 s), from faint to strong
    static func ramp(_ seconds: Double, token: @escaping () -> Bool) {
        let n = 6
        for k in 0..<n {
            let at = seconds * (1 - pow(1 - Double(k) / Double(n), 1.6))
            DispatchQueue.main.asyncAfter(deadline: .now() + at) {
                guard token() else { return }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.2 + 0.8 * Double(k) / Double(n - 1))
            }
        }
    }
}
