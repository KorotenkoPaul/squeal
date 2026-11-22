import XCTest
@testable import Squeal

/// Search, the fear row, Favourites, the random reel and the one rule for double taps against the web prototype itself
/// (web-expected.json: "search", "norm", "oneEdit", "fear", "fearPaint", "favs", "reel", "spot" — node ios/tools/web-expected.js).
final class Stage3Tests: XCTestCase {
    static var fx: [String: Any] { LogicTests.fixture }
    static var library: StoryLibrary { LogicTests.library }

    func testSearchFindsWhatTheWebFindsInEveryLanguage() {
        let all = Self.fx["search"] as! [String: [[Any]]]
        let en = Self.library.stories("en")
        var n = 0
        for lang in StoryLibrary.langs {
            let list = Self.library.stories(lang)
            for c in all[lang]! {
                let q = c[0] as! String, want = c[1] as! [String]
                XCTAssertEqual(Search.stories(list, english: en, q).map(\.id), want, "\(lang): \"\(q)\"")
                n += 1
            }
        }
        XCTAssertGreaterThan(n, 250)
    }

    func testNormAndOneTypo() {
        for c in Self.fx["norm"] as! [[String]] { XCTAssertEqual(Search.norm(c[0]), c[1], c[0]) }
        for c in Self.fx["oneEdit"] as! [[Any]] {
            let a = c[0] as! String, b = c[1] as! String
            XCTAssertEqual(Search.oneEditAway(Array(a.utf16), Array(b.utf16)), c[2] as! Bool, "\(a) / \(b)")
        }
    }

    func testFearLevelsAndTheRowsLook() {
        let levels = Self.fx["fear"] as! [[String]]
        let en = Self.library.stories("en")
        for l in 1...5 { XCTAssertEqual(Fear.stories(en, level: l).map(\.id), levels[l - 1], "level \(l)") }
        for p in Self.fx["fearPaint"] as! [[String: Any]] {
            let x = (p["x"] as! NSNumber).doubleValue
            let look = Fear.paint(scroll: x)
            let s = (p["s"] as! [NSNumber]).map(\.doubleValue), o = (p["o"] as! [NSNumber]).map(\.doubleValue)
            for i in 0..<5 {
                XCTAssertEqual(look.scale[i], s[i], accuracy: 0.003, "scale \(i) at \(x)")
                XCTAssertEqual(look.opacity[i], o[i], accuracy: 0.004, "opacity \(i) at \(x)")
            }
        }
        XCTAssertEqual(Fear.paint(scroll: 0).near, 1)
        XCTAssertEqual(Fear.paint(scroll: 66).near, 1)        // a tie: the first of the two
        XCTAssertEqual(Fear.paint(scroll: 67).near, 2)
        XCTAssertEqual(Fear.paint(scroll: 528).near, 5)
    }

    func testFavouritesStandUnderTheirGenresInTheStoriesOrder() {
        let en = Self.library.stories("en")
        let names = ["horror": "Horror", "thriller": "Thriller", "romance": "Romance"]
        for c in Self.fx["favs"] as! [[String: Any]] {
            let groups = Shelf.favourites(en, favs: c["favs"] as! [String])
            let rows = groups.flatMap { ["#" + names[$0.genre]!] + $0.stories.map(\.id) }
            XCTAssertEqual(rows, c["rows"] as! [String])
            XCTAssertEqual(groups.isEmpty, c["empty"] as! Bool)
        }
    }

