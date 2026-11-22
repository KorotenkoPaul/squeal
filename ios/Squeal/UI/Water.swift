import SwiftUI

/// One of the two waves: the curve over a 200×10 box (x every 0.5), filled down to the bottom.
struct WaveShape: Shape {
    let ys: [CGFloat]
    var crestOnly = false
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (i, y) in ys.enumerated() {
            let pt = CGPoint(x: r.minX + CGFloat(i) * 0.5 / 200 * r.width, y: r.minY + y / 10 * r.height)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        if !crestOnly { p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
        return p
    }
}

/// How a part button's water moves.
struct WaterMotion: Equatable {
    var riseFrom: Date? = nil        // the level rises from 0 (1 s), after `delay`
    var delay: Double = 0
    var wavesFrom: Date? = nil       // the two waves roll and then settle flat (preview timings: ≈3.3 s)
    var drainFrom: Date? = nil       // reset: the water drains down (1 s), its surface waking up again
    var drainLevel: Double = 0
}

/// "Water": a part fills from the bottom up to how much of it is read. Two waves roll against each other with a
/// faint light on the crest, then the surface settles flat and still (template.html .part .water).
struct WaterFill: View {
    let fraction: Double
    let motion: WaterMotion
    var color = Theme.water
    var backColor = Theme.water2

    var body: some View {
        let ends = [motion.riseFrom.map { $0.addingTimeInterval(motion.delay + 1.05) },
                    motion.wavesFrom.map { $0.addingTimeInterval(3.4) },
                    motion.drainFrom.map { $0.addingTimeInterval(1.05) }].compactMap { $0 }.max()
        let running = (ends ?? .distantPast) > Date()
        TimelineView(.animation(minimumInterval: nil, paused: !running)) { tl in
            GeometryReader { g in
                drawn(g.size, now: running ? tl.date : Date.distantFuture)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawn(_ size: CGSize, now: Date) -> some View {
        let W = size.width, H = size.height
        var level = fraction
        if let r = motion.riseFrom {
            let t = now.timeIntervalSince(r) - motion.delay
            level = fraction * CubicBezier.app(max(0, min(1, t)))
        }
        var wavesOn = false
        var x1: CGFloat = 0, x2: CGFloat = -W, s1 = 1.0, s2 = 1.0
        if let w = motion.wavesFrom, now != .distantFuture {
            let t = now.timeIntervalSince(w)
            wavesOn = t < 3.4
            if t < 4.4 { x1 = -CGFloat((t / 2.2).truncatingRemainder(dividingBy: 1)) * W }
            if t < 6.2 { x2 = -W + CGFloat((t / 3.1).truncatingRemainder(dividingBy: 1)) * W }
            s1 = 1 - CubicBezier(0.4, 0, 0.2, 1)(max(0, min(1, (t - 0.9) / 2.4)))
            s2 = 1 - CubicBezier(0.4, 0, 0.2, 1)(max(0, min(1, (t - 0.7) / 2.2)))
        }
        if let d = motion.drainFrom {
            let t = now == .distantFuture ? 1 : max(0, min(1, now.timeIntervalSince(d)))
            level = motion.drainLevel * (1 - CubicBezier(0.45, 0, 0.55, 1)(t))
            wavesOn = t < 1
            x1 = 0; x2 = -W
            s1 = keyframes(t, [(0, 1), (0.85, 1), (1, 0)]); s2 = s1
        }
        let fillH = H * level
        let top = H - fillH
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: W, height: fillH).offset(y: top)
            if wavesOn && fillH > 0 {
                WaveShape(ys: WaveData.back).fill(backColor)
                    .frame(width: 2 * W, height: 10)
                    .scaleEffect(x: 1, y: s2, anchor: .bottom).opacity(s2)
                    .offset(x: x2, y: top + 1 - 10)
                ZStack {
                    WaveShape(ys: WaveData.front).fill(color)
                    WaveShape(ys: WaveData.front, crestOnly: true).stroke(Color(red: 214 / 255, green: 204 / 255, blue: 1, opacity: 0.45), lineWidth: 0.5)
                }
                .frame(width: 2 * W, height: 8)
                .scaleEffect(x: 1, y: s1, anchor: .bottom).opacity(s1)
                .offset(x: x1, y: top + 1 - 8)
            }
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .clipped()
    }
}
