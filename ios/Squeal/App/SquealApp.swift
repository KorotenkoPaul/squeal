import SwiftUI

@main
struct SquealApp: App {
    @StateObject private var model: AppModel
    private let homeScroll: CGFloat?
    private let letterings: Int?

    init() {
        Lettering.register()
        let args = LaunchArgs(ProcessInfo.processInfo.arguments)
        let store = Store()
        args.prepare(store)
        let m = AppModel(store: store)
        if let id = args.value("-preview") { m.previewID = id }
        if let t = args.value("-tab") { m.tab = t }
        ChatDebug.autotap = args.value("-autotap").flatMap { Int($0) } ?? 0
        ChatDebug.autopick = args.value("-autopick").flatMap { Int($0) }
        ChatDebug.autopart = args.value("-autopart").flatMap { Int($0) }
        if let id = args.value("-chat") { m.openStory(id, part: args.value("-part").flatMap { Int($0) }) }
        _model = StateObject(wrappedValue: m)
        letterings = args.value("-letterings").flatMap { Int($0) }
        homeScroll = args.value("-scroll").flatMap { Double($0) }.map { CGFloat($0) }
    }

    var body: some Scene {
        WindowGroup {
            if let p = letterings {
                LetteringPages(page: p).environmentObject(model)
            } else {
                RootView(homeScroll: homeScroll).environmentObject(model)
            }
        }
    }
}

/// Launch arguments for the CI screenshots (never used by a reader):
///   -reset 1          start from a clean slate
///   -demo 1           a few favourites and some progress (the same as the web reference shots)
///   -lang ru          the language
///   -scroll 600       Home scrolled this far down
///   -preview <id>     the story page of <id> open
///   -letterings <p>   page p of all slider cards (four a page)
///   -still 1          the slider does not turn by itself
///   -chat <id>        the chat of <id> open (-part N: that part, counted from 0; else where the reader is)
///   -pos N            N messages of that part already read (or N,M,…: part by part); -path a,b,c: the branches taken (interactive)
///   -premium 0        a free reader, with -taps N free taps left
///   -autotap N        the open chat reads N more messages by itself; -autopick K: then picks answer K at a choice
///   -autopart K       2 s after the chat opens, part K is picked on the part disc (a part switch)
struct LaunchArgs {
    let args: [String]
    init(_ a: [String]) { args = a }
    func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    func prepare(_ store: Store) {
        if value("-reset") == "1" {
            for k in store.defaults.dictionaryRepresentation().keys where k.hasPrefix("squeal:") { store.defaults.removeObject(forKey: k) }
        }
        if value("-demo") == "1" {
            store.set("favs", ["clown", "the-doctor"])
            store.set("p:nobodys-home", ["ep": 1, "pos": [40, 10, 0]])
            store.set("p:clown", ["ep": 0, "pos": [20]])
        }
        if let l = value("-lang") { store.set("lang", l) }
        if let id = value("-chat"), let pos = value("-pos") {
            let part = value("-part").flatMap { Int($0) } ?? 0
            let ns = pos.split(separator: ",").compactMap { Int($0) }              // "22": that part; "22,9": part by part
            let all: [Int] = ns.count > 1 ? ns : (0...part).map { $0 == part ? (ns.first ?? 0) : 0 }
            var save: [String: Any] = ["ep": part, "pos": all]
            if let path = value("-path") { save["path"] = path.split(separator: ",").map(String.init) }
            store.set("p:" + id, save)
        }
        if value("-premium") == "0" { store.set("premium", false) }
        if let t = value("-taps").flatMap({ Int($0) }) { store.set("taps", t) }
    }
}
