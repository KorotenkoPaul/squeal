import SwiftUI
import UIKit

/// Every touch of the app passes here before anything else hears of it, as the web's window-level capture listeners
/// do: the one rule for double taps needs to know where each finger came down. (UIWindow.sendEvent is exchanged for
/// ours once, at launch — a SwiftUI app has no window class of its own to override it in.)
///
/// Safeguards. The watcher only ever adds knowledge; nothing waits for it:
/// - if the exchange cannot be made, or touches stop arriving here, `Taps.allows` has no touch to judge by and says
///   yes — every control simply works, without the double-tap rule (unit test `TapsTests`);
/// - a touch seen long ago is never taken for the tap under way (`Taps.fresh`);
/// - the exchange itself is checked by a unit test in the running app, and the UI tests press real controls and read
///   `Taps.seen` back through the screen (`TouchProbe`), so a system update that breaks it fails CI, not a reader.
extension UIWindow {
    private static var watching = false
    static var watchesTouches: Bool { watching }

    static func watchTouches() {
        guard !watching, let a = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let b = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.squeal_sendEvent(_:))) else { return }
        // exchanged only when both are UIWindow's very own methods of the same shape (never a half-made exchange)
        guard method_getTypeEncoding(a).map({ String(cString: $0) }) == method_getTypeEncoding(b).map({ String(cString: $0) }) else { return }
        method_exchangeImplementations(a, b)
        watching = true
    }

    @objc func squeal_sendEvent(_ event: UIEvent) {
        if event.type == .touches, let all = event.allTouches { MainActor.assumeIsolated { Taps.shared.see(all) } }
        squeal_sendEvent(event)                 // the original (the two are exchanged)
    }
}

/// The app's taps under the one rule for double taps (SpotRule = the web's SPOT and CLOSE_TAP). Every control asks
/// `allows("its name")` before it acts; a tap on no control is noted by itself when the finger lifts.
@MainActor
final class Taps {
    static let shared = Taps()

    var rule = SpotRule()
    /// fingers on the screen right now (the web's FINGERS)
    private(set) var fingers = 0
    /// called when the last finger lifts
    var onFingersUp: [String: () -> Void] = [:]
    /// called when a finger comes down (window coordinates), before any control hears of it
    var onDown: [String: (CGPoint) -> Void] = [:]

    private var seq = 0
    private weak var touch: UITouch?
    private var down: (p: CGPoint, t: Double)? = nil
    private var last = CGPoint.zero
    private var claimed = false
    private var verdict: (seq: Int, control: String?, ok: Bool)? = nil
    private var blank: (seq: Int, before: SpotRule.Spot?)? = nil
    private var eatSeq = -1
    /// when the watched finger last lifted, and how many touches have been seen at all (tests)
    private var upT = -1e9
    private(set) var seen = 0

    static func now() -> Double { CACurrentMediaTime() }

    /// Is the touch we know of the tap being judged right now? Yes while its finger is down, and for a moment after
    /// it lifts (a tap is handled as the finger leaves). Otherwise what we know is an old touch — the watcher has
    /// missed this one — and it must not be judged by where and when that old touch was.
    private var fresh: Bool { touch != nil || Self.now() - upT < 0.6 }

    fileprivate func see(_ touches: Set<UITouch>) {
        let mine = touches.filter { t in
            guard let w = t.window else { return true }
            let name = String(describing: type(of: w))
            return !name.contains("Keyboard") && !name.contains("TextEffects")
        }
        let before = fingers
        fingers = mine.filter { $0.phase != .ended && $0.phase != .cancelled }.count
        if before > 0 && fingers == 0 { DispatchQueue.main.async { [self] in if fingers == 0 { onFingersUp.values.forEach { $0() } } } }
        if touch == nil, let t = mine.first(where: { $0.phase == .began }) {            // the first finger only (isPrimary)
            touch = t; seq += 1; claimed = false; seen += 1
            let p = t.location(in: nil)
            down = (p, Self.now()); last = p
            onDown.values.forEach { $0(p) }
        }
        guard let t = touch, mine.contains(t) else { return }
        last = t.location(in: nil)
        if t.phase == .ended || t.phase == .cancelled {
            touch = nil; upT = Self.now()
            guard t.phase == .ended, let d = down else { return }
            let my = seq, up = last, moved = Double(hypot(up.x - d.p.x, up.y - d.p.y))
            // a tap on no control: noted once every control under the finger has had its say
            DispatchQueue.main.async { [self] in
                guard seq == my, !claimed, eatSeq != my, moved <= 10, !rule.eats(nil, at: d.p, now: d.t) else { return }
                blank = (my, rule.spot)
                rule.tapped(nil, at: up, now: Self.now(), moved: moved)
            }
        }
    }

    /// A control (or, with nil, the conversation: something that reads a tap but is no control) asks whether the tap
    /// under way is its to take. False: it is the second half of a double tap on something else — do nothing.
    /// `at`: where the tap is (window coordinates), for a tap that came with no touch of ours (tests).
    func allows(_ control: String?, at: CGPoint? = nil) -> Bool {
        let now = Self.now()
        if down != nil, !fresh { down = nil; verdict = nil; blank = nil }     // an old touch says nothing about this tap
        if eatSeq == seq, down != nil { return false }
        guard let p = down?.p ?? at else { return true }
        if let b = blank, b.seq == seq { rule.spot = b.before; blank = nil }     // this very tap was noted as one on no control: it is not
        if let v = verdict, v.seq == seq, v.control == control, down != nil { return v.ok }   // asked again in the same touch (pressed, then lifted)
        claimed = true
        let ok = !rule.eats(control, at: p, now: down?.t ?? now)
        verdict = (seq, control, ok)
        if ok { rule.tapped(control, at: down == nil ? p : last, now: now, moved: down.map { Double(hypot(last.x - $0.p.x, last.y - $0.p.y)) } ?? 0) }
        return ok
    }

    /// the touch under way does nothing more (it closed an open "Remove", it put the keyboard away)
    func eatThisTouch() { eatSeq = seq }
    /// where the finger of the touch under way (or the last one) came down
    var downPoint: CGPoint? { down?.p }

    /// ✕ or the chat's back arrow was pressed: for 0.7 s a touch at that place presses nothing under it
    func closeTap() { if let p = down?.p { rule.closed(at: p, now: Self.now(), open: false) } }
    /// a story page was opened by this tap: for 0.7 s a touch at that place presses nothing on the new page
    func openTap() { if let p = down?.p { rule.closed(at: p, now: Self.now(), open: true) } }
    /// the tap that only put the search keyboard away
    func pin() { if let p = down?.p { rule.pin(at: p, now: Self.now()) } }

    /// tests
    func reset() { rule = SpotRule(); down = nil; touch = nil; verdict = nil; blank = nil; eatSeq = -1; upT = -1e9 }
}

extension View {
    /// A control's tap, under the one rule for double taps.
    func tap(_ control: String, perform action: @escaping () -> Void) -> some View {
        onTapGesture { if Taps.shared.allows(control) { action() } }
    }
}

/// The app's one toast (template.html toast()): a line over the tab bar for 1.8 s.
struct ToastLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppFont.ui(14)).foregroundStyle(.white).multilineTextAlignment(.center)
            .accessibilityIdentifier("toast")
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.field))
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .offset(y: 8)))
            .allowsHitTesting(false)
    }
}
