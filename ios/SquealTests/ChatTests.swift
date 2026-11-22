import XCTest
@testable import Squeal

/// The chat's logic against the web prototype itself. web-expected.json → "chat" holds stories walked through in
/// web/squeal-preview.html (ios/tools/web-expected.js): after every step — a tap, an answer, "Next part", "Read again",
/// back to a choice, leaving — what is saved, what every screen would show as progress, the free taps left and what
/// the chat shows. ChatReader must come out the same, step for step.
final class ChatTests: XCTestCase {
    private final class Live { var ep: Int? = nil }

    func testChatWalksMatchTheWeb() {
        let scenarios = LogicTests.fixture["chat"] as! [[String: Any]]
        XCTAssertGreaterThan(scenarios.count, 10)
        let en = Dictionary(uniqueKeysWithValues: LogicTests.library.stories("en").map { ($0.id, $0) })
        for sc in scenarios {
            let name = sc["name"] as! String
            let story = en[sc["id"] as! String]!
            let defaults = UserDefaults(suiteName: "squeal-chat-tests")!
            defaults.removePersistentDomain(forName: "squeal-chat-tests")
            let store = Store(defaults)
            if let save = sc["save"] as? [String: Any] { for (k, v) in save { store.set("p:" + k, v) } }
            if let premium = sc["premium"] as? Bool, !premium { store.set("premium", false) }
            if let taps = sc["taps"] as? Int { store.set("taps", taps) }

            let live = Live()
            var reader: ChatReader? = nil
            let io = ChatReader.IO.store(store, story) { live.ep }

            func open(_ part: Int?) {
                reader?.stop()
                let r = ChatReader(story: story, part: part, progress: io.prog(), io: io)
                live.ep = r.ep
                reader = r
                if r.owesReply, case .theirs = r.begin(free: true) { r.arrived() }
            }
            func leave() {
                reader?.leaving = true
                reader?.stop()
                reader = nil
                live.ep = nil
            }

            for (n, step) in (sc["steps"] as! [[String: Any]]).enumerated() {
                let what = "\(name), step \(n) \(String(describing: step["do"]!))"
                if let word = step["do"] as? String {
                    switch word {
                    case "tap":
                        if let r = reader, r.foot == .tap, case .theirs = r.begin() { r.arrived() }
                    case "tapback":
                        if let r = reader, r.foot == .tap { _ = r.begin() }
                        leave()
                    case "back": leave()
                    case "next": open(reader!.ep + 1)
                    case "again": open(reader!.again())
                    default: XCTFail("unknown step " + word)
                    }
                } else if let d = step["do"] as? [String: Any] {
                    if let k = d["pick"] as? Int {
                        let r = reader!
                        if case .mine = r.pick(k), r.replyComesByItself, case .theirs = r.begin(free: true) { r.arrived() }
                    } else if let k = d["turn"] as? Int {
                        reader!.backToChoice(k)
                        open(reader!.ep)
                    } else {
                        open(d["open"] as? Int)
                    }
                }

                // what is saved
                let saved = store.progressRaw(story.id) as? [String: Any]
                let want = step["saved"] as? [String: Any]
                XCTAssertEqual(saved == nil, want == nil, "saved at all: " + what)
                XCTAssertEqual(saved?["ep"] as? Int, want?["ep"] as? Int, "saved ep: " + what)
                XCTAssertEqual(saved?["pos"] as? [Int], want?["pos"] as? [Int], "saved pos: " + what)
                XCTAssertEqual(saved?["path"] as? [String], want?["path"] as? [String], "saved path: " + what)
                if let v = want?["v"] as? String { XCTAssertEqual(saved?["v"] as? String, v, "saved version: " + what) }
                // what every screen makes of it
                let p = io.prog()
                XCTAssertEqual(p.ep, step["ep"] as? Int, "ep: " + what)
                XCTAssertEqual(p.pos, step["pos"] as? [Int], "pos: " + what)
                XCTAssertEqual(p.path, step["path"] as? [String], "path: " + what)
                XCTAssertEqual(Reading.percent(story, p), step["pct"] as? Int, "percent: " + what)
                XCTAssertEqual(Reading.nextPart(story, p), step["next"] as? Int, "next part: " + what)
                XCTAssertEqual(store.taps, step["taps"] as? Int, "free taps: " + what)
                // what the chat shows
                XCTAssertEqual(reader?.ep, step["open"] as? Int, "the part open: " + what)
                guard let r = reader else { continue }
                XCTAssertEqual(r.i, step["shown"] as? Int, "messages shown: " + what)
                if r.i > 0, r.messages[r.i - 1].voice == nil, r.messages[r.i - 1].video == nil {
                    XCTAssertEqual(r.messages[r.i - 1].text, step["last"] as? String, "last message: " + what)
                }
                var foot = "tap", drafts: [String] = [], next = false, turns = 0
                var end: String? = nil
                switch r.foot {
                case .tap: break
                case .ask(let choices): foot = "ask"; drafts = choices.map(\.text)
                case .paywall: foot = "pay"
                case .end(let e):
                    foot = "end"; next = !e.last; turns = e.turns
                    let words = ChatText.end(story, part: r.ep, end: e, lang: "en")
                    end = words.title + (words.sub.map { " | " + $0 } ?? "")
                }
                XCTAssertEqual(foot, step["foot"] as? String, "bottom panel: " + what)
                XCTAssertEqual(drafts, step["drafts"] as? [String], "answers: " + what)
                XCTAssertEqual(next, step["nextButton"] as? Bool, "Next part: " + what)
                XCTAssertEqual(turns, step["turns"] as? Int, "back-to-a-choice buttons: " + what)
                XCTAssertEqual(end, step["end"] as? String, "the end's title: " + what)
            }
        }
    }