    func testTheReelHoldsTheWebsCandidatesAndStandsWhereTheWebsDoes() {
        let en = Self.library.stories("en")
        for c in Self.fx["reel"] as! [[String: Any]] {
            let save = c["save"] as! [String: Any], genre = c["genre"] as! String, name = "\(c["name"]!) / \(genre)"
            let prog: (Story) -> Squeal.Progress = { Reading.prog($0, raw: save["p:" + $0.id]) }
            let pool = Shelf.randomPool(en, genre: genre, started: { prog($0).pos.contains { $0 != 0 } }, percent: { Reading.percent($0, prog($0)) })
            XCTAssertEqual(pool.map(\.id).sorted(), c["pool"] as! [String], name)
            let g = ReelGeometry(tabsTop: (c["tabsTop"] as! NSNumber).doubleValue, hintBottom: (c["hintBottom"] as! NSNumber).doubleValue, hintGap: (c["hintGap"] as! NSNumber).doubleValue)
            let at = c["at"] as! [[String: Any]]
            let first = (at[0]["strip"] as! NSNumber).doubleValue
            for a in at.prefix(11) {                       // the finger only ever going up
                let raw = (a["raw"] as! NSNumber).doubleValue, d = min(raw, g.full), ov = max(0, raw - g.full)
                XCTAssertEqual(g.top(d), (a["top"] as! NSNumber).doubleValue, accuracy: 0.01, "top at \(raw), \(name)")
                XCTAssertEqual(g.lift(d) + ReelGeometry.ovPx(ov), (a["shift"] as! NSNumber).doubleValue, accuracy: 0.01, "page at \(raw), \(name)")
                XCTAssertEqual(d >= g.line ? "Release for a random story" : "Keep pulling", a["hint"] as! String, "words at \(raw), \(name)")
                // the rows have turned 0.9 of the finger's way (the strip goes round: whole turns do not count)
                let turned = ReelGeometry.wrap((a["strip"] as! NSNumber).doubleValue - first - 0.9 * (raw - 5), rows: (c["n"] as! NSNumber).intValue)
                XCTAssertTrue(turned < 0.01 || turned > Double((c["n"] as! NSNumber).intValue) * 84 - 0.01, "rows at \(raw), \(name)")
            }
        }
        XCTAssertEqual(ReelGeometry.ovInv(ReelGeometry.ovPx(73)), 73, accuracy: 1e-9)
        XCTAssertEqual(ReelGeometry.wrap(-10, rows: 3), 242, accuracy: 1e-9)
        XCTAssertEqual(ReelGeometry.settle(84 * 4 + 41.9, rows: 3).index, 1)
        XCTAssertEqual(ReelGeometry.settle(84 * 4 + 42, rows: 3).index, 2)
        XCTAssertEqual(ReelGeometry.settleMs(from: 42, to: 84), 165)
    }

    func testTheOneRuleForDoubleTapsEatsWhatTheWebEats() {
        let buttons = (Self.fx["spotButtons"] as! [String: [NSNumber]]).mapValues { CGRect(x: $0[0].doubleValue, y: $0[1].doubleValue, width: $0[2].doubleValue, height: $0[3].doubleValue) }
        func control(_ p: CGPoint) -> String? { buttons.first { $0.value.contains(p) }?.key }
        func point(_ a: Any?) -> CGPoint? { (a as? [NSNumber]).map { CGPoint(x: $0[0].doubleValue, y: $0[1].doubleValue) } }
        for (k, taps) in (Self.fx["spot"] as! [[[String: Any]]]).enumerated() {
            var rule = SpotRule(), now = 100.0
            for (i, t) in taps.enumerated() {
                now += (t["ms"] as! NSNumber).doubleValue / 1000
                let down = point(t["at"])!, up = point(t["to"]) ?? down
                let eaten = rule.eats(control(down), at: down, now: now)
                XCTAssertEqual(!eaten, t["got"] as! Bool, "scenario \(k), tap \(i)")
                if !eaten { rule.tapped(control(up), at: up, now: now, moved: Double(hypot(up.x - down.x, up.y - down.y))) }
            }
        }
    }

    func testAfterCloseAndAfterOpenTheSamePlaceTakesNoTap() {
        var rule = SpotRule()
        let p = CGPoint(x: 30, y: 60)
        rule.closed(at: p, now: 10, open: false)                              // ✕ pressed
        XCTAssertTrue(rule.eats("tile:x", at: CGPoint(x: 40, y: 70), now: 10.3))   // the card under it
        XCTAssertFalse(rule.eats("pv-back", at: p, now: 10.3))                 // the button itself, still there
        XCTAssertFalse(rule.eats("tile:x", at: CGPoint(x: 30, y: 105), now: 10.3)) // 45 pt away
        XCTAssertFalse(rule.eats("tile:x", at: p, now: 10.71))
        rule.closed(at: p, now: 20, open: true)                               // a story page opened by a tap here
        XCTAssertTrue(rule.eats("pv-back", at: p, now: 20.3))                  // not even the new page's ✕
        XCTAssertTrue(rule.eats("read", at: p, now: 20.69))
        // the tap that only put the search keyboard away keeps its mark
        rule = SpotRule()
        rule.pin(at: p, now: 30)
        XCTAssertTrue(rule.eats("item:x", at: p, now: 30.2))
        XCTAssertFalse(rule.eats(nil, at: p, now: 30.2))
        rule.tapped(nil, at: CGPoint(x: 200, y: 200), now: 30.3)
        XCTAssertTrue(rule.eats("item:x", at: p, now: 30.5))
    }

