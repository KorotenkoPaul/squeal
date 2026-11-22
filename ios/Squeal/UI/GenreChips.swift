import SwiftUI
import UIKit

/// Genres on Home (All / Horror / Thriller / Romance): one violet oval under the words, like the part disc in the chat.
/// Drag it 1:1 (its width blends between neighbours), let go — it glides to the nearest and the genre switches;
/// tap a genre — it glides there (IDEAS.md «Жанры на главной»).
struct GenreChips: View {
    @EnvironmentObject var model: AppModel
    static let keys = ["all", "horror", "thriller", "romance"]

    @State private var pos: CGFloat = -1          // centre of the oval, in row coordinates
    @State private var dragBase: CGFloat? = nil
    @State private var horizontal: Bool? = nil
    @State private var glide: Int = 0

    private let font = AppFont.uiFont(14, 600)
    private var widths: [CGFloat] {
        Self.keys.map { ceil((model.genreName($0) as NSString).size(withAttributes: [.font: font]).width) + 32 }
    }
    private var centres: [CGFloat] {
        var x: CGFloat = 0
        return widths.map { w in defer { x += w + 8 }; return x + w / 2 }
    }
    private var height: CGFloat { ceil(font.lineHeight) + 14 }

    var body: some View {
        let ws = widths, cs = centres
        let index = Self.keys.firstIndex(of: model.genre) ?? 0
        let at = pos < 0 ? cs[index] : pos
        let sh = shape(at, ws, cs), ovalW = sh.0, near = sh.1
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        ForEach(Array(Self.keys.enumerated()), id: \.offset) { k, key in
                            Capsule().fill(Theme.field).frame(width: ws[k], height: height).id(key)
                        }
                    }
                    Capsule().fill(Theme.accent).frame(width: ovalW, height: height).offset(x: at - ovalW / 2)
                    HStack(spacing: 8) {
                        ForEach(Array(Self.keys.enumerated()), id: \.offset) { k, key in
                            Text(model.genreName(key)).font(Font(font))
                                .foregroundStyle(k == near ? Theme.text : Theme.muted)
                                .animation(.linear(duration: 0.15), value: near)
                                .frame(width: ws[k], height: height)
                                .contentShape(Rectangle().inset(by: -6))
                                .onTapGesture { glideTo(k) }
                                .accessibilityAddTraits(k == index ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                .frame(height: height)
            }
            .scrollDisabled(true)
            .onChange(of: near) { _, k in withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(Self.keys[k]) } }
        }
        .frame(height: height)
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if horizontal == nil { horizontal = abs(v.translation.width) > abs(v.translation.height) }
                    guard horizontal == true else { return }
                    glide += 1
                    if dragBase == nil { dragBase = at }
                    pos = min(cs.last!, max(cs.first!, dragBase! + v.translation.width))
                }
                .onEnded { _ in
                    defer { horizontal = nil; dragBase = nil }
                    guard horizontal == true else { return }
                    let k = cs.enumerated().min { abs($0.element - pos) < abs($1.element - pos) }!.offset
                    glideTo(k)
                })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.tr("genre"))
    }

    /// the oval's width blended between the two chips it is between; the chip it is nearest to is lit
    private func shape(_ c: CGFloat, _ ws: [CGFloat], _ cs: [CGFloat]) -> (CGFloat, Int) {
        let x = min(cs.last!, max(cs.first!, c))
        var i = 0
        while i < cs.count - 2 && x > cs[i + 1] { i += 1 }
        let f = (x - cs[i]) / (cs[i + 1] - cs[i])
        return (ws[i] + (ws[i + 1] - ws[i]) * f, f > 0.5 ? i + 1 : i)
    }

    private func glideTo(_ k: Int) {
        let cs = centres
        let from = pos < 0 ? cs[Self.keys.firstIndex(of: model.genre) ?? 0] : pos
        let to = cs[k]
        let ms = min(340, 160 + abs(to - from) * 0.6) / 1000
        glide += 1; let my = glide
        let t0 = Date()
        // a frame-by-frame glide (cubic ease-out), so the oval's width blends on the way exactly as under the finger
        func step() {
            guard glide == my else { return }
            let t = min(1, Date().timeIntervalSince(t0) / ms)
            pos = from + (to - from) * (1 - pow(1 - t, 3))
            if t < 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 120) { step() } }
        }
        step()
        if model.genre != Self.keys[k] { model.genre = Self.keys[k] }
    }
}
