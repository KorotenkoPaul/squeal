import Foundation
import CoreGraphics

/// One rule for every double tap, app-wide (template.html SPOT, CLOSE_TAP — 2026-11-13).
///
/// SPOT: a tap that lands, within 0.8 s and 40 pt of the tap before it, on a DIFFERENT control from the one that tap
/// pressed is the second half of that double tap, not a choice: a control has just appeared or slid under the finger
/// ("Read again" after the last message, the story page's buttons over a card, the row sliding up after "Remove",
/// the next fear name, the card under a heart that has just gone). It does nothing. The same control again (a heart,
/// play, Tap to continue) still works. No control under the finger: eaten only when the first tap pressed one.
/// The end of a slide (the finger moved more than 10 pt) is no tap: nothing is armed after it.
///
/// CLOSE_TAP: after ✕ or the chat's back arrow (and after a tap that opened a story page), a touch within 44 pt of that
/// place does nothing for 0.7 s — it must not press what lay under the button, or what has just appeared over the card.
struct SpotRule {
    struct Spot: Equatable { var p: CGPoint; var t: Double; var control: String?; var pin = false }
    struct Close: Equatable { var p: CGPoint; var t: Double; var open: Bool }

    var spot: Spot? = nil
    var close: Close? = nil
    /// controls that handle their own second tap while CLOSE_TAP is on (✕ and the back arrow, still there)
    static let closers: Set<String> = ["pv-back", "chat-back"]

    /// The finger comes down at `p` on `control` (nil: no control there). True: this touch does nothing.
    func eats(_ control: String?, at p: CGPoint, now: Double) -> Bool {
        if let c = close, now - c.t <= 0.7, hypot(p.x - c.p.x, p.y - c.p.y) <= 44 {
            if c.open || !(control.map { Self.closers.contains($0) } ?? false) { return true }
        }
        guard let s = spot, now - s.t <= 0.8, hypot(p.x - s.p.x, p.y - s.p.y) <= 40 else { return false }
        if let control { return control != s.control }
        return s.control != nil
    }

    /// A tap that was not eaten has landed (the web's click): it is the mark for the next one.
    /// `moved`: how far the finger went between coming down and lifting.
    mutating func tapped(_ control: String?, at p: CGPoint, now: Double, moved: Double = 0) {
        if moved > 10 { spot = nil; return }                               // the end of a slide is no tap
        if let s = spot, s.pin, now - s.t < 0.7 { return }                 // the tap that only put the search keyboard away keeps its mark
        spot = Spot(p: p, t: now, control: control)
    }

    /// a touch that only put the keyboard away (Search, nothing typed): a second tap there does nothing either
    mutating func pin(at p: CGPoint, now: Double) { spot = Spot(p: p, t: now, control: nil, pin: true) }

    /// ✕ / back pressed at `p` (`open` false), or a story page opened by a tap at `p` (`open` true)
    mutating func closed(at p: CGPoint, now: Double, open: Bool) { close = Close(p: p, t: now, open: open) }
}
