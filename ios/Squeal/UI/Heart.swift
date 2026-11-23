import SwiftUI

/// How a heart badge is moving right now.
enum HeartMotion: Equatable {
    case still
    /// a like: the badge pops in (0 → 1.12 → .97 → 1), a pen draws the heart from its tip round both lobes, the ink fills it
    case draw(Date, Double)
    /// an unlike: the heart cracks like 💔 (halves part ±7° round the tip); `fadeBadge`: the whole badge fades away too
    case crack(Date, Double, fadeBadge: Bool)

    var start: Date? { switch self { case .still: return nil; case .draw(let d, _), .crack(let d, _, _): return d } }
    var duration: Double { switch self { case .still: return 0; case .draw(_, let ms), .crack(_, let ms, _): return ms / 1000 } }
}

/// The crack, in the heart's own 24-unit drawing (dip, zig, zag, zig, tip, down) — template.html CRACK_PTS
private let crackPts: [CGPoint] = [CGPoint(x: 12, y: 7.3), CGPoint(x: 10.3, y: 10.6), CGPoint(x: 13.7, y: 13.6), CGPoint(x: 11.1, y: 16.6),
                                   CGPoint(x: 12.6, y: 18.9), CGPoint(x: 12, y: 20.7), CGPoint(x: 12, y: 24)]

private struct CrackHalf: Shape {
    let left: Bool
    let box: CGFloat, heart: CGFloat
    func path(in rect: CGRect) -> Path {
        let o = (box - heart) / 2, k = heart / 24
        let pts = crackPts.map { CGPoint(x: o + $0.x * k, y: o + $0.y * k) }
        var p = Path()
        if left {
            p.move(to: .zero); p.addLine(to: CGPoint(x: box / 2, y: 0))
            pts.forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: 0, y: box))
        } else {
            p.move(to: CGPoint(x: box / 2, y: 0)); p.addLine(to: CGPoint(x: box, y: 0)); p.addLine(to: CGPoint(x: box, y: box))
            pts.reversed().forEach { p.addLine(to: $0) }
        }
        p.closeSubpath()
        return p
    }
}

/// The heart in a round badge (tiles: 39/21, preview: 40/27), with its like / unlike motion.
struct HeartBadge: View {
    var box: CGFloat
    var heart: CGFloat
    var circle: Color
    var ink: Color = .white
    var motion: HeartMotion = .still
    /// the preview's unlike: the halves fade out while the circle stays lit
    var fadeHalves = false
    /// the plain heart coming back after that unlike: 0 (unseen, at 70 % of its size) … 1 (there)
    var heartIn: Double = 1

    var body: some View {
        if motion == .still {
            face(at: 1)
        } else {
            TimelineView(.animation(minimumInterval: nil, paused: false)) { tl in
                let t = min(1, max(0, tl.date.timeIntervalSince(motion.start!) / max(0.001, motion.duration)))
                face(at: t)
            }
        }
    }

    @ViewBuilder private func face(at t: Double) -> some View {
        switch motion {
        case .still:
            ZStack {
                Circle().fill(circle)
                SVGShape(d: IconPath.heart).fill(ink).frame(width: heart, height: heart)
                    .opacity(heartIn).scaleEffect(0.7 + 0.3 * heartIn)
            }.frame(width: box, height: box)
        case .draw:
            let e = CubicBezier.easeOut(t)
            let pop = keyframes(e, [(0, 0), (0.3, 1.12), (0.5, 0.97), (1, 1)])
            let pen = CubicBezier(0.45, 0.05, 0.35, 1)(t)
            let drawn = 1 - keyframes(pen, [(0, 1), (0.14, 1), (0.17, 0.97), (0.78, 0)])
            let penOn = keyframes(pen, [(0, 0), (0.14, 0), (0.17, 1)])
            let ink = keyframes(e, [(0, 0), (0.66, 0), (1, 1)])
            let inkScale = keyframes(e, [(0, 0.6), (0.66, 0.6), (1, 1)])
            ZStack {
                Circle().fill(circle)
                ZStack {
                    SVGShape(d: IconPath.heart).fill(self.ink).opacity(ink)
                        .scaleEffect(inkScale, anchor: UnitPoint(x: 0.5, y: 0.6))
                    SVGShape(d: IconPath.heart).trim(from: 0, to: drawn)
                        .stroke(self.ink, style: StrokeStyle(lineWidth: 1.9 * heart / 24, lineCap: .round, lineJoin: .round))
                        .opacity(penOn)
                }.frame(width: heart, height: heart)
            }
            .frame(width: box, height: box)
            .scaleEffect(pop)
        case .crack(_, _, let fadeBadge):
            let open = CubicBezier(0.2, 0.9, 0.3, 1)(min(1, t / 0.45))
            let e = CubicBezier.easeIn(t)
            let fade = keyframes(e, [(0, 1), (0.45, 1), (1, 0)])
            let shrink = keyframes(e, [(0, 1), (0.45, 1), (1, 0.8)])
            let tip = UnitPoint(x: ((box - heart) / 2 + 12 * heart / 24) / box, y: ((box - heart) / 2 + 20.5 * heart / 24) / box)
            ZStack {
                Circle().fill(circle)
                ForEach([true, false], id: \.self) { left in
                    SVGShape(d: IconPath.heart).fill(ink).frame(width: heart, height: heart)
                        .frame(width: box, height: box)
                        .clipShape(CrackHalf(left: left, box: box, heart: heart))
                        .rotationEffect(.degrees((left ? -7 : 7) * open), anchor: tip)
                        .opacity(fadeHalves ? fade : 1)
                }
            }
            .frame(width: box, height: box)
            .opacity(fadeBadge ? fade : 1)
            .scaleEffect(fadeBadge ? shrink : 1)
        }
    }
}
