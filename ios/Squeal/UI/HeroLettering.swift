import SwiftUI

/// Each story's title on the slider is lettering that carries its mood: its own face, its own place on the card,
/// its own small trick (template.html LETTERING). Other languages rebuild it from the translated title in the same
/// spirit (LOCAL_LETTERING): the leading words take the small line, the last word the big one.
struct HeroLettering: View {
    let id: String
    let title: String
    let lang: String
    let card: CGSize

    @State private var natural: CGSize = .zero

    var body: some View {
        let spec = Self.spec(id)
        let content = Self.content(id, title: title, local: lang != "en")
            .shadow(color: spec.shadow ? .black.opacity(0.6) : .clear, radius: 6, x: 0, y: 2)
        let W = card.width, H = card.height, M: CGFloat = 12
        let w = spec.fullWidth ? W : natural.width, h = natural.height
        var s: CGFloat = 1
        if w > 0 && h > 0 {
            let room = min(spec.fullWidth ? .infinity : (W - 2 * M) / w, (H - 2 * M) / h)   // a full-width block: its words decide, not its box
            if room < 1 { s = room * 0.98 }
        }
        let sw = w * s, sh = h * s
        var x: CGFloat = spec.left != nil && spec.right != nil ? (spec.fullWidth ? 0 : (W - sw) / 2)
            : spec.left != nil ? spec.left! : W - (spec.right ?? 0) - sw
        var y: CGFloat = spec.centerY ? (H - sh) / 2 : spec.top != nil ? spec.top! : H - (spec.bottom ?? 0) - sh
        // the right size but pushed past an edge: nudge it back in (fitLettering)
        if !spec.fullWidth { x += max(0, M - x) - max(0, x + sw - (W - M)) }
        y += max(0, M - y) - max(0, y + sh - (H - M))
        return content
            .fixedSize(horizontal: !spec.fullWidth, vertical: true)
            .frame(width: spec.fullWidth ? W : nil)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { natural = $0 })
            .scaleEffect(s)
            .position(x: x + sw / 2, y: y + sh / 2)
            .allowsHitTesting(false)
    }

    struct Spec {
        var left: CGFloat? = nil, right: CGFloat? = nil, top: CGFloat? = nil, bottom: CGFloat? = nil
        var centerY = false
        var fullWidth = false
        var shadow = true
    }

    static func spec(_ id: String) -> Spec {
        switch id {
        case "nobodys-home": return Spec(left: 0, right: 0, bottom: 22)
        case "clown": return Spec(left: 22, top: 20)
        case "first-impressions": return Spec(right: 20, bottom: 18)
        case "grave": return Spec(left: 0, right: 0, top: 22)
        case "haunted": return Spec(right: 22, top: 26)
        case "last-train-out": return Spec(left: 18, top: 18, shadow: false)
        case "love-till-death": return Spec(left: 0, right: 0, bottom: 20)
        case "reunion": return Spec(right: 26, bottom: 24)
        case "skinless": return Spec(left: 14, bottom: 10)
        case "slice": return Spec(left: 0, right: 0, centerY: true)
        case "the-crossroad": return Spec(left: 22, centerY: true)
        case "the-doctor": return Spec(left: 20, bottom: 20)
        case "unwanted-guest": return Spec(left: 0, right: 0, centerY: true, fullWidth: true)
        case "clinical-love": return Spec(left: 22, bottom: 20)
        case "frenemy": return Spec(left: 0, right: 0, centerY: true)
        case "perfect-match": return Spec(left: 22, top: 22)
        case "the-crushing-love": return Spec(right: 20, bottom: 18)
        case "mystery-girlfriend": return Spec(left: 22, bottom: 20)
        case "the-reunion-affair": return Spec(left: 0, right: 0, bottom: 18)
        case "two-knocks": return Spec(left: 0, right: 0, centerY: true)
        case "under-wrong-hands": return Spec(left: 22, centerY: true)
        default: return Spec(left: 18, bottom: 18)
        }
    }

    // MARK: - the letters

    /// one line of lettering: a CSS block span with its own face, size, letter-spacing (em) and line-height
    static func line(_ t: String, _ family: String, _ size: CGFloat, _ color: Color, track: CGFloat = 0, lh: CGFloat = 1.05, opacity: Double = 1) -> some View {
        Text(t).font(Lettering.font(family, size)).tracking(track * size).foregroundStyle(color).opacity(opacity)
            .padding(.trailing, -track * size)        // margin-right: -<spacing>: the last letter's spacing does not count
            .fixedSize()
            .frame(height: size * lh)
    }

    /// one letter at a time (letters()), each with its own move
    static func letters(_ t: String, _ family: String, _ size: CGFloat, _ color: Color, track: CGFloat = 0, lh: CGFloat = 1.05,
                        _ f: @escaping (Int, Int) -> (dy: CGFloat, rot: Double, opacity: Double, dx: CGFloat, blur: CGFloat)) -> some View {
        let chars = Array(t)
        return HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { k, c in
                let m = c == " " ? (dy: CGFloat(0), rot: 0.0, opacity: 1.0, dx: CGFloat(0), blur: CGFloat(0)) : f(k, chars.count)
                Text(String(c)).font(Lettering.font(family, size)).tracking(track * size).foregroundStyle(color)
                    .fixedSize()
                    .blur(radius: m.blur)
                    .opacity(m.opacity)
                    .rotationEffect(.degrees(m.rot))
                    .offset(x: m.dx, y: m.dy)
            }
        }
        .padding(.trailing, -track * size)
        .frame(height: size * lh)
    }

    static func twoParts(_ t: String) -> (String, String) {
        let w = t.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        return w.count > 1 ? (w.dropLast().joined(separator: " "), w.last!) : ("", t)
    }

    static let red = Color(hex: 0xd4606b)
    static let clownDy: [CGFloat] = [0, 8, -4, 10, 2], clownRot: [Double] = [-12, 6, -4, 9, -7]
    static let doctorDy: [CGFloat] = [0, 1.5, -1, 2, -0.5, 1, -1.5, 0.5, 0, 1], doctorOp: [Double] = [1, 0.85, 0.95, 0.8, 1, 0.9]

    @ViewBuilder
    static func content(_ id: String, title t: String, local: Bool) -> some View {
        switch id {
        case "nobodys-home":
            let c = Color(hex: 0xd9d4e8)
            let ab = local ? twoParts(t) : ("nobody’s", "home")
            let a = ab.0, b = ab.1
            VStack(spacing: 0) {
                if !a.isEmpty { line(a, "Cormorant SC", 15, c, track: 0.6, lh: 1.1, opacity: 0.75) }
                line(b, "Cormorant SC", local ? 40 : 44, c, track: local ? 0.3 : 0.42, lh: 1.1, opacity: 0.85)
            }
        case "clown":
            letters(t, "Rubik Wet Paint", 58, Color(hex: 0xf2f4fa)) { k, _ in
                (dy: clownDy[k % 5], rot: clownRot[k % 5], opacity: 1, dx: 0, blur: 0)
            }
        case "first-impressions":
            let c = Color(hex: 0xf1e6dc)
            let ab = local ? twoParts(t) : ("First", "Impressions")
            let a = ab.0, b = ab.1
            VStack(alignment: .trailing, spacing: 0) {
                if !a.isEmpty { line(a, "DM Serif Display", 20, c, lh: 0.95, opacity: 0.75) }
                line(b, "DM Serif Display", 40, c, lh: 0.95)
            }
        case "grave":
            let c = Color(hex: 0xe2dfda)
            Text(t.uppercased()).font(Lettering.font("Cinzel", 34)).tracking(17).foregroundStyle(c)
                .fixedSize()
                .padding(.top, 6).padding(.bottom, 4).padding(.leading, 17)
                .overlay(alignment: .top) { Rectangle().fill(c.opacity(0.45)).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(c.opacity(0.45)).frame(height: 1) }
        case "haunted":
            letters(t, "IM Fell English", 46, Color(hex: 0xe4e0f0)) { k, n in
                (dy: CGFloat(-2 * k), rot: 0.0, opacity: 1 - Double(k) / Double(n) * 0.85, dx: CGFloat(0), blur: CGFloat(0))
            }
        case "last-train-out":
            Text(t.uppercased()).font(Lettering.font("Big Shoulders Display", 28)).tracking(28 * 0.14).foregroundStyle(Color(hex: 0xf4b740))
                .fixedSize()
                .frame(height: 28 * 1.05)
                .padding(.top, 6).padding(.bottom, 5).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255, opacity: 0.82)))
        case "love-till-death":
            let c = Color(hex: 0xfbe3e6), f = Lettering.font("Pinyon Script", 46)
            if local {
                let ab = twoParts(t)
                let a = ab.0, b = ab.1
                (Text(a + " ").font(f).foregroundColor(c) + Text(b).font(f).foregroundColor(red)).fixedSize().frame(height: 46 * 1.05)
            } else {
                (Text("Love ").font(f).foregroundColor(c) + Text("till").font(Lettering.font("Pinyon Script", 26)).foregroundColor(c.opacity(0.8))
                 + Text(" ").font(f) + Text("Death").font(f).foregroundColor(red)).fixedSize().frame(height: 46 * 1.05)
            }
        case "reunion":
            let c = Color(hex: 0xf6efe2)
            line(t, "Caveat", 48, c)
                .overlay(alignment: .bottom) { WavyLine().stroke(c.opacity(0.6), lineWidth: 2).frame(height: 5).offset(y: 6) }
                .rotationEffect(.degrees(-7))
        case "skinless":
            line(t, "Rubik Distressed", 84, Color(hex: 0xecdcd8), track: -0.02, opacity: 0.9)
        case "slice":
            let u = t.uppercased(), c = Color(hex: 0xf4f2f7)
            ZStack {
                line(u, "Anton", 66, c, track: 0.08).clipShape(SlicePart(top: true)).offset(x: -4)
                line(u, "Anton", 66, c, track: 0.08).clipShape(SlicePart(top: false)).offset(x: 4, y: 1)
            }
        case "the-crossroad":
            let c = Color(hex: 0xf4e3ea)
            let ab = local ? twoParts(t) : ("THE", "crossroad")
            let a = ab.0, b = ab.1
            let m = Int(ceil(Double(b.count) / 2))
            let b1 = local ? String(b.prefix(m)) : "cross", b2 = local ? String(b.dropFirst(m)) : "road"
            VStack(alignment: .leading, spacing: 2) {
                if !a.isEmpty { line(a.uppercased(), "Playfair Display", 16, c, track: 0.3, lh: 1, opacity: 0.7) }
                HStack(spacing: 0) {
                    line(b1, "Playfair Display", 40, c, lh: 1).rotationEffect(.degrees(-8), anchor: .bottomTrailing).offset(y: -6)
                    line(b2, "Playfair Display", 40, c, lh: 1).rotationEffect(.degrees(9), anchor: .bottomLeading).offset(y: 4)
                }
            }
        case "the-doctor":
            letters(t, "Special Elite", 30, Color(hex: 0xe6eeec)) { k, _ in
                (dy: doctorDy[k % 10], rot: 0, opacity: doctorOp[k % 6], dx: 0, blur: 0)
            }
        case "unwanted-guest":
            let c = Color(hex: 0xf2e6dd)
            let ab = local ? twoParts(t) : ("UNWANTED", "GUEST")
            let a = ab.0, b = ab.1
            VStack(spacing: 0) {
                if !a.isEmpty { line(a.uppercased(), "Monoton", local ? 24 : 26, c, track: 0.12, lh: 1.15).frame(maxWidth: .infinity) }
                line(b.uppercased(), "Monoton", local ? 36 : 40, c, lh: 1.15).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 18)
            }
        case "clinical-love":
            let ab = local ? twoParts(t) : ("clinical", "Love")
            let a = ab.0, b = ab.1
            VStack(alignment: .leading, spacing: 2) {
                if !a.isEmpty { line(a.lowercased(), "Major Mono Display", 14, Color(hex: 0xeef1f4), track: 0.32, lh: 1, opacity: 0.75) }
                line(b, "Pinyon Script", local ? 48 : 52, Color(hex: 0xf6d6dc), lh: 1)
            }
        case "frenemy":
            let u = local ? t.uppercased() : "FRENEMY"
            let m = local ? Int(ceil(Double(u.count) * 0.55)) : 4
            let f = Lettering.font("Anton", 58), tr: CGFloat = 58 * 0.06
            (Text(String(u.prefix(m))).font(f).tracking(tr).foregroundColor(Color(hex: 0xf3f0f5))
             + Text(String(u.dropFirst(m))).font(f).tracking(tr).foregroundColor(red)).fixedSize().frame(height: 58 * 1.05)
        case "perfect-match":
            let c = Color(hex: 0xf3e9df)
            VStack(alignment: .leading, spacing: 0) {
                line(t, "DM Serif Display", 40, c, lh: 0.9)
                line(t, "DM Serif Display", 40, c, lh: 0.9).scaleEffect(x: 1, y: -1).opacity(0.28)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .clear, location: 0.8)], startPoint: .top, endPoint: .bottom))
            }
        case "the-crushing-love":
            let ab = local ? twoParts(t) : ("the", "Crushing")
            let a = ab.0, b = ab.1
            VStack(alignment: .trailing, spacing: 0) {
                if !a.isEmpty { line(a, "Cormorant SC", 14, Color(hex: 0xf1e4ea), track: 0.4, lh: 0.95, opacity: 0.7) }
                line(b.uppercased(), "Big Shoulders Display", local ? 48 : 52, Color(hex: 0xf1e4ea), track: -0.06, lh: 0.95)
                    .scaleEffect(x: 0.82, y: 1, anchor: .trailing)
                if !local { line("Love", "Pinyon Script", 34, Color(hex: 0xe9b4bb), lh: 0.95).padding(.top, -4) }
            }
        case "mystery-girlfriend":
            let c = Color(hex: 0xf4ece4)
            let ab = local ? twoParts(t) : ("MYSTERY", "girlfriend")
            let a = ab.0, b = ab.1
            VStack(alignment: .leading, spacing: 2) {
                if !a.isEmpty {
                    letters(a.uppercased(), "Cinzel", local ? 26 : 30, c, track: 0.18, lh: 1) { k, _ in
                        (dy: 0, rot: 0, opacity: k % 2 == 1 ? 0.8 : 1, dx: 0, blur: k % 2 == 1 ? 2.2 : 0)
                    }
                }
                line(b, "Caveat", 40, c, lh: 1)
            }
        case "the-reunion-affair":
            let c = Color(hex: 0xefe6d6)
            let ab = local ? twoParts(t) : ("The Reunion", "Affair")
            let a = ab.0, b = ab.1
            VStack(spacing: -2) {
                if !a.isEmpty { line(a, "Cormorant SC", local ? 22 : 24, c, track: local ? 0.3 : 0.34, lh: 1) }
                line(b, "Pinyon Script", 44, c, lh: 1)
            }
        case "two-knocks":
            let c = Color(hex: 0xece6f2)
            let ab = local ? twoParts(t) : ("two", "KNOCKS")
            let a = ab.0, b = ab.1
            let u = b.uppercased(), size: CGFloat = local ? 50 : 56, tr: CGFloat = local ? 0.12 : 0.14
            VStack(spacing: 0) {
                if !a.isEmpty { line(a.lowercased(), "Cormorant SC", 16, c, track: 0.6, lh: 1, opacity: 0.7) }
                letters(u, "Anton", size, c, track: tr, lh: 1) { k, n in
                    // the two Ks (first and last letter in a translation) jolt as if struck
                    let first = local ? k == 0 : k == 0, last = local ? k == n - 1 : k == 4
                    if n > 2 && first { return (dy: -2, rot: -6, opacity: 1, dx: -3, blur: 0) }
                    if n > 2 && last { return (dy: 2, rot: 6, opacity: 1, dx: 3, blur: 0) }
                    return (dy: 0, rot: 0, opacity: 1, dx: 0, blur: 0)
                }
            }
        case "under-wrong-hands":
            let words = local ? t.split(separator: " ").map(String.init) : ["Under", "Wrong", "Hands"]
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                    let flip = words.count > 2 && i == 1
                    line(w.uppercased(), "Anton", 36, flip ? red : Color(hex: 0xf2eef4), track: 0.06)
                        .rotationEffect(.degrees(flip ? 180 : 0))
                }
            }
        default:
            Text(t).font(AppFont.ui(26, 600)).foregroundStyle(.white).fixedSize()
        }
    }
}

private struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// the "slice" cut: the top half slips off the bottom half (clip-path polygons of the web)
private struct SlicePart: Shape {
    let top: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if top {
            p.addLines([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.minY + r.height * 0.46), CGPoint(x: r.minX, y: r.minY + r.height * 0.56)])
        } else {
            p.addLines([CGPoint(x: r.minX, y: r.minY + r.height * 0.57), CGPoint(x: r.maxX, y: r.minY + r.height * 0.47), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)])
        }
        p.closeSubpath()
        return p
    }
}

/// text-decoration: underline wavy
private struct WavyLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let wave: CGFloat = 8, amp = r.height / 2
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        var x = r.minX
        var up = true
        while x < r.maxX {
            let nx = min(r.maxX, x + wave / 2)
            p.addQuadCurve(to: CGPoint(x: nx, y: r.midY), control: CGPoint(x: (x + nx) / 2, y: r.midY + (up ? -amp : amp) * 2))
            x = nx; up.toggle()
        }
        return p
    }
}
