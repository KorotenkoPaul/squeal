import XCTest

/// The real app on the simulator, driven by real touches through its main flows (the only way to exercise gestures
/// without a phone): open a story and read, answers at a choice, an ending and back to a choice, like and unlike,
/// Favourites, Search, the language, the subscription and the paywall, the genre oval, the slider, the two pulls
/// of Home. Every test starts the app from a clean slate (`-reset 1`), in English, with the slider standing still.
final class FlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-reset", "1", "-still", "1", "-lang", "en", "-uitest", "1"] + extra
        app.launch()
    }

    // MARK: helpers

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func count(_ id: String) -> Int { app.descendants(matching: .any).matching(identifier: id).count }

    @discardableResult
    private func appear(_ id: String, _ timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(id) never appeared", file: file, line: line)
        return e
    }

    private func gone(_ id: String, _ timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        let e = el(id)
        let done = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: e)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: timeout), .completed, "\(id) is still there", file: file, line: line)
    }

    private func until(_ timeout: TimeInterval = 10, _ what: String, file: StaticString = #filePath, line: UInt = #line, _ test: () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if test() { return }; usleep(200_000) }
        XCTFail("never happened: " + what, file: file, line: line)
    }

    /// what the app itself says (see TouchProbe): "touches=3;tab=home;favs=a,b;…"
    private func probe() -> [String: String] {
        let v = (el("probe").value as? String) ?? ""
        var out: [String: String] = [:]
        for pair in v.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { out[kv[0]] = kv[1] } else if kv.count == 1 { out[kv[0]] = "" }
        }
        return out
    }

    private func tab(_ key: String) { appear("tab-" + key).tap() }

    /// a tap at an element's middle, by its place on screen (no question asked about what is "hittable" there)
    private func press(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        appear(id, file: file, line: line).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// a slow drag from one point of the screen to another (fractions of the window), the finger resting before it lifts
    private func drag(from a: CGVector, to b: CGVector, hold: TimeInterval = 0.3) {
        let w = app.windows.firstMatch
        w.coordinate(withNormalizedOffset: a).press(forDuration: 0.05, thenDragTo: w.coordinate(withNormalizedOffset: b), withVelocity: .slow, thenHoldForDuration: hold)
    }

    /// A real finger: down ON the element (a moment's rest), then straight up by `dy` points, resting before it lifts.
    /// (Not swipeUp(): the touch must begin on the element itself — that is where a gesture of the element's own can
    /// keep the page from scrolling, BUGS #169.)
    private func dragUp(_ e: XCUIElement, by dy: CGFloat) {
        let a = e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 0, dy: -dy)), withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// a vertical drag that starts on `start` moves the page up with the finger: `mark` (on the same page) goes up too
    private func scrolls(from start: XCUIElement, by dy: CGFloat, mark: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        let y0 = mark.frame.minY
        dragUp(start, by: dy)
        usleep(800_000)
        let moved = y0 - mark.frame.minY
        XCTAssertGreaterThan(moved, dy * 0.5, "a drag up that starts on \(what) did not scroll the page (it moved \(Int(moved)) pt of \(Int(dy)))", file: file, line: line)
        XCTAssertEqual(probe()["pv"], "-", "a drag up on \(what) opened a story", file: file, line: line)
    }

    /// the first element whose id starts with `prefix` and whose middle is between these fractions of the screen
    private func onScreen(_ prefix: String, between a: CGFloat, _ b: CGFloat) -> XCUIElement? {
        let h = app.windows.firstMatch.frame.height
        let all = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        return all.allElementsBoundByIndex.first { $0.exists && $0.frame.midY > h * a && $0.frame.midY < h * b && $0.frame.width > 40 }
    }

    // MARK: reading

    func testOpenAStoryReadAndComeBack() {
        launch()
        appear("tile-clown").tap()
        appear("pv-read")
        XCTAssertEqual(appear("pv-title").label, "Clown")
        XCTAssertEqual(probe()["pv"], "clown")
        el("pv-read").tap()
        let tap = appear("chat-tap")
        XCTAssertEqual(tap.label, "TAP TO CONTINUE")
        XCTAssertEqual(count("msg-them") + count("msg-me"), 0, "a new story opens with nothing read")
        // the window watcher saw the touches that got us here: the double-tap rule is live
        // (read before the chat's modal page hides the probe: asked through the chat's own status instead)
        usleep(700_000)                                         // the chat takes no tap for its first 0.5 s
        tap.tap()                                               // "Hello!" — the other side types first
        until(6, "the first message") { self.count("msg-them") == 1 }
        tap.tap()                                               // the reader's own: there at once
        until(4, "the reader's message") { self.count("msg-me") == 1 }
        tap.tap()
        until(6, "the third message") { self.count("msg-them") == 2 }
        tap.tap()
        until(6, "the fourth message") { self.count("msg-them") + self.count("msg-me") == 4 }
        // a tap on the conversation itself reads on too
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
        until(6, "the fifth message") { self.count("msg-them") + self.count("msg-me") == 5 }

        appear("chat-back").tap()
        gone("chat-tap")
        gone("pv-read", 3)                                      // back lands on Home, not on the story page
        XCTAssertTrue(appear("tile-clown").isHittable)
        XCTAssertEqual(probe()["chat"], "-")
        XCTAssertGreaterThan(Int(probe()["touches"] ?? "0") ?? 0, 5, "the window watcher is not seeing touches")
        XCTAssertEqual(probe()["watching"], "1")

        // what was read is still read
        el("tile-clown").tap()
        appear("pv-read").tap()
        appear("chat-tap")
        until(5, "the five messages are there again") { self.count("msg-them") + self.count("msg-me") == 5 }
        // the swipe from the left edge closes the chat
        drag(from: CGVector(dx: 0.0, dy: 0.5), to: CGVector(dx: 0.9, dy: 0.5), hold: 0)
        gone("chat-tap")
        XCTAssertTrue(appear("tile-clown").isHittable)
    }

    func testADoubleTapOnACardOnlyOpensItsPage() {
        launch()
        appear("tile-clown").doubleTap()
        appear("pv-read")
        sleep(1)
        XCTAssertFalse(el("chat-tap").exists, "the second tap of a double tap opened the chat")
        XCTAssertEqual(probe()["chat"], "-")
        // ✕ closes at a touch; a second tap there presses nothing under it
        el("pv-close").doubleTap()
        gone("pv-read")
        sleep(1)
        XCTAssertEqual(probe()["pv"], "-")
        XCTAssertEqual(probe()["tab"], "home")
    }

    func testAnswersAtAChoiceAndAnEndingAndBackToAChoice() {
        // the chat opens right at the first choice of the interactive story
        launch(["-chat", "two-knocks", "-pos", "16", "-path", "start"])
        appear("chat-ask")
        let first = appear("draft-1"), second = appear("draft-2")
        XCTAssertTrue(first.isHittable && second.isHittable)
        let mine = count("msg-me")
        usleep(800_000)                                         // (answers take no tap while they still come in)
        second.tap()
        gone("draft-1")
        until(4, "the answer is sent") { self.count("msg-me") == mine + 1 }
        XCTAssertFalse(el("draft-2").exists)
        // the other side answers by itself, a second on
        let theirs = count("msg-them")
        until(8, "the reply comes by itself") { self.count("msg-them") > theirs || self.el("chat-status").label != "online" }
        app.terminate()

        // an ending: its title, "Start over", and the way back to each choice made
        launch(["-chat", "two-knocks", "-pos", "37", "-path", "start,stay,hide"])
        let end = appear("chat-end")
        XCTAssertTrue(end.label.contains("Ending"), end.label)
        XCTAssertEqual(appear("chat-again").label, "START OVER")
        XCTAssertFalse(el("chat-next").exists)
        appear("chat-turn-2")
        usleep(700_000)
        appear("chat-turn-1").tap()                              // back to the first choice
        appear("chat-ask")
        appear("draft-1")
        XCTAssertFalse(el("chat-again").exists)
        // a quick second tap where the button stood picks nothing
        sleep(1)
        XCTAssertTrue(el("draft-1").exists && el("draft-2").exists)
    }

    func testPartsNextPartAndThePartDisc() {
        // a story of three parts, its first part read to the end
        launch(["-chat", "nobodys-home", "-part", "0", "-pos", "999"])
        XCTAssertEqual(appear("chat-again").label, "READ AGAIN")
        appear("chat-end")
        usleep(700_000)
        appear("chat-next").tap()
        appear("chat-tap")
        until(5, "part 2 is open") { self.el("disc-2").isSelected }
        XCTAssertTrue(el("disc-2").isSelected)
        // a tap on a number of the disc
        el("disc-3").tap()
        until(5, "part 3 is open") { self.el("disc-3").isSelected }
        el("disc-1").tap()
        until(5, "part 1 is open again") { self.el("disc-1").isSelected }
        appear("chat-again", 6)
    }

    // MARK: likes, Favourites

    func testLikeUnlikeAndFavourites() {
        launch()
        let tile = appear("tile-clown")
        XCTAssertFalse(tile.isSelected)
        tile.press(forDuration: 0.7)                              // hold a card: liked
        until(4, "liked by a hold") { self.probe()["favs"] == "clown" }
        XCTAssertFalse(el("pv-read").exists, "a hold must not open the card")
        tile.press(forDuration: 0.7)                              // hold again: unliked
        until(4, "unliked by a hold") { (self.probe()["favs"] ?? "") == "" }

        // the heart on the story page
        tile.tap()
        let heart = appear("pv-like")
        XCTAssertFalse(heart.isSelected)
        usleep(900_000)                                          // (a page just opened by a tap takes none at that place)
        press("pv-like")
        until(4, "liked on the story page") { self.el("pv-like").isSelected }
        el("pv-close").tap()
        gone("pv-read")
        XCTAssertEqual(probe()["favs"], "clown")
        // a second story, to have two rows
        appear("tile-nobodys-home").press(forDuration: 0.7)
        until(4, "two liked") { self.probe()["favs"] == "clown,nobodys-home" }

        tab("fav")
        let row = appear("fav-row-clown")
        appear("fav-row-nobodys-home")
        // swipe the row a third of its width to the left and rest: "Remove" stands open beside it
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.3)
        usleep(700_000)
        XCTAssertEqual(probe()["pv"], "-", "the swipe opened the story instead of moving the row")
        XCTAssertEqual(probe()["row"], "clown:-104", "the row did not stay open after the swipe")
        XCTAssertEqual(probe()["favs"], "clown,nobodys-home")
        // a touch anywhere else only closes it: nothing opens, nothing is removed
        el("fav-row-nobodys-home").coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        usleep(700_000)
        XCTAssertEqual(probe()["row"], "clown:0", "a touch elsewhere did not close the open row")
        XCTAssertEqual(probe()["pv"], "-", "the touch that closed an open row also opened a story")
        // open it again; a tap on "Remove" removes the story
        sleep(1)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.3)
        usleep(700_000)
        XCTAssertEqual(probe()["row"], "clown:-104")
        let w = app.windows.firstMatch.frame.width
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: (w - 18 - 48) / w, dy: row.frame.midY / app.windows.firstMatch.frame.height)).tap()
        let limit = Date().addingTimeInterval(4)
        while Date() < limit, probe()["favs"] != "nobodys-home" { usleep(200_000) }
        XCTAssertEqual(probe()["favs"], "nobodys-home", "Remove did not remove the story (row: \(probe()["row"] ?? "?"), page: \(probe()["pv"] ?? "?"))")
        gone("fav-row-clown")
        // a tap on a row opens its story page
        usleep(900_000)
        press("fav-row-nobodys-home")
        appear("pv-read")
        usleep(900_000)
        press("pv-like")                                         // unliked here: the row is gone when the page closes
        until(4, "unliked on the story page") { (self.probe()["favs"] ?? "x") == "" || !self.el("pv-like").isSelected }
        el("pv-close").tap()
        appear("fav-empty")
        tab("home")
        XCTAssertFalse(appear("tile-clown").isSelected)
    }

    // MARK: Search

    func testSearchFindsAndOpensAndCancelBringsTheFearRowBack() {
        launch()
        tab("search")
        let fear = appear("fear-row")
        XCTAssertEqual(fear.label, "Scary")
        fear.swipeLeft(velocity: .slow)                           // one name on: the next level
        until(4, "the fear level changed") { (self.probe()["fear"] ?? "3") != "3" }
        let field = appear("search-field")
        field.tap()
        appear("search-cancel")
        app.typeText("clown")
        appear("result-clown")
        XCTAssertFalse(el("result-nobodys-home").exists)
        el("result-clown").tap()
        appear("pv-read")
        XCTAssertEqual(el("pv-title").label, "Clown")
        el("pv-close").tap()
        gone("pv-read")
        appear("result-clown")                                   // what was typed is still there
        usleep(900_000)
        el("search-cancel").tap()
        gone("result-clown")
        until(4, "the fear row is back") { self.el("fear-row").exists && self.el("fear-row").isHittable }
        // nothing found
        el("search-field").tap()
        appear("search-cancel")
        app.typeText("xyzzyq")
        XCTAssertEqual(appear("search-hint").label, "Nothing found")
    }

    // MARK: Menu: language, subscription; the paywall

    func testLanguageAndSubscription() {
        launch()
        tab("menu")
        XCTAssertEqual(appear("menu-row-2").label, "Language")
        press("menu-row-2")
        until(4, "the languages show") { self.el("menu-row-1").label == "Deutsch" }
        XCTAssertTrue(el("menu-row-0").isSelected, "English carries the tick")
        sleep(1)                                                 // rows that just faded in take no tap yet
        press("menu-row-1")
        until(5, "the menu is back, in German") { self.el("menu-row-2").label == "Sprache" }
        XCTAssertEqual(probe()["lang"], "de")
        tab("home")
        appear("tile-clown").tap()
        XCTAssertEqual(appear("pv-read").label, "Lesen")
        el("pv-close").tap()

        tab("menu")
        sleep(1)
        XCTAssertEqual(probe()["premium"], "1")
        press("menu-row-0")                                      // Subscription: the demo switch
        XCTAssertTrue(appear("toast").label.hasPrefix("Demo"))
        XCTAssertEqual(probe()["premium"], "0")
        XCTAssertEqual(probe()["taps"], "100")
    }

    func testAFreeReaderHitsThePaywall() {
        launch(["-premium", "0", "-taps", "2", "-chat", "clown"])
        let tap = appear("chat-tap")
        usleep(700_000)
        tap.tap()
        until(6, "first free message") { self.count("msg-them") == 1 }
        tap.tap()
        until(4, "second free message") { self.count("msg-me") == 1 }
        // no taps left: the paywall takes the hint's place — and no counter was ever shown
        let pay = appear("chat-pay", 5)
        XCTAssertFalse(el("chat-tap").exists)
        XCTAssertEqual(count("msg-them") + count("msg-me"), 2)
        sleep(1)
        pay.tap()
        appear("toast")
        // the conversation takes no more taps either
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        sleep(2)
        XCTAssertEqual(count("msg-them") + count("msg-me"), 2)
    }

    // MARK: Home: genres, the slider, the two pulls

    func testGenresAndTheSlider() {
        launch()
        appear("tile-nobodys-home")                               // horror
        appear("genre-romance").tap()
        until(4, "romance is chosen") { self.probe()["genre"] == "romance" }
        gone("tile-nobodys-home")
        appear("tile-clinical-love")
        // drag the oval sideways, back towards "All": it settles on a genre, and the page did not move with it
        let row = el("genre-romance")
        let from = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: appear("genre-all").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)), withVelocity: .slow, thenHoldForDuration: 0.2)
        until(4, "the oval was dragged to All") { self.probe()["genre"] == "all" }
        appear("tile-nobodys-home")
        XCTAssertTrue(el("genre-all").isHittable, "the page moved under the oval's drag")

        // the slider: a swipe turns it to the next card, a tap opens the card on screen
        let heroes = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'hero-'"))
        until(5, "the slider is there") { heroes.count > 0 }
        func front() -> String? {
            let mid = app.windows.firstMatch.frame.midX
            return heroes.allElementsBoundByIndex.first { $0.exists && abs($0.frame.midX - mid) < 40 }?.identifier
        }
        guard let before = front() else { return XCTFail("no card in the middle of the slider") }
        // across most of the card (a short slow move that stops half way comes back, as it should)
        let card = el(before)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)), withVelocity: .default, thenHoldForDuration: 0)
        until(5, "the slider turned") { front() != nil && front() != before }
        let now = front()!
        el(now).tap()
        appear("pv-read")
        XCTAssertEqual(probe()["pv"], String(now.dropFirst("hero-".count)))
    }

    func testPullToRefreshAndTheRandomStoryReel() {
        launch()
        appear("tile-clown")
        // pull Home down from the top: the owl's eyes, a refresh, and the page comes back
        drag(from: CGVector(dx: 0.5, dy: 0.25), to: CGVector(dx: 0.5, dy: 0.62), hold: 0.2)
        sleep(4)
        XCTAssertTrue(appear("tile-clown").isHittable, "Home did not come back after the refresh")
        XCTAssertEqual(probe()["pv"], "-")

        // to the very bottom (plain scrolling: a touch that starts above the end is never the reel's) …
        let hint = el("pull-hint"), tabsTop = el("tab-home").frame.minY
        for _ in 0..<14 {
            if hint.exists && hint.frame.maxY < tabsTop - 30 { break }
            let w = app.windows.firstMatch
            w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.03, thenDragTo: w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)), withVelocity: .fast, thenHoldForDuration: 0)
            sleep(1)
        }
        XCTAssertTrue(hint.exists && hint.frame.maxY < tabsTop - 30, "Home did not scroll to its end")
        drag(from: CGVector(dx: 0.5, dy: 0.62), to: CGVector(dx: 0.5, dy: 0.55), hold: 0)      // the last few points, or a pull too short to count
        sleep(2)
        XCTAssertEqual(probe()["pv"], "-")
        XCTAssertEqual(hint.label, "Pull up for a random story")
        // … then pull up: the reel; let go at the top of its way and the story in its window opens
        drag(from: CGVector(dx: 0.5, dy: 0.8), to: CGVector(dx: 0.5, dy: 0.2), hold: 0.4)
        appear("pv-read", 6)
        let picked = probe()["pv"] ?? "-"
        XCTAssertNotEqual(picked, "-")
        el("pv-close").tap()
        gone("pv-read")
        // a short pull that is let go sinks back and opens nothing
        sleep(1)
        drag(from: CGVector(dx: 0.5, dy: 0.8), to: CGVector(dx: 0.5, dy: 0.72), hold: 0)
        sleep(2)
        XCTAssertEqual(probe()["pv"], "-")
        XCTAssertEqual(probe()["tab"], "home")
    }

    // MARK: scrolling: a drag up that starts on a card, a slider card, the genre row or a list row scrolls the page

    func testHomeScrollsFromATileASliderCardAndTheGenreRow() {
        // on a card of the grid
        launch()
        appear("tile-clown")
        sleep(1)
        guard let tile = onScreen("tile-", between: 0.45, 0.8) else { return XCTFail("no card in the lower half of Home") }
        scrolls(from: tile, by: min(320, tile.frame.midY - 120), mark: tile, "a card")
        XCTAssertEqual(probe()["favs"], "", "a drag up on a card liked it")

        // on the slider's card (straight up: the slider does not turn, the page goes up)
        launch()
        let heroes = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'hero-'"))
        until(5, "the slider is there") { heroes.count > 0 }
        sleep(1)
        let mid = app.windows.firstMatch.frame.midX
        guard let hero = heroes.allElementsBoundByIndex.first(where: { $0.exists && abs($0.frame.midX - mid) < 40 }) else { return XCTFail("no slider card in the middle") }
        scrolls(from: hero, by: max(110, hero.frame.midY - 50), mark: appear("genre-all"), "a slider card")

        // on the genre row
        launch()
        let genre = appear("genre-horror")
        sleep(1)
        scrolls(from: genre, by: min(320, genre.frame.midY - 70), mark: genre, "the genre row")
        XCTAssertEqual(probe()["genre"], "all", "a drag up on the genre row changed the genre")
    }

    func testFavouritesAndSearchListsScrollFromARow() {
        launch(["-tab", "fav", "-favs", "clown,the-doctor,two-knocks,frenemy,grave,haunted,slice,skinless,reunion,perfect-match"])
        appear("fav-row-clown")
        sleep(1)
        guard let row = onScreen("fav-row-", between: 0.4, 0.75) else { return XCTFail("no Favourites row in the middle") }
        scrolls(from: row, by: min(320, row.frame.midY - 120), mark: row, "a Favourites row")
        XCTAssertFalse((probe()["row"] ?? "-").contains(":-"), "a drag up moved a row sideways")

        launch(["-tab", "search", "-query", "e"])
        until(6, "search results") { self.onScreen("result-", between: 0.3, 0.7) != nil }
        guard let item = onScreen("result-", between: 0.25, 0.55) else { return XCTFail("no search result in the middle") }
        scrolls(from: item, by: min(260, item.frame.midY - 110), mark: item, "a search result")
    }
}
