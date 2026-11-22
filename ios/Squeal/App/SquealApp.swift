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
    }
}
