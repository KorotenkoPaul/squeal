import XCTest
@testable import Squeal

/// The app's logic against the web prototype itself: web-expected.json is produced by running
/// web/squeal-preview.html (template.html + the stories) in a browser — versions, reading times, progress rules,
/// nextPart and Top of the week must come out the same.
final class LogicTests: XCTestCase {
    static var fixture: [String: Any] = {
        let url = Bundle(for: LogicTests.self).url(forResource: "web-expected", withExtension: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }()
    static let library = StoryLibrary.bundled(Bundle(for: AppModel.self))

    func testAllLanguagesLoadInTheWebOrder() {
        let all = Self.fixture["stories"] as! [String: [[String: Any]]]
        for lang in StoryLibrary.langs {
            let mine = Self.library.stories(lang)
            let web = all[lang]!
            XCTAssertEqual(mine.map(\.id), web.map { $0["id"] as! String }, "order, \(lang)")
            XCTAssertEqual(mine.map(\.title), web.map { $0["title"] as! String }, "titles, \(lang)")
        }
    }

    func testVersionFingerprintMatchesBuildPy() {
        let all = Self.fixture["stories"] as! [String: [[String: Any]]]
        for lang in StoryLibrary.langs {
            let mine = Dictionary(uniqueKeysWithValues: Self.library.stories(lang).map { ($0.id, $0) })
            for w in all[lang]! {
                let id = w["id"] as! String
                XCTAssertEqual(mine[id]?.v, w["v"] as? String, "version of \(id) in \(lang)")
                XCTAssertEqual(mine[id]?.cover.map { "covers/" + $0 }, w["cover"] as? String, "cover of \(id)")
            }
        }
    }

    func testReadingTimeMatchesTheWebEverywhere() {
        let all = Self.fixture["stories"] as! [String: [[String: Any]]]
        for lang in StoryLibrary.langs {
            let mine = Dictionary(uniqueKeysWithValues: Self.library.stories(lang).map { ($0.id, $0) })
            for w in all[lang]! {
                let id = w["id"] as! String
                let s = mine[id]!
                XCTAssertEqual(L10n.tr(lang, "min", ["n": String(Reading.storyMinutes(s))]), w["min"] as? String, "\(id) in \(lang)")
            }
        }
    }

    func testCoversAreBundled() {
        for s in Self.library.stories("en") {
            let url = Bundle(for: AppModel.self).resourceURL!.appendingPathComponent("covers/" + (s.cover ?? "-"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "cover of \(s.id)")
        }
    }

    func testProgressRulesMatchTheWeb() {
        let cases = Self.fixture["prog"] as! [[String: Any]]
        let en = Dictionary(uniqueKeysWithValues: Self.library.stories("en").map { ($0.id, $0) })
        XCTAssertGreaterThan(cases.count, 50)
        for c in cases {
            let s = en[c["id"] as! String]!
            let save = c["save"] is NSNull ? nil : c["save"]
            let p = Reading.prog(s, raw: save)
            let what = "\(s.id) save=\(String(describing: save))"
            XCTAssertEqual(p.ep, c["ep"] as? Int, "ep " + what)
            XCTAssertEqual(p.pos, c["pos"] as? [Int], "pos " + what)
            XCTAssertEqual(Reading.percent(s, p), c["pct"] as? Int, "percent " + what)
            XCTAssertEqual(Reading.nextPart(s, p), c["next"] as? Int, "nextPart " + what)
        }
    }

    func testThePartOpenInTheChatKeepsAShortCount() {
        let s = Self.library.stories("en").first { $0.id == "nobodys-home" }!
        let raw: [String: Any] = ["ep": 1, "pos": [2, 3, 0]]
        XCTAssertEqual(Reading.prog(s, raw: raw).pos, [0, 0, 0])
        XCTAssertEqual(Reading.prog(s, raw: raw, liveEp: 1).pos, [0, 3, 0])
    }

    func testTopOfTheWeekIsTheSameInEveryLanguage() {
        let top = Self.fixture["top"] as! [String: [String]]
        let en = Self.library.stories("en")
        for lang in ["en", "ru"] {
            XCTAssertEqual(TopWeek.top(Self.library.stories(lang), english: en, counts: [:]).map(\.id), top[lang], lang)
        }
        let ratings = Self.fixture["ratings"] as! [String: Double]
        for (id, r) in ratings { XCTAssertEqual(TopWeek.rating(id), r, accuracy: 1e-9, id) }
        // reads lift a story: most read first, featured always pinned at the front
        let counted = TopWeek.top(en, english: en, counts: ["clown": 3, "haunted": 1])
        XCTAssertEqual(counted.prefix(3).map(\.id), ["two-knocks", "clown", "haunted"])
    }

    func testWeekKeyIsISO() {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 1; c.hour = 12
        let d = Calendar.current.date(from: c)!
        XCTAssertEqual(TopWeek.weekKey(d), "2026-W01")
        c.year = 2027; c.month = 1; c.day = 1
        XCTAssertEqual(TopWeek.weekKey(Calendar.current.date(from: c)!), "2026-W53")
    }

    func testStoreTreatsAWrongKindAsNoValue() {
        let d = UserDefaults(suiteName: "squeal-tests")!
        d.removePersistentDomain(forName: "squeal-tests")
        let st = Store(d)
        d.set("{\"a\":1}", forKey: "squeal:favs")
        XCTAssertEqual(st.favs, [])
        d.set("not json", forKey: "squeal:premium")
        XCTAssertTrue(st.premium)
        d.set("5", forKey: "squeal:premium")
        XCTAssertTrue(st.premium)
        d.set("false", forKey: "squeal:premium")
        XCTAssertFalse(st.premium)
        XCTAssertEqual(st.taps, Store.freeTaps)
        st.set("tab", "fav")
        XCTAssertEqual(st.tab, "fav")
        st.set("p:x", ["ep": 1, "pos": [1, 2]])
        XCTAssertEqual((st.progressRaw("x") as? [String: Any])?["ep"] as? Int, 1)
    }

    func testPyJSONMatchesPython() {
        let x: [String: Any] = ["b": [1, "é\"\\\n", NSNull()], "a": ["z": true, "ä": false], "Z": "x\u{1}"]
        XCTAssertEqual(PyJSON.dumps(x), "{\"Z\": \"x\\u0001\", \"a\": {\"z\": true, \"ä\": false}, \"b\": [1, \"é\\\"\\\\\\n\", null]}")
    }

    func testSvgPathReaderDrawsTheIcons() {
        for d in [IconPath.heart, IconPath.pad, IconPath.homeOuter, IconPath.searchCircle, IconPath.again, IconPath.menu] {
            let b = SVGPath.parse(d).boundingRect
            XCTAssertGreaterThan(b.width, 1, d); XCTAssertGreaterThan(b.height, 1, d)
            XCTAssertLessThan(b.maxX, 25, d); XCTAssertLessThan(b.maxY, 26, d)
        }
    }

    func testFirstLanguage() {
        XCTAssertEqual(L10n.firstLanguage(["ru-RU", "en"]), "ru")
        XCTAssertEqual(L10n.firstLanguage(["ja-JP", "de-DE"]), "de")
        XCTAssertEqual(L10n.firstLanguage(["ja-JP"]), "en")
        XCTAssertEqual(L10n.tr("de", "partOver", ["n": "2"]), "Teil 2 beginnt von vorn")
        XCTAssertEqual(L10n.tr("xx", "read"), "Read")
    }
}
