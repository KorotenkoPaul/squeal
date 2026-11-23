import XCTest
import UIKit
import Combine
@testable import Squeal

/// Stage 4 (the pass over BUGS.md): the checks the web's builder makes on the stories, repeated on what the app
/// really bundles; every story opening in every saved state; broken saves; the wallpaper's falls; the tap watcher's
/// safeguards; the pieces of UI logic changed in this stage.
final class Stage4Tests: XCTestCase {
    static let library = LogicTests.library

    // MARK: - the stories themselves (BUGS #16, #17, #33, #58, #162)

    private func allMessages(_ p: Part) -> [Message] {
        p.messages + (p.nodes ?? [:]).values.flatMap { $0.messages }
    }

    func testStoryTextIsClean() {
        for lang in StoryLibrary.langs {
            for s in Self.library.stories(lang) {
                let at = "\(s.id) [\(lang)]"
                XCTAssertFalse(s.title.trimmingCharacters(in: .whitespaces).isEmpty, at)
                for (k, p) in s.parts.enumerated() {
                    XCTAssertNotEqual(p.left, p.right, "the two sides have one name, \(at) part \(k + 1)")
                    var texts = allMessages(p).map(\.text)
                    texts += (p.nodes ?? [:]).values.flatMap { ($0.choices ?? []).map(\.text) }
                    for m in allMessages(p) {
                        XCTAssertTrue(m.from == p.left || m.from == p.right, "unknown speaker \(m.from), \(at) part \(k + 1)")
                        XCTAssertFalse(m.voice != nil && m.video != nil, "a message is both voice and video, \(at)")
                    }
                    for t in texts + [p.prologue, s.description, s.title] {
                        XCTAssertFalse(t.contains("|") || t.contains("\\!"), "markup left in a text, \(at): \(t.prefix(40))")
                        let odd = t.unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) || $0.value >= 0xF0000 }
                        XCTAssertFalse(odd, "a private-use character (shows as a box on a phone), \(at): \(t.prefix(40))")
                    }
                    for t in texts { XCTAssertFalse(t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "an empty message, \(at) part \(k + 1)") }
                }
            }
        }
    }

    func testStoryShape() {
        var ids = Set<String>()
        for s in Self.library.stories("en") { XCTAssertTrue(ids.insert(s.id).inserted, "two stories share the id \(s.id)") }
        for lang in StoryLibrary.langs {
            let stories = Self.library.stories(lang)
            XCTAssertEqual(stories.count, ids.count, "every story is there in \(lang)")
            for s in stories {
                let at = "\(s.id) [\(lang)]"
                XCTAssertTrue(["horror", "thriller", "romance"].contains(s.genre), "unknown genre, \(at)")
                XCTAssertTrue((1...5).contains(s.fear), "fear is not 1…5, \(at)")
                XCTAssertFalse(s.parts.isEmpty, at)
                XCTAssertNotNil(s.cover, "no cover, \(at)")
                if let c = s.cover {
                    let url = Bundle(for: AppModel.self).resourceURL!.appendingPathComponent("covers/" + c)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "the cover's file is missing: \(c)")
                }
                for (k, p) in s.parts.enumerated() {
                    XCTAssertFalse(p.messages.isEmpty, "a part without messages, \(at) part \(k + 1)")
                    guard let nodes = p.nodes else { continue }
                    XCTAssertTrue(s.interactive, "a part with branches in a story not marked interactive, \(at)")
                    guard let start = p.start, nodes[start] != nil else { XCTFail("the start of an interactive part is missing, \(at)"); continue }
                    var seen = Set<String>(), todo = [start]
                    while let id = todo.popLast() {
                        guard seen.insert(id).inserted, let n = nodes[id] else { continue }
                        let choices = n.choices ?? [], ending = !(n.ending ?? "").isEmpty
                        XCTAssertNotEqual(!choices.isEmpty, ending, "a branch must either offer answers or be an ending, \(at) \(id)")
                        for c in choices {
                            XCTAssertNotNil(nodes[c.next], "an answer leads to a branch that is not there: \(c.next), \(at)")
                            todo.append(c.next)
                        }
                    }
                    XCTAssertEqual(seen.count, nodes.count, "a branch no answer leads to, \(at)")
                    // the part's own list of messages is its longest path (progress is counted against it)
                    var memo: [String: Int] = [:]
                    func far(_ id: String, _ depth: Int) -> Int {
                        if let m = memo[id] { return m }
                        guard depth < 200, let n = nodes[id] else { return 0 }
                        let rest = (n.choices ?? []).map { 1 + far($0.next, depth + 1) }.max() ?? 0
                        memo[id] = n.messages.count + rest
                        return memo[id]!
                    }
                    XCTAssertEqual(far(start, 0), p.messages.count, "the part's messages are not its longest path, \(at)")
                }
            }
        }
    }

    func testWallpaperNamesExist() {
        for lang in StoryLibrary.langs {
            for s in Self.library.stories(lang) {
                for (k, p) in s.parts.enumerated() {
                    let names = p.wallpaper + (p.wallpaperEndings ?? [:]).values.flatMap { $0 }
                    for n in names { XCTAssertNotNil(DoodleData.all[n], "no doodle called \(n): \(s.id) [\(lang)] part \(k + 1)") }
                }
            }
        }
    }

    // MARK: - every story opens, whatever is saved (BUGS #6, #30, #31, #113)

    func testEveryStoryOpensInEveryState() {
        let defaults = UserDefaults(suiteName: "squeal-stage4-open")!
        var opened = 0
        for lang in StoryLibrary.langs {
            for s in Self.library.stories(lang) {
                let half = s.parts.map { $0.messages.count / 2 }
                let full = s.parts.map { $0.messages.count }
                let halfRead: [String: Any] = ["ep": 0, "pos": half, "v": s.v]
                let allRead: [String: Any] = ["ep": s.parts.count - 1, "pos": full, "v": s.v]
                let olderText: [String: Any] = ["ep": 0, "pos": half, "v": "an-older-text"]
                let gonePath: [String: Any] = ["ep": 0, "pos": half, "path": ["no-such-branch", "nor-this"], "v": s.v]
                let wrongKinds: [String: Any] = ["ep": "a", "pos": "b"]
                let outOfRange: [String: Any] = ["ep": 99, "pos": [99999, -3, "q"] as [Any], "path": 5]
                // never opened; half read; read to the end; read before the story was changed; a path of branches that
                // are gone; old or broken saves
                let saves: [Any?] = [nil, halfRead, allRead, olderText, gonePath, 7, "x", wrongKinds, outOfRange]
                for save in saves {
                    defaults.removePersistentDomain(forName: "squeal-stage4-open")
                    let store = Store(defaults)
                    if let save { store.set("p:" + s.id, save) }
                    for part in [nil] + s.parts.indices.map({ Optional($0) }) {
                        let io = ChatReader.IO.store(store, s) { nil }
                        let r = ChatReader(story: s, part: part, progress: io.prog(), io: io)
                        XCTAssertTrue(s.parts.indices.contains(r.ep))
                        XCTAssertTrue((0...r.messages.count).contains(r.i), "\(s.id) [\(lang)]")
                        // a few steps on: taps, and the first answer at a choice
                        for _ in 0..<6 {
                            switch r.foot {
                            case .tap: if case .theirs = r.begin() { r.arrived() }
                            case .ask: if case .mine = r.pick(0), r.replyComesByItself, case .theirs = r.begin(free: true) { r.arrived() }
                            case .end, .paywall: break
                            }
                        }
                        let p = io.prog()
                        XCTAssertTrue((0...100).contains(Reading.percent(s, p)))
                        XCTAssertTrue(s.parts.indices.contains(Reading.nextPart(s, p)))
                        r.stop()
                        opened += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(opened, 1000)
    }

    @MainActor func testBrokenSavesAreIgnored() {
        let defaults = UserDefaults(suiteName: "squeal-stage4-broken")!
        let junk: [Any] = [7, "x", true, ["a": 1] as [String: Any], [1, 2, ["x"]] as [Any], [String: Any](), NSNull()]
        for (n, j) in junk.enumerated() {
            defaults.removePersistentDomain(forName: "squeal-stage4-broken")
            let store = Store(defaults)
            for key in ["favs", "tab", "lang", "premium", "taps", "reads", "recent", "p:clown", "p:two-knocks"] { store.set(key, j) }
            if n == 0 { defaults.set("{not json", forKey: "squeal:favs"); defaults.set("", forKey: "squeal:lang") }
            let m = AppModel(library: Self.library, store: store)
            XCTAssertFalse(m.stories.isEmpty)
            XCTAssertTrue(["home", "fav", "search", "menu"].contains(m.tab))
            XCTAssertNotNil(L10n.text[m.lang])
            XCTAssertFalse(m.topOfWeek.isEmpty)
            for s in m.stories { XCTAssertTrue((0...100).contains(m.percent(s))) }
            XCTAssertTrue(Shelf.favourites(m.stories, favs: m.favs).allSatisfy { !$0.stories.isEmpty })
            m.toggleFav("clown", want: true)
            XCTAssertTrue(m.isFav("clown"))
            m.openStory("two-knocks", part: nil)
            XCTAssertEqual(m.chat?.storyID, "two-knocks")
            m.toggleSubscription(); m.toggleSubscription()
        }
        defaults.removePersistentDomain(forName: "squeal-stage4-broken")
    }

    /// A language is never changed with a chat open (there is no way to Menu from one); if it ever were, the chat —
    /// built from the old language's messages — and the story page are simply dropped.
    @MainActor func testALanguageChangeDropsAnOpenChat() {
        let defaults = UserDefaults(suiteName: "squeal-stage4-lang")!
        defaults.removePersistentDomain(forName: "squeal-stage4-lang")
        let m = AppModel(library: Self.library, store: Store(defaults))
        m.previewID = "clown"
        m.openStory("clown", part: nil)
        XCTAssertNotNil(m.chat)
        m.setLang("de")
        XCTAssertNil(m.chat); XCTAssertNil(m.previewID)
        XCTAssertEqual(m.lang, "de")
        XCTAssertEqual(m.story("clown")?.title, Self.library.stories("de").first { $0.id == "clown" }?.title)
        defaults.removePersistentDomain(forName: "squeal-stage4-lang")
    }

    // MARK: - the wallpaper's doodles fall and fly (BUGS #62)

    private func spin(_ seconds: Double) {
        let e = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { e.fulfill() }
        wait(for: [e], timeout: seconds + 5)
    }

    func testAPartSwitchMakesTheOldDoodlesFallAndAChoiceOnlyTheClosedEndings() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled, "with Reduce Motion nothing falls")
        let en = Self.library.stories("en")
        let home = en.first { $0.id == "nobodys-home" }!
        let size = CGSize(width: 393, height: 700)
        let a = Doodles.config(home.parts[0]), b = Doodles.config(home.parts[1])
        let standing = Doodles.lay(a, seed: "nobodys-home:0", size: size, vis: nil).count
        XCTAssertGreaterThan(standing, 10)

        let wall = WallKeeper()
        wall.resize(size)
        wall.show(a, seed: "nobodys-home:0", vis: nil, switching: false, same: false)
        XCTAssertEqual(wall.pieces.count, standing)                    // all on their way in
        XCTAssertTrue(wall.still.isEmpty)
        spin(2.6)                                                       // they land; the plain wallpaper takes over
        XCTAssertTrue(wall.pieces.isEmpty)
        XCTAssertEqual(wall.still.count, standing)

        wall.show(b, seed: "nobodys-home:1", vis: nil, switching: true, same: false)
        let falling = wall.pieces.filter { $0.phase == .fall }
        XCTAssertEqual(falling.count, standing, "every doodle of the old part falls")
        XCTAssertTrue(wall.still.isEmpty)
        XCTAssertGreaterThan(wall.pieces.filter { $0.phase == .flyIn }.count, 10, "the new part's doodles are on their way")
        spin(4.5)
        XCTAssertTrue(wall.pieces.isEmpty, "all fallen, all landed")
        XCTAssertEqual(wall.still.count, Doodles.lay(b, seed: "nobodys-home:1", size: size, vis: nil).count)

        // interactive: a choice that closes off endings drops only those endings' doodles
        let knocks = en.first { $0.id == "two-knocks" }!
        let cfg = Doodles.config(knocks.parts[0])
        let endings = (cfg.endings ?? []).map(\.g)
        try XCTSkipIf(endings.count < 2, "the story has no doodles per ending")
        let all = Set(["*"] + endings), kept = Set(["*", endings[0]])
        let w2 = WallKeeper()
        w2.resize(size)
        w2.show(cfg, seed: "two-knocks:0", vis: all, switching: false, same: false)
        spin(2.6)
        XCTAssertTrue(w2.pieces.isEmpty)
        w2.setVis(kept)
        XCTAssertFalse(w2.pieces.isEmpty)
        XCTAssertTrue(w2.pieces.allSatisfy { $0.phase == .fall && !kept.contains($0.item.g) }, "only the closed endings' doodles fall")
        XCTAssertTrue(w2.still.allSatisfy { kept.contains($0.item.g) })
        w2.setVis(all)                                                  // back to the choice: they fly back in
        XCTAssertTrue(w2.pieces.contains { $0.phase == .flyIn })
    }

    // MARK: - the tap watcher's safeguards

    /// With no touch to judge by (the watcher missing or blind) every control simply works: no tap is ever lost.
    @MainActor func testWithNoTouchSeenEveryTapIsAllowed() {
        let t = Taps.shared
        t.reset()
        for name in ["tile:a", "read", "pv-like", "chat:again", "tab:fav", "remove:x", "tile:a", "read"] {
            XCTAssertTrue(t.allows(name), name)
        }
        XCTAssertTrue(t.allows(nil))
        XCTAssertNil(t.downPoint)
        t.closeTap(); t.openTap(); t.pin(); t.eatThisTouch()            // nothing to hang on to: all harmless
        XCTAssertTrue(t.allows("anything"))
        XCTAssertEqual(t.fingers, 0)
        t.reset()
    }

    func testTheWindowsSendEventIsOursAndStillUIKits() {
        XCTAssertTrue(UIWindow.watchesTouches)
        // exchanged, not replaced: the two selectors now run each other's code
        let a = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:)))!
        let b = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.squeal_sendEvent(_:)))!
        XCTAssertNotEqual(method_getImplementation(a), method_getImplementation(b))
        UIWindow.watchTouches()                                          // a second call changes nothing
        XCTAssertEqual(method_getImplementation(a), method_getImplementation(class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:)))!))
    }

    // MARK: - this stage's own pieces

    func testAVoiceBubbleIsAsWideAsItsCaptionWithinItsLimits() {
        let most: CGFloat = 278                                          // 78 % of a 393 pt phone's log
        XCTAssertEqual(VoiceBubble.contentWidth("Hi.", maxBubble: most), 230)
        XCTAssertEqual(VoiceBubble.contentWidth(String(repeating: "a long caption ", count: 12), maxBubble: most), most - 28)
        let mid = VoiceBubble.contentWidth("Wait. Do not open the door for them.", maxBubble: 400)
        XCTAssertTrue(mid >= 230 && mid <= 372)
        XCTAssertEqual(VoiceBubble.contentWidth("Hi.", maxBubble: 222), 194) // the smallest phone: the bubble's own limit wins
    }

    @MainActor func testTheGenreOvalFollowsTheFingerAndSettlesOnTheNearest() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let oval = GenreOval()
        oval.widths = [50, 80, 90, 100]
        oval.centres = [25, 98, 191, 294]                                // 8 pt apart
        oval.rowFrame = CGRect(x: 18, y: 300, width: 357, height: 33)
        oval.contentFrame = oval.rowFrame
        var genre = 0, picks: [Int] = []
        oval.chosen = { genre }
        oval.choose = { k in if genre != k { genre = k; picks.append(k) } }
        XCTAssertEqual(oval.at, 25); XCTAssertEqual(oval.nearest(), 0)
        XCTAssertEqual(oval.chip(at: CGPoint(x: 18 + 98, y: 310)), 1)
        XCTAssertNil(oval.chip(at: CGPoint(x: 18 + 54, y: 310)))         // between two
        XCTAssertNil(oval.chip(at: CGPoint(x: 18 + 98, y: 500)))

        // a sideways drag: 1:1 with the finger, never past the ends; let go — the nearest genre
        oval.dragBegan()
        oval.drag(60); XCTAssertEqual(oval.at, 85)
        oval.drag(-500); XCTAssertEqual(oval.at, 25)
        oval.drag(5000); XCTAssertEqual(oval.at, 294)
        oval.drag(150); XCTAssertEqual(oval.at, 175); XCTAssertEqual(oval.nearest(), 2)
        XCTAssertTrue(picks.isEmpty, "nothing is chosen while the finger is down")
        oval.dragEnded()
        XCTAssertEqual(picks, [2])

        // a touch that goes down first is the page's: the oval is not moved and nothing is chosen
        oval.down(at: CGPoint(x: 18 + 25, y: 310))
        oval.pageTookIt()
        oval.drag(-80)                                                   // (no drag was begun: ignored)
        XCTAssertEqual(picks, [2]); XCTAssertEqual(genre, 2)

        // a tap
        oval.glideTo(0)
        XCTAssertEqual(picks, [2, 0])
        spin(0.6)
        XCTAssertEqual(oval.pos, -1, "at rest it simply is the chosen genre's oval")
        XCTAssertEqual(oval.at, 25)
        // a language with other widths: it stands on its word at once
        oval.centres = [40, 130, 230, 340]
        XCTAssertEqual(oval.at, 40)
    }

    @MainActor func testTheSliderPublishesNothingWhileNothingChanges() {
        let clock = SliderClock()
        let engine = SliderEngine(clock: clock)
        engine.frozen = true
        engine.start(count: 5)
        var fired = 0
        let watch = engine.objectWillChange.sink { fired += 1 }
        spin(0.5)                                                        // thirty frames or so
        XCTAssertEqual(fired, 0, "covered or standing still, Home is not redrawn every frame (BUGS #126)")
        engine.frozen = false
        spin(0.3)
        if UIApplication.shared.applicationState == .active { XCTAssertGreaterThan(fired, 3, "running, the white line moves") }
        engine.stop()
        watch.cancel()
    }
}
