import SwiftUI

/// A small SVG path reader, so the web prototype's icons (and later the chat doodles) are drawn from the very
/// same path data. Supports M L H V C S Q T A Z, absolute and relative.
struct SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var tokens = Tokenizer(d)
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCtrl: CGPoint? = nil, lastQuad: CGPoint? = nil
        while let next = tokens.peek() {
            if case .cmd(let c) = next { cmd = c; _ = tokens.next() }
            let rel = cmd.isLowercase
            func pt() -> CGPoint? {
                guard let x = tokens.number(), let y = tokens.number() else { return nil }
                return rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            }
            switch cmd.uppercased().first! {
            case "M":
                guard let p = pt() else { return path }
                path.move(to: p); cur = p; start = p; lastCtrl = nil; lastQuad = nil
                cmd = rel ? "l" : "L"                                    // further pairs are line-tos
            case "L":
                guard let p = pt() else { return path }
                path.addLine(to: p); cur = p; lastCtrl = nil; lastQuad = nil
            case "H":
                guard let x = tokens.number() else { return path }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: cur); lastCtrl = nil; lastQuad = nil
            case "V":
                guard let y = tokens.number() else { return path }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: cur); lastCtrl = nil; lastQuad = nil
            case "C":
                guard let c1 = pt(), let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); cur = p; lastCtrl = c2; lastQuad = nil
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                guard let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); cur = p; lastCtrl = c2; lastQuad = nil
            case "Q":
                guard let c = pt(), let p = pt() else { return path }
                path.addQuadCurve(to: p, control: c); cur = p; lastQuad = c; lastCtrl = nil
            case "T":
                let c = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                guard let p = pt() else { return path }
                path.addQuadCurve(to: p, control: c); cur = p; lastQuad = c; lastCtrl = nil
            case "A":
                guard let rx = tokens.number(), let ry = tokens.number(), let rot = tokens.number(),
                      let large = tokens.flag(), let sweep = tokens.flag(), let p = pt() else { return path }
                arc(&path, from: cur, to: p, rx: rx, ry: ry, angle: rot, large: large, sweep: sweep)
                cur = p; lastCtrl = nil; lastQuad = nil
            case "Z":
                path.closeSubpath(); cur = start; lastCtrl = nil; lastQuad = nil
                if let t = tokens.peek(), case .num = t { cmd = rel ? "l" : "L" }
            default:
                _ = tokens.next()
            }
        }
        return path
    }

    /// SVG elliptical arc → cubic Béziers (SVG spec, appendix F.6)
    private static func arc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: CGFloat, ry: CGFloat, angle: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rx), ry = abs(ry)
        if rx == 0 || ry == 0 || p0 == p1 { path.addLine(to: p1); return }
        let phi = angle * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
        let cx = cosP * cx1 - sinP * cy1 + (p0.x + p1.x) / 2, cy = sinP * cx1 + cosP * cy1 + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a
        }
        let t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segs = Int(ceil(abs(dt) / (.pi / 2)))
        let step = dt / CGFloat(segs)
        let k = 4 / 3 * tan(step / 4)
        var t = t1
        func point(_ a: CGFloat) -> CGPoint { CGPoint(x: cx + rx * cos(a) * cosP - ry * sin(a) * sinP, y: cy + rx * cos(a) * sinP + ry * sin(a) * cosP) }
        func deriv(_ a: CGFloat) -> CGPoint { CGPoint(x: -rx * sin(a) * cosP - ry * cos(a) * sinP, y: -rx * sin(a) * sinP + ry * cos(a) * cosP) }
        for _ in 0..<segs {
            let a = t, b = t + step
            let pa = point(a), pb = point(b), da = deriv(a), db = deriv(b)
            path.addCurve(to: pb, control1: CGPoint(x: pa.x + k * da.x, y: pa.y + k * da.y), control2: CGPoint(x: pb.x - k * db.x, y: pb.y - k * db.y))
            t = b
        }
    }

    private enum Token: Equatable { case cmd(Character), num(CGFloat) }

    private struct Tokenizer {
        let chars: [Character]
        var i = 0
        init(_ s: String) { chars = Array(s) }
        mutating func skip() { while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" { i += 1 } }
        mutating func peek() -> Token? {
            skip(); guard i < chars.count else { return nil }
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" { return .cmd(c) }
            let save = i; defer { i = save }
            return number().map { .num($0) }
        }
        mutating func next() -> Token? {
            skip(); guard i < chars.count else { return nil }
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" { i += 1; return .cmd(c) }
            return number().map { .num($0) }
        }
        mutating func flag() -> Bool? {
            skip(); guard i < chars.count else { return nil }
            let c = chars[i]; guard c == "0" || c == "1" else { return nil }
            i += 1; return c == "1"
        }
        mutating func number() -> CGFloat? {
            skip(); guard i < chars.count else { return nil }
            var s = ""
            var seenDot = false, seenExp = false
            if chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c) }
                else if c == "." && !seenDot && !seenExp { seenDot = true; s.append(c) }
                else if (c == "e" || c == "E") && !seenExp { seenExp = true; s.append(c); if i + 1 < chars.count, chars[i + 1] == "-" || chars[i + 1] == "+" { i += 1; s.append(chars[i]) } }
                else { break }
                i += 1
            }
            return Double(s).map { CGFloat($0) }
        }
    }
}

/// A shape drawn from SVG path data in a given viewBox, scaled to fit its frame (preserveAspectRatio xMidYMid meet).
struct SVGShape: Shape {
    let d: String
    var viewBox = CGRect(x: 0, y: 0, width: 24, height: 24)
    func path(in rect: CGRect) -> Path {
        let p = SVGPath.parse(d)
        let s = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let ox = rect.minX + (rect.width - viewBox.width * s) / 2 - viewBox.minX * s
        let oy = rect.minY + (rect.height - viewBox.height * s) / 2 - viewBox.minY * s
        return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: ox, ty: oy))
    }
}
