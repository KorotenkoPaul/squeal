import UIKit
import QuartzCore

/// The chat's clock: seconds, the same one CADisplayLink and CACurrentMediaTime use.
func chatNow() -> Double { CACurrentMediaTime() }

/// "Reduce Motion" on the phone: nothing slides, grows or glides (the web's reduce()).
func reduceMotion() -> Bool { UIAccessibility.isReduceMotionEnabled }

/// Calls `step` once a frame while running (requestAnimationFrame for the chat's own motion).
final class FrameLoop {
    private var link: CADisplayLink?
    private let step: (Double) -> Void
    init(_ step: @escaping (Double) -> Void) { self.step = step }
    deinit { link?.invalidate() }

    var running: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: Target(self), selector: #selector(Target.tick))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() { link?.invalidate(); link = nil }

    fileprivate func fire() { step(CACurrentMediaTime()) }

    private final class Target: NSObject {
        weak var loop: FrameLoop?
        init(_ l: FrameLoop) { loop = l }
        @objc func tick(_ l: CADisplayLink) { loop?.fire() }
    }
}
