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
    /// the chat on screen
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
    /// (a part of 3 messages or fewer keeps its count only while it is the part open in the chat — and not on its way out)
    func prog(_ s: Story) -> Progress {
        let live = chat.flatMap { $0.storyID == s.id && $0.live ? $0.ep : nil }
        return Reading.prog(s, raw: store.progressRaw(s.id), liveEp: live)
    }
    func percent(_ s: Story) -> Int { Reading.percent(s, prog(s)) }
    func setProg(_ s: Story, _ p: Progress) { store.set("p:" + s.id, p.saved(v: s.v)); progressRev += 1 }
    func resetAll(_ s: Story) { store.set("p:" + s.id, ["ep": 0, "pos": s.parts.map { _ in 0 }]); progressRev += 1 }
    func minutes(_ s: Story) -> String { tr("min", ["n": String(Reading.storyMinutes(s))]) }

    // MARK: top of the week
    var topOfWeek: [Story] {
        TopWeek.top(stories, english: english, counts: TopWeek.counts(store.raw("reads"), week: TopWeek.weekKey()))
    }

    // MARK: opening a story
    /// The chat of a story comes up over everything (ChatScreen): `part` nil = carry on where the reader is.
    func openStory(_ id: String, part: Int?, from: Edge = .trailing) {
        guard let s = story(id) else { return }
        let recent = [id] + store.strings("recent").filter { $0 != id }
        store.set("recent", Array(recent.prefix(3)))
        if chat?.storyID != id || chat?.live != true { TopWeek.countRead(id, store: store) }   // one opening, one read (BUGS #121)
        let p = prog(s)
        chat = ChatRoute(storyID: id, ep: part ?? Reading.nextPart(s, p), asked: part, from: from)
    }

    /// the open chat shows this part now (it alone keeps a count of 3 messages or fewer)
    func chatShows(part: Int) {
        guard var c = chat else { return }
        c.ep = part; c.live = true
        chat = c
    }

    /// the chat is on its way out: its part's progress counts as any other's from this moment
    func chatLeaves() {
        guard var c = chat else { return }
        c.live = false
        chat = c
        progressRev += 1
    }

    /// the chat has slid away (unless another one was opened meanwhile)
    func chatGone(_ token: UUID?) {
        if chat?.token == token { chat = nil }
        progressRev += 1
    }
}

struct ChatRoute: Equatable {
    let storyID: String
    var ep: Int
    /// the part asked for (nil: carry on)
    var asked: Int? = nil
    var from: Edge
    /// its conversation is up and it is not leaving
    var live = false
    let token = UUID()
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