    func testPullsAndRowSwipeNumbers() {
        XCTAssertEqual(RefreshPull.shown(0), 0)
        XCTAssertEqual(RefreshPull.shown(170), 150 * (1 - exp(-1)), accuracy: 1e-9)
        XCTAssertEqual(RefreshPull.lids(0), 1); XCTAssertEqual(RefreshPull.lids(32), 0.75); XCTAssertEqual(RefreshPull.lids(64), 0); XCTAssertEqual(RefreshPull.lids(120), 0)
        XCTAssertEqual(RefreshPull.eyesY(30), -46); XCTAssertEqual(RefreshPull.eyesY(120), 0)
        XCTAssertEqual(RowSwipe.x(base: 0, dx: 40), 10); XCTAssertEqual(RowSwipe.x(base: -104, dx: -20), -124)
        XCTAssertEqual(RowSwipe.buttonWidth(-104), 96); XCTAssertEqual(RowSwipe.buttonWidth(-5), 0)
        XCTAssertEqual(RowSwipe.label(-60).opacity, 0.5, accuracy: 1e-9); XCTAssertEqual(RowSwipe.label(-60).scale, 0.925, accuracy: 1e-9)
        XCTAssertEqual(RowSwipe.end(x: -220, width: 357, vx: 0, idle: 0), .remove)
        XCTAssertEqual(RowSwipe.end(x: -214, width: 357, vx: 0, idle: 0), .open)
        XCTAssertEqual(RowSwipe.end(x: -47, width: 357, vx: 0, idle: 0), .shut)
        XCTAssertEqual(RowSwipe.end(x: -20, width: 357, vx: -0.5, idle: 10), .open)       // a flick wins over position
        XCTAssertEqual(RowSwipe.end(x: -20, width: 357, vx: -0.5, idle: 150), .shut)      // stopped before lifting: no flick
        XCTAssertEqual(RowSwipe.end(x: -90, width: 357, vx: 0.5, idle: 10), .shut)
    }

    @MainActor func testMenuSubscriptionSwitchWritesWhatTheChatReads() {
        let d = UserDefaults(suiteName: "stage3-tests")!
        d.removePersistentDomain(forName: "stage3-tests")
        let store = Store(d)
        let m = AppModel(library: Self.library, store: store)
        store.set("taps", 3)
        XCTAssertTrue(store.premium)
        m.toggleSubscription()
        XCTAssertFalse(store.premium); XCTAssertEqual(store.taps, 100)
        XCTAssertEqual(m.toast, L10n.tr(m.lang, "subOff", ["n": "100"]))
        store.set("taps", 7)
        m.toggleSubscription()
        XCTAssertTrue(store.premium); XCTAssertEqual(store.taps, 7)
        m.show(tab: "search")
        XCTAssertEqual(store.tab, "search")
        m.setLang("ru")
        XCTAssertEqual(m.tr("cancel"), "Отмена"); XCTAssertEqual(store.lang, "ru")
    }

    @MainActor func testTheAppWatchesItsTouchesAndATapWithNoTouchIsJudgedByItsPlace() {
        XCTAssertTrue(UIWindow.watchesTouches)
        let t = Taps.shared
        t.reset()
        let p = CGPoint(x: 50, y: 50)
        XCTAssertTrue(t.allows("a", at: p))
        XCTAssertFalse(t.allows("b", at: CGPoint(x: 60, y: 50)))        // the second half of a double tap
        XCTAssertTrue(t.allows("a", at: p))
        XCTAssertTrue(t.allows("b", at: CGPoint(x: 200, y: 50)))
        XCTAssertFalse(t.allows(nil, at: CGPoint(x: 200, y: 60)))
        t.reset()
    }
}
