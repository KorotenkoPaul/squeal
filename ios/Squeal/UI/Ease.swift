import Foundation
import SwiftUI

/// CSS cubic-bezier() timing, for animations played frame by frame (the same curves as the web prototype).
struct CubicBezier {
    let cx, bx, ax, cy, by, ay: Double
    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        cx = 3 * x1; bx = 3 * (x2 - x1) - cx; ax = 1 - cx - bx
        cy = 3 * y1; by = 3 * (y2 - y1) - cy; ay = 1 - cy - by
    }
    private func sx(_ t: Double) -> Double { ((ax * t + bx) * t + cx) * t }
    private func sy(_ t: Double) -> Double { ((ay * t + by) * t + cy) * t }
    private func dx(_ t: Double) -> Double { (3 * ax * t + 2 * bx) * t + cx }
    func callAsFunction(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var t = x
        for _ in 0..<8 {
            let e = sx(t) - x
            if abs(e) < 1e-6 { return sy(t) }
            let d = dx(t)
            if abs(d) < 1e-6 { break }
            t -= e / d
        }
        var lo = 0.0, hi = 1.0; t = x
        while lo < hi {
            let v = sx(t)
            if abs(v - x) < 1e-6 { break }
            if x > v { lo = t } else { hi = t }
            t = (lo + hi) / 2
            if hi - lo < 1e-7 { break }
        }
        return sy(t)
    }

    static let ease = CubicBezier(0.25, 0.1, 0.25, 1)
    static let easeIn = CubicBezier(0.42, 0, 1, 1)
    static let easeOut = CubicBezier(0, 0, 0.58, 1)
    static let easeInOut = CubicBezier(0.42, 0, 0.58, 1)
    static let app = CubicBezier(0.25, 0.8, 0.25, 1)      // EASE in template.html
    static let sheet = CubicBezier(0.32, 0.72, 0, 1)
}

/// Keyframes like the Web Animations API: `t` is the (already eased) iteration progress, values in between are
/// interpolated linearly (or with `ease` per segment, like a CSS @keyframes animation's timing function).
func keyframes(_ t: Double, _ frames: [(Double, Double)], ease: CubicBezier? = nil) -> Double {
    guard let first = frames.first else { return 0 }
    if t <= first.0 { return first.1 }
    for i in 1..<frames.count where t <= frames[i].0 {
        let (a, va) = frames[i - 1], (b, vb) = frames[i]
        let f = b > a ? (t - a) / (b - a) : 1
        return va + (vb - va) * (ease.map { $0(f) } ?? f)
    }
    return frames.last!.1
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

extension Animation {
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ d: Double) -> Animation { .timingCurve(x1, y1, x2, y2, duration: d) }
}
