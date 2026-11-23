import SwiftUI
import UIKit

/// A button that acts on lift inside it and keeps its touch (a swipe that starts on it never moves the page).
struct PressArea<Content: View>: View {
    var onDown: () -> Void = {}
    var onUp: (_ inside: Bool) -> Void
    @ViewBuilder var content: (_ pressed: Bool) -> Content
    @State private var pressed = false
    @GestureState private var live = false
    var body: some View {
        GeometryReader { g in
            content(pressed)
                .frame(width: g.size.width, height: g.size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($live) { _, s, _ in s = true }
                    .onChanged { _ in if !pressed { pressed = true; onDown() } }
                    .onEnded { v in
                        pressed = false
                        let inside = CGRect(origin: .zero, size: g.size).insetBy(dx: -20, dy: -20).contains(v.location)
                        onUp(inside)
                    })
                // a touch the phone took away never lifts: the button lets go and does nothing (BUGS #149)
                .onChange(of: live) { _, on in if !on { DispatchQueue.main.async { if pressed { pressed = false } } } }
        }
    }
}

/// The story page (template.html sheetHTML/wire, "still" layout): one iPhone screen, the photo takes whatever height
/// is left, the description gives up lines from its end only if it must. Close: ✕ (on touch), swipe right, swipe down;
/// swipe left or up opens the story. (IDEAS.md «Превью истории»)
struct PreviewView: View {
    @EnvironmentObject var model: AppModel
    let story: Story

    @State private var sel: Int = 0
    @State private var waterAt = Date()
    @State private var still = false                 // redrawn after a reset: the water just stands
    @State private var wake: [Int: Date] = [:]       // a part picked again: its waves play once more
    @State private var drain: [Int: (Date, Double)] = [:]
    @State private var note: String? = nil
    @State private var noteShown = false
    @State private var noteToken = 0
    @State private var ring: Double = 0              // the hold ring, 0...1
    @State private var ringOpacity: Double = 0
    @State private var resetPressed = false
    @State private var likePressed = false
    @State private var bounce: [String: Bool] = [:]
    @State private var likeMotion: HeartMotion = .still
    @State private var likeLit: Bool = false
    @State private var holdToken = 0
    @State private var holdState = 0                 // 0 idle, 1 down, 2 ring filling, 3 all reset
    @State private var drag: CGSize = .zero
    @State private var dragAxis: String? = nil
    @State private var leaving: CGSize? = nil
    @State private var tick = 0
    // SwiftUI ends a drag with `onEnded` only when the finger lifts; a touch the phone takes away (a call, the home
    // bar, a second finger's gesture) just stops. These say "a touch is on it": when one drops with its gesture
    // still open, the gesture is called off and everything goes back (BUGS #118, #149).
    @GestureState private var swipeLive = false
    @GestureState private var frameLive = false
    @GestureState private var resetLive = false
    @GestureState private var likeLive = false
    @State private var likeBack = 1.0                // the plain heart coming back after an unlike
    @State private var resetOff = false              // the finger has slid off ↺ during this touch

    private var multi: Bool { story.parts.count > 1 }

