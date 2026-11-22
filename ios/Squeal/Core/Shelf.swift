import Foundation

/// Favourites, the random story and the two pulls of Home: the plain rules and numbers of template.html
/// (favourites(), pullForRandom(), pullToRefresh(), rubberBand()).
enum Shelf {
    static let genres = ["horror", "thriller", "romance"]

    /// Favourites: the liked stories in the stories' own order, grouped by genre in the genres' order
    static func favourites(_ stories: [Story], favs: [String]) -> [(genre: String, stories: [Story])] {
        let list = stories.filter { favs.contains($0.id) }
        return genres.compactMap { g in
            let of = list.filter { $0.genre == g }
            return of.isEmpty ? nil : (g, of)
        }
    }

    /// The reel's candidates (deal()): only from the genre you are looking at; stories you have not started, else the
    /// unfinished ones, else any; never fewer than three rows.
    static func randomPool(_ stories: [Story], genre: String, started: (Story) -> Bool, percent: (Story) -> Int) -> [Story] {
        let shelf = stories.filter { genre == "all" || $0.genre == genre }
        let fresh = shelf.filter { !started($0) }
        let unfinished = shelf.filter { started($0) && percent($0) < 100 }
        let pool = !fresh.isEmpty ? fresh : !unfinished.isEmpty ? unfinished : shelf
        return pool.count > 2 ? pool : shelf.count > 2 ? shelf : stories
    }
}

/// The random-story reel at the bottom of Home (pullForRandom): where everything stands for a pull of `raw` px.
struct ReelGeometry: Equatable {
    static let row = 84.0
    static let ovC = 110.0, ovK = 220.0

    /// the tab bar's top, the hint line's bottom, the gap the hint keeps under the last card (all in one coordinate space)
    var tabsTop: Double, hintBottom: Double, hintGap: Double

    /// where the reel belongs, page at rest
    var r0: Double { hintBottom + hintGap }
    /// it starts behind the tabs
    var start: Double { max(r0, tabsTop) }
    var need: Double { max(0, r0 + Self.row + 16 - tabsTop) }
    /// the pull at which all is up
    var full: Double { (start - r0) + need }
    /// the release line: the reel has come all the way up
    var line: Double { max(40, full) }

    func lift(_ raw: Double) -> Double { min(need, max(0, max(0, raw) - (start - r0))) }
    /// the reel's top: risen with the finger, never past its place under the words
    func top(_ raw: Double, lift l: Double? = nil) -> Double { max(start - max(0, raw), r0 - (l ?? lift(raw))) }

    /// pulled on past the top: what the page shows for `o` px of finger travel, and back
    static func ovPx(_ o: Double) -> Double { ovC * (1 - exp(-o / ovK)) }
    static func ovInv(_ px: Double) -> Double { -ovK * log(1 - min(0.995, max(0, px) / ovC)) }

    /// the strip's place for a turn of `o` px (rows move up): how far into the list the window's top is
    static func wrap(_ o: Double, rows n: Int) -> Double { let span = Double(n) * row; return (o.truncatingRemainder(dividingBy: span) + span).truncatingRemainder(dividingBy: span) }
    /// letting go: the nearest row, and the row of the list it is
    static func settle(_ from: Double, rows n: Int) -> (to: Double, index: Int) {
        let k = (from / row + 0.5).rounded(.down)
        return (k * row, ((Int(k) % n) + n) % n)
    }
    static func settleMs(from: Double, to: Double) -> Double { (120 + 90 * abs(to - from) / row + 0.5).rounded(.down) }
    /// sinking back: a critically damped spring from the finger's own speed
    static func sink(x0: Double, v0: Double, t: Double) -> Double { let w = 12.0; return max(0, (x0 + (v0 + w * x0) * t) * exp(-w * t)) }
}

/// Pull to refresh (pullToRefresh): the page follows the finger with a rubber band; the owl's eyes open as you pull.
enum RefreshPull {
    static let line = 64.0, rest = 76.0
    /// rubber band: easy at first, then stiffer
    static func shown(_ raw: Double) -> Double { raw <= 0 ? 0 : 150 * (1 - exp(-raw / 170)) }
    /// 1 shut, 0 open
    static func lids(_ d: Double) -> Double { let k = min(1, d / line); return 1 - k * k }
    static func eyesY(_ d: Double) -> Double { min(d, rest) - rest }
}

/// A row of Favourites under the finger (favourites() set / end): the red button stretches with the swipe.
enum RowSwipe {
    static let open = 96.0, gap = 8.0
    static func x(base: Double, dx: Double) -> Double { let x = base + dx; return x > 0 ? x / 4 : x }   // a little resistance to the right
    static func buttonWidth(_ x: Double) -> Double { max(0, -x - gap) }
    static func label(_ x: Double) -> (opacity: Double, scale: Double) {
        let k = min(1, max(0, (buttonWidth(x) - 24) / 56))
        return (k, 0.85 + 0.15 * k)
    }
    enum End: Equatable { case remove, open, shut }
    /// `vx` in px/ms (smoothed), `idle`: ms since the last move
    static func end(x: Double, width: Double, vx: Double, idle: Double) -> End {
        let v = idle > 100 ? 0 : vx                      // stopped before lifting: where it is decides, not an old flick
        if -x > width * 0.6 { return .remove }
        let o = v < -0.4 ? true : v > 0.4 ? false : -x > open / 2   // a flick wins over position
        return o ? .open : .shut
    }
}