    func testWallpaperIsLaidOutAsInTheWeb() {
        let walls = LogicTests.fixture["wall"] as! [[String: Any]]
        let en = Dictionary(uniqueKeysWithValues: LogicTests.library.stories("en").map { ($0.id, $0) })
        XCTAssertGreaterThan(walls.count, 3)
        for w in walls {
            let id = w["id"] as! String, ep = w["ep"] as! Int
            let mine = Doodles.items(Doodles.config(en[id]!.parts[ep]), seed: id + ":" + String(ep))
            let web = w["items"] as! [[Any]]
            XCTAssertEqual(mine.count, web.count, "\(id) part \(ep)")
            for (a, b) in zip(mine, web) {
                XCTAssertEqual(a.name, b[0] as? String, "\(id) part \(ep): doodle")
                XCTAssertEqual(a.g, b[1] as? String, "\(id) part \(ep): group")
                XCTAssertEqual(a.s, (b[2] as! NSNumber).doubleValue, accuracy: 1e-9)
                XCTAssertEqual(a.px, (b[3] as! NSNumber).doubleValue, accuracy: 1e-9)
                XCTAssertEqual(a.py, (b[4] as! NSNumber).doubleValue, accuracy: 1e-9)
                XCTAssertEqual(a.rot, (b[5] as! NSNumber).doubleValue, accuracy: 1e-9)
            }
        }
    }

    func testEveryDoodleOfEveryStoryCanBeDrawn() {
        for s in LogicTests.library.stories("en") {
            for part in s.parts {
                let cfg = Doodles.config(part)
                for name in cfg.groups.flatMap(\.names) {
                    XCTAssertNotNil(DoodleData.all[name], "\(s.id): no doodle \(name)")
                    let art = Doodles.art(name)
                    XCTAssertFalse(art.lines.isEmpty && art.words.isEmpty, "\(s.id): doodle \(name) is empty")
                    for l in art.lines {
                        let b = l.path.boundingRect
                        XCTAssertTrue(b.minX > -3 && b.minY > -3 && b.maxX < 27 && b.maxY < 27, "\(name) leaves its 24-grid: \(b)")
                    }
                }
            }
        }
    }

    func testKeysAreReadInTheFilesOrder() {
        let json = #"{"parts": [{"x": {"a": [1, {"q": "}"}], "b\"c": 2}}, {"nodes": {"start": {"m": []}, "zeta": {}, "alpha": {"e": "x"}}, "wallpaperEndings": {"run": [], "hide": []}}]}"#
        let data = json.data(using: .utf8)!
        XCTAssertEqual(JSONOrder.keys(data, at: ["parts", 1, "nodes"]), ["start", "zeta", "alpha"])
        XCTAssertEqual(JSONOrder.keys(data, at: ["parts", 1, "wallpaperEndings"]), ["run", "hide"])
        XCTAssertEqual(JSONOrder.keys(data, at: ["parts", 0, "x"]), ["a", "b\"c"])
        XCTAssertEqual(JSONOrder.keys(data, at: ["parts", 2, "nodes"]), [])
        XCTAssertEqual(JSONOrder.keys(data, at: ["parts", 0, "nodes"]), [])
        let tk = LogicTests.library.stories("en").first { $0.id == "two-knocks" }!
        XCTAssertEqual(tk.parts[0].nodeOrder, ["start", "open", "stay", "run", "hide"])
        XCTAssertEqual(tk.parts[0].endingIDs, ["open", "run", "hide"])
        XCTAssertEqual(tk.parts[0].endingsOrder, ["open", "run", "hide"])
    }

    func testANewBubbleOpensOnlyTheRoomItNeeds() {
        // a chat shorter than the screen: the bubble grows in place
        let short = Grow(kind: .inflate, t0: 0, natBefore: 200, hold: nil, viewport: 600)
        XCTAssertEqual(short.margin0(46), 0)
        // a full chat: all of it (with its gap) opens as it grows
        let full = Grow(kind: .inflate, t0: 0, natBefore: 900, hold: nil, viewport: 600)
        XCTAssertEqual(full.margin0(46), -46)
        XCTAssertEqual(full.margin(0, h: 46), -46)
        XCTAssertEqual(full.margin(0.26, h: 46), 0, accuracy: 1e-6)
        // only a part does not fit
        let part = Grow(kind: .inflate, t0: 0, natBefore: 580, hold: nil, viewport: 600)
        XCTAssertEqual(part.margin0(46), -18)
        // room kept after a choice is used first
        let held = Grow(kind: .inflate, t0: 0, natBefore: 800, hold: 900, viewport: 600)
        XCTAssertEqual(held.margin0(46), 0)
        let heldLess = Grow(kind: .inflate, t0: 0, natBefore: 880, hold: 900, viewport: 600)
        XCTAssertEqual(heldLess.margin0(46), -26)
        // "typing…" turned message: only what the message is taller by
        let morph = Grow(kind: .morph(from: CGSize(width: 60, height: 40)), t0: 0, natBefore: 900, hold: nil, viewport: 600)
        XCTAssertEqual(morph.margin0(62 + 6), -22)
        XCTAssertEqual(morph.contentOpacity(0.05), 0)
        XCTAssertEqual(morph.contentOpacity(0.26), 1, accuracy: 1e-9)
    }

    func testVoiceWaveformIsTheWebs() {
        // template.html voiceBubble(): 30 bars, 4…18 px, from the clip's name
        let bars = VoiceBubble.bars("voice/two-knocks-door.mp3")
        XCTAssertEqual(bars.count, 30)
        XCTAssertEqual(bars.map { Int($0) }, (LogicTests.fixture["voiceBars"] as! [Int]))
    }
}