    /// the phone's safe area (the page itself runs under the status bar and the home indicator)
    static var windowSafeArea: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets) ?? .zero
    }

    var body: some View {
        GeometryReader { g in
            let safe = Self.windowSafeArea
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    cover
                        .frame(maxWidth: .infinity, minHeight: 150 + safe.top, maxHeight: .infinity)
                        .layoutPriority(-1)
                    bodyColumn(bottom: max(16, safe.bottom))
                }
                chrome(width: g.size.width).padding(.top, safe.top)
            }
            .frame(width: g.size.width, height: g.size.height)
            .background(Theme.bg)
            .offset(leaving ?? drag)
            .gesture(swipe(g.size))
            .onChange(of: swipeLive) { _, on in
                if !on { DispatchQueue.main.async {
                    guard dragAxis != nil else { return }      // (lifted: onEnded has dealt with it)
                    dragAxis = nil
                    if leaving == nil { withAnimation(reduceMotion() ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { drag = .zero } }
                } }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { if TouchProbe.on { TouchProbe() } }      // (UI tests: a modal page hides the one outside it)
        .accessibilityAddTraits(.isModal)                     // VoiceOver stays on the story page, not on the tab under it (BUGS #148)
        .onAppear(perform: setup)
    }

    // MARK: cover and caption

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            CoverImage(file: story.cover)
            LinearGradient(stops: [.init(color: Theme.bg, location: 0.04), .init(color: Theme.bg.opacity(0), location: 0.70)], startPoint: .bottom, endPoint: .top)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Text(model.genreName(story.genre).uppercased())
                    Circle().fill(Theme.muted).opacity(0.7).frame(width: 4, height: 4).padding(.horizontal, 9).offset(y: -0.5)
                    Text(model.minutes(story).uppercased())
                    if story.interactive {
                        Circle().fill(Theme.muted).opacity(0.7).frame(width: 4, height: 4).padding(.horizontal, 9).offset(y: -0.5)
                        Icons.pad(17).offset(y: -1).accessibilityLabel(model.tr("interactive"))
                    }
                }
                .font(AppFont.ui(13)).tracking(13 * 0.05).foregroundStyle(Theme.muted)
                Text(story.title).font(AppFont.ui(32, 700)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("pv-title")
            }
            .padding(18)
        }
        .clipped()
    }

    private func bodyColumn(bottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.description)
                .font(AppFont.ui(15)).lineSpacing(15 * 0.45 - (AppFont.uiFont(15).lineHeight - 15))
                .foregroundStyle(Color(hex: 0xdcd9ea))
                .lineLimit(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-0.5)
            if !story.author.isEmpty {
                Text(model.tr("by", ["a": story.author])).font(AppFont.ui(14)).foregroundStyle(Theme.muted)
            }
            if multi { parts }
            PressArea(onUp: { inside in if inside && Taps.shared.allows("read") { read(from: .trailing) } }) { pressed in
                Text(model.tr("read")).font(AppFont.ui(17, 700)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(pressed ? 0.08 : 0)))
            }
            .frame(height: 14 * 2 + ceil(AppFont.uiFont(17, 700).lineHeight))
            .accessibilityElement().accessibilityLabel(model.tr("read")).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("pv-read")
            .accessibilityAction { read(from: .trailing) }
        }
        .padding(.top, 4).padding(.horizontal, 18).padding(.bottom, bottom)
    }

    // MARK: parts (water, one draggable frame)

    @State private var framePos: CGFloat = -1
    @State private var frameDragBase: CGFloat? = nil
    @State private var frameGlide = 0

    private var parts: some View {
        let p = model.prog(story), n = story.parts.count
        let _ = tick
        return GeometryReader { g in
            let w = (g.size.width - 8 * CGFloat(n - 1)) / CGFloat(n), stepX = w + 8
            let centre = { (k: Int) in CGFloat(k) * stepX + w / 2 }
            let at = framePos < 0 ? centre(sel) : framePos
            ZStack(alignment: .topLeading) {
                HStack(spacing: 8) {
                    ForEach(0..<n, id: \.self) { k in
                        let f = Reading.partPct(story, p, k)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field)
                            if f > 0 || drain[k] != nil {
                                WaterFill(fraction: f, motion: waterMotion(k, done: f >= 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            Text(model.tr("part", ["n": "\(k + 1)"])).font(AppFont.ui(15, 700)).foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 8)
                        }
                        .frame(width: w, height: g.size.height)
                        .accessibilityElement().accessibilityLabel(model.tr("part", ["n": "\(k + 1)"]))
                        .accessibilityAddTraits(k == sel ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("pv-part-\(k + 1)")
                        .accessibilityValue(String(Int((f * 100).rounded())) + " %")
                        .accessibilityAction { select(k, wakeUp: true) }
                    }
                }
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5)
                    .frame(width: w, height: g.size.height)
                    .offset(x: at - w / 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onChange(of: frameLive) { _, on in
                if !on { DispatchQueue.main.async {
                    guard frameDragBase != nil else { return }
                    frameDragBase = nil                          // taken by the phone: the frame settles on the nearest part
                    if framePos >= 0 { glide(to: (0..<n).min { abs(centre($0) - framePos) < abs(centre($1) - framePos) }!, from: framePos, centre: centre) }
                } }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .updating($frameLive) { _, s, _ in s = true }
                .onChanged { v in
                    guard Taps.shared.allows("part\(max(0, min(n - 1, Int(v.startLocation.x / stepX))))") else { return }
                    if frameDragBase == nil {
                        let k = max(0, min(n - 1, Int(v.startLocation.x / stepX)))
                        frameDragBase = centre(k)
                        if k != sel { glide(to: k, from: at, centre: centre) }      // another part: the frame goes there at once
                    }
                    if abs(v.translation.width) >= 5 {
                        frameGlide += 1
                        framePos = min(centre(n - 1), max(centre(0), frameDragBase! + v.translation.width))
                    }
                }
                .onEnded { v in
                    defer { frameDragBase = nil }
                    guard frameDragBase != nil else { return }
                    if abs(v.translation.width) >= 5 {
                        let k = (0..<n).min { abs(centre($0) - framePos) < abs(centre($1) - framePos) }!
                        glide(to: k, from: framePos, centre: centre)
                    }
                })
        }
        .frame(height: 13 * 2 + ceil(AppFont.uiFont(15, 700).lineHeight))
    }

    private func waterMotion(_ k: Int, done: Bool) -> WaterMotion {
        var m = WaterMotion()
        if let d = drain[k] { m.drainFrom = d.0; m.drainLevel = d.1; return m }
        if !still && !reduceMotion() { m.riseFrom = waterAt; m.delay = Double(k) * 0.09; if !done { m.wavesFrom = waterAt } }
        if let w = wake[k], !done { m.wavesFrom = w }
        return m
    }

    private func glide(to k: Int, from: CGFloat, centre: @escaping (Int) -> CGFloat) {
        let to = centre(k)
        let ms = reduceMotion() ? 0.0001 : min(320, 150 + abs(to - from) * 0.8) / 1000
        frameGlide += 1; let my = frameGlide
        let t0 = Date()
        func step() {
            guard frameGlide == my else { return }
            let t = min(1, Date().timeIntervalSince(t0) / ms)
            framePos = from + (to - from) * (1 - pow(1 - t, 3))
            if t < 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 120) { step() } }
        }
        step()
        select(k, wakeUp: true)
    }

    /// chosen by hand: a part whose waves have calmed down plays them again; still moving — nothing changes
    private func select(_ k: Int, wakeUp: Bool) {
        if wakeUp && !reduceMotion() {
            let started = wake[k] ?? (still ? .distantPast : waterAt)
            if Date().timeIntervalSince(started) > 3.3 { wake[k] = Date(); refreshLater(3.5) }
        }
        sel = k
    }

    // MARK: the round buttons

    private func chrome(width: CGFloat) -> some View {
        let liked = model.isFav(story.id)
        return ZStack(alignment: .topLeading) {
            // ✕ closes the moment it is touched
            Icons.close(21).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(Circle().fill(Theme.chrome))
                .frame(width: 56, height: 56).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if Taps.shared.allows("pv-back") { Taps.shared.closeTap(); close() } })
                .offset(x: 12 - 8, y: 10 - 8)
                .accessibilityElement().accessibilityLabel(model.tr("close")).accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("pv-close")
                .accessibilityAction { close() }
            if let note {
                noteView(note, width: width)
            }
            resetButton
                .offset(x: width - 12 - 52 - 40 - 8, y: 10 - 8)
            likeButton(liked)
                .offset(x: width - 12 - 40 - 8, y: 10 - 8)
        }
        .frame(width: width, height: 64, alignment: .topLeading)
    }

    private var resetButton: some View {
        ZStack {
            Circle().fill(Theme.chrome)
            Icons.again(25).foregroundStyle(Theme.muted)
            if multi {
                Circle().trim(from: 0, to: ring).stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(1).opacity(ringOpacity)
            }
        }
        .frame(width: 40, height: 40)
        .scaleEffect(resetPressed ? 0.88 : (bounce["reset"] == true ? 1.08 : 1))
        .frame(width: 56, height: 56).contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .updating($resetLive) { _, s, _ in s = true }
            .onChanged { v in
                // the finger slid off the button: the press is over, nothing is reset (the web's pointerleave)
                if !CGRect(x: 0, y: 0, width: 56, height: 56).insetBy(dx: -4, dy: -4).contains(v.location) {
                    if !resetOff { resetOff = true; resetCalledOff() }
                    return
                }
                if holdState == 0, !resetOff, Taps.shared.allows("pv-reset") { resetDown() }
            }
            .onEnded { _ in
                if resetOff { resetOff = false } else { resetUp() }
            })
        .onChange(of: resetLive) { _, on in if !on { DispatchQueue.main.async { resetOff = false; resetCalledOff() } } }
        .accessibilityElement().accessibilityLabel(model.tr(multi ? "resetMulti" : "reset")).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pv-reset")
        .accessibilityAction { resetOne() }
    }

    private func likeButton(_ liked: Bool) -> some View {
        HeartBadge(box: 40, heart: 27, circle: likeLit ? Theme.accent : Theme.chrome, ink: likeLit ? .white : Theme.muted,
                   motion: likeMotion, fadeHalves: true, heartIn: likeBack)
            .animation(.easeInOut(duration: 0.2), value: likeLit)
            .scaleEffect(likePressed ? 0.88 : (bounce["like"] == true ? 1.08 : 1))
            .frame(width: 56, height: 56).contentShape(Rectangle())
            .onChange(of: likeLive) { _, on in if !on { DispatchQueue.main.async { if likePressed { release("like") { likePressed = false } } } } }
            .gesture(DragGesture(minimumDistance: 0)
                .updating($likeLive) { _, s, _ in s = true }
                .onChanged { _ in if !likePressed { withAnimation(.easeOut(duration: 0.12)) { likePressed = true } } }
                .onEnded { v in
                    release("like") { likePressed = false }
                    if CGRect(x: -20, y: -20, width: 96, height: 96).contains(v.location), Taps.shared.allows("pv-like") { toggleLike() }
                })
            .accessibilityElement().accessibilityLabel(model.tr("favourite"))
            .accessibilityAddTraits(liked ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("pv-like")
            .accessibilityAction { toggleLike() }
    }

    /// pressed (.88) → springs back past 1 (1.08) → 1, 0.32 s
    private func release(_ key: String, _ unpress: @escaping () -> Void) {
        if reduceMotion() { unpress(); return }               // no spring back past its size
        withAnimation(.easeOut(duration: 0.176)) { unpress(); bounce[key] = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.176) { withAnimation(.easeOut(duration: 0.144)) { bounce[key] = false } }
    }

    private func noteView(_ text: String, width: CGFloat) -> some View {
        let maxW = width - 2 * 12 - 104 - 48
        let font = AppFont.uiFont(15)
        let oneLine = (text as NSString).size(withAttributes: [.font: font]).width + 32 <= maxW
        return HStack { Spacer(minLength: 0)
            Text(text)
                .font(AppFont.ui(oneLine ? 15 : 14)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.trailing).lineLimit(oneLine ? 1 : 2)
                .padding(.horizontal, 16).padding(.vertical, oneLine ? 0 : 4)
                .frame(minHeight: 40)
                .background(Capsule().fill(Theme.chrome))
                .frame(maxWidth: maxW, alignment: .trailing)
                .opacity(noteShown ? 1 : 0)
                .scaleEffect(noteShown ? 1 : 0.96, anchor: .trailing)
                .offset(x: noteShown ? 0 : 8)
        }
        .frame(width: width - 12 - 104)
        .offset(y: 10)
        .allowsHitTesting(false)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: actions

    private func setup() {
        let p = model.prog(story)
        sel = Reading.nextPart(story, p)          // all read: the part last read (2026-11-11)
        likeLit = model.isFav(story.id)
        waterAt = Date()
        refreshLater(3.5)
    }

    private func refreshLater(_ s: Double) { DispatchQueue.main.asyncAfter(deadline: .now() + s) { tick += 1 } }

    private func close() {
        guard model.previewID == story.id else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { model.previewID = nil }
    }

    private func read(from edge: Edge) {
        model.openStory(story.id, part: multi ? sel : nil, from: edge)
    }

    private func toggleLike() {
        let wasOn = model.isFav(story.id)
        model.toggleFav(story.id, want: !wasOn)
        holdToken += 1; let my = holdToken
        if reduceMotion() { likeMotion = .still; likeLit = !wasOn; return }     // the heart is simply on or off
        if !wasOn {
            // one to one the card's like: the purple badge pops up from nothing, a pen draws the white heart, it fills
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { likeLit = true }
            likeMotion = .draw(Date(), 390)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { if holdToken == my { likeMotion = .still } }
        } else {
            // it cracks while still lit; then the circle dims and the plain heart comes back
            likeMotion = .crack(Date(), 320, fadeBadge: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                guard holdToken == my else { return }
                likeMotion = .still
                likeLit = model.isFav(story.id)
                // the plain heart comes back: from 70 % of its size, fading in (0.18 s)
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { likeBack = 0 }
                DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.18)) { likeBack = 1 } }
            }
        }
    }

    // start over: a tap clears the selected part; a hold (the ring closes) clears every part
    private func resetDown() {
        holdState = 1
        withAnimation(.easeOut(duration: 0.12)) { resetPressed = true }
        guard multi else { return }
        holdToken += 1; let my = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard holdToken == my, holdState == 1 else { return }
            holdState = 2
            withAnimation(.linear(duration: 0.1)) { ringOpacity = 1 }
            withAnimation(.linear(duration: 0.3)) { ring = 1 }
            Haptics.ramp(0.3) { holdToken == my && holdState == 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard holdToken == my, holdState == 2 else { return }
                holdState = 3
                let before = levels()
                model.resetAll(story)
                redraw(model.tr("allOver"), drained: Array(0..<story.parts.count), before: before)
                // the closed ring stays a second, then dissolves
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.easeInOut(duration: 0.45)) { ringOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if ringOpacity == 0 { ring = 0 } }
                }
            }
        }
    }

    private func resetUp() {
        let state = holdState
        holdState = 0
        release("reset") { resetPressed = false }
        switch state {
        case 1: holdToken += 1; resetOne()                       // a tap
        case 2:                                                   // let go before the ring closed: nothing; the ring winds back
            holdToken += 1
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)) { ring = 0 }
            withAnimation(.linear(duration: 0.12).delay(0.26)) { ringOpacity = 0 }
        default: break
        }
    }

    /// the touch on ↺ was taken by the phone: nothing is reset; a ring on its way winds back
    private func resetCalledOff() {
        guard holdState == 1 || holdState == 2 else { if holdState == 3 { holdState = 0; release("reset") { resetPressed = false } }; return }
        let state = holdState
        holdState = 0; holdToken += 1
        release("reset") { resetPressed = false }
        if state == 2 {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)) { ring = 0 }
            withAnimation(.linear(duration: 0.12).delay(0.26)) { ringOpacity = 0 }
        }
    }

    private func resetOne() {
        let before = levels()
        var p = model.prog(story)
        let k = multi ? sel : p.ep
        p.pos[k] = 0
        if story.parts[k].nodes != nil { p.path = nil }
        model.setProg(story, p)
        redraw(multi ? model.tr("partOver", ["n": "\(k + 1)"]) : model.tr("storyOver"), drained: [k], before: before)
    }

    /// the water of the parts being reset drains (1 s), then the page shows the new state with a note beside the buttons
    private func redraw(_ text: String, drained: [Int], before: [Int: Double]) {
        var any = false
        if !reduceMotion() {                                  // (Reduce Motion: the water is simply gone)
            for k in drained where (before[k] ?? 0) > 0 { drain[k] = (Date(), before[k]!); any = true }
        }
        let wait = max(0.38, any ? 1.0 : 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            drain = [:]; still = true; wake = [:]
            tick += 1
            noteToken += 1; let my = noteToken
            note = text; noteShown = false
            let quick = reduceMotion()                        // the note is there and gone, it does not slide
            withAnimation(quick ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { noteShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                guard noteToken == my else { return }
                withAnimation(quick ? nil : .easeIn(duration: 0.25)) { noteShown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0 : 0.3)) { if noteToken == my { note = nil } }
            }
        }
    }

    /// each part's level as it is on screen now (taken before a reset writes the new progress)
    private func levels() -> [Int: Double] {
        let p = model.prog(story)
        return Dictionary(uniqueKeysWithValues: (0..<story.parts.count).map { ($0, Reading.partPct(story, p, $0)) })
    }

    // MARK: swipes: right / down close (the page follows the finger), left / up open the story

    private func swipe(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($swipeLive) { _, s, _ in s = true }
            .onChanged { v in
                let dx = v.translation.width, dy = v.translation.height
                if dragAxis == nil {
                    if abs(dx) > abs(dy) && dx > 0 { dragAxis = "x" }
                    else if abs(dy) >= abs(dx) && dy > 0 { dragAxis = "y" }
                    else if abs(dx) > abs(dy) && dx < 0 { dragAxis = "open"; read(from: .trailing); return }
                    else { dragAxis = "open"; read(from: .bottom); return }
                }
                if dragAxis == "x" { drag = CGSize(width: max(0, dx), height: 0) }
                if dragAxis == "y" { drag = CGSize(width: 0, height: max(0, dy)) }
            }
            .onEnded { v in
                defer { dragAxis = nil }
                guard dragAxis == "x" || dragAxis == "y" else { return }
                let x = dragAxis == "x"
                let d = x ? drag.width : drag.height, full = x ? size.width : size.height
                let speed = x ? (v.predictedEndTranslation.width - v.translation.width) : (v.predictedEndTranslation.height - v.translation.height)
                let go = d > full * 0.33 || speed > 120
                let quick = reduceMotion()
                withAnimation(quick ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) {
                    if go { leaving = x ? CGSize(width: full, height: 0) : CGSize(width: 0, height: full) } else { drag = .zero }
                }
                if go { DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0 : 0.3)) { close() } }
            }
    }
}
