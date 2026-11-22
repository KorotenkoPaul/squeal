import SwiftUI
import UIKit

/// Search (template.html search()): the field stays put at the top with the fear row under it; only the list of
/// stories scrolls and springs. Typing hides the fear row and lists the matches; Cancel brings everything back to
/// where it was.
struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var active = false                  // the field is in use: Cancel stands beside it
    @State private var dialGone = false                // faded away (0.25 s) …
    @State private var dialOut = false                 // … and then out of the page
    @State private var outToken = 0
    @State private var backY: CGFloat? = nil           // where the list was scrolled when the field was tapped
    @State private var barFrame = CGRect.zero
    @State private var list = ListScroll()
    @State private var keyboard: CGFloat = 0           // how much of the list the keyboard covers

    var body: some View {
        let found = model.query.isEmpty ? [] : Search.stories(model.stories, english: model.english, model.query)
        let level = Fear.stories(model.stories, level: model.fearLevel)
        VStack(spacing: 0) {
            bar
            if !dialOut {
                FearRow()
                    .padding(.top, 8)
                    .opacity(dialGone ? 0 : 1).offset(y: dialGone ? -8 : 0)
                    .allowsHitTesting(!dialGone)
            }
            results(found: found, level: level)
                .padding(.top, 14)
        }
        .onAppear(perform: appear)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { n in
            guard let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screen = UIScreen.main.bounds.height
            keyboard = f.minY >= screen ? 0 : max(0, screen - f.minY - 58 - PreviewView.windowSafeArea.bottom)
        }
        .onDisappear { Taps.shared.onDown["search"] = nil }
        .onChange(of: focused) { _, f in f ? focus() : blur() }
        .onChange(of: text) { _, t in model.query = t.trimmingCharacters(in: .whitespacesAndNewlines) }   // spaces alone are no query
    }

    // MARK: the field and Cancel

    private var bar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Icons.search(18).foregroundStyle(Theme.muted)
                TextField("", text: $text, prompt: Text(model.tr("search")).foregroundStyle(Theme.muted))
                    .font(AppFont.ui(16)).foregroundStyle(.white).tint(Theme.line)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .frame(height: 24)
                    .accessibilityLabel(model.tr("search"))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5).padding(-1.5).opacity(focused ? 1 : 0)
                .animation(.linear(duration: 0.2), value: focused))
            .overlay {
                // not in use: the tap that brings the keyboard is a tap like any other (a double tap on Cancel never brings it back)
                if !focused { Color.clear.contentShape(Rectangle()).tap("q") { focused = true } }
            }
            Text(model.tr("cancel")).font(AppFont.ui(16, 600)).foregroundStyle(Color(hex: 0xb9a3ff))
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 6)
                .frame(maxWidth: active ? 102 : 12, alignment: .leading).clipped()
                .opacity(active ? 1 : 0)
                .padding(.leading, active ? 12 : 0)
                .contentShape(Rectangle())
                .tap("s-cancel") { cancel() }
                .allowsHitTesting(active)
                .accessibilityAddTraits(.isButton).accessibilityHidden(!active)
        }
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.28), value: active)
        .padding(.top, 18).padding(.bottom, 6).padding(.horizontal, 18)
        .background(Theme.bg)
        .background(GeometryReader { g in Color.clear.onAppear { barFrame = g.frame(in: .global) }.onChange(of: g.frame(in: .global)) { _, r in barFrame = r } })
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Theme.bg, Theme.bg.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 14).offset(y: 14).allowsHitTesting(false)
        }
        .zIndex(3)
    }

    // MARK: the list

    @ViewBuilder private func results(found: [Story], level: [Story]) -> some View {
        let searching = !model.query.isEmpty
        let rows: [Story] = searching ? found : (active ? [] : level)
        let hint: String? = searching ? (found.isEmpty ? model.tr("nothing") : nil) : (active ? nil : (level.isEmpty ? model.tr("noScary") : nil))
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { s in
                    HStack(spacing: 14) {
                        Thumb(story: s)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(AppFont.ui(18, 600)).foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            MetaLine(story: s)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .contentShape(Rectangle())
                    .tap("item:" + s.id) {
                        focused = false
                        Taps.shared.openTap()
                        model.previewID = s.id
                    }
                    .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                }
                if let hint { HintText(text: hint) }
            }
            .padding(.horizontal, 18).padding(.bottom, 24 + keyboard)     // the last match can be scrolled up from under the keyboard
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScrollFinder { sv in sv.alwaysBounceVertical = true; list.sv = sv })
        }
        .scrollDisabled(rows.isEmpty)                      // only stories spring; a lone hint line stands still
        .frame(maxHeight: .infinity)
    }

    // MARK: what the field does

    private func appear() {
        text = model.query
        active = !model.query.isEmpty
        dialGone = active; dialOut = active
        // tap anywhere but the field: the keyboard goes away (and, with nothing typed, the fear row comes back). With
        // nothing typed that tap only puts the keyboard away — the list comes back under the finger, and the same tap
        // must not open the story that is now there; with matches showing, a tap on one opens it straight away.
        Taps.shared.onDown["search"] = { p in
            guard focused, model.tab == "search", model.previewID == nil, model.chat == nil, !barFrame.contains(p) else { return }
            if model.query.isEmpty { Taps.shared.eatThisTouch(); Taps.shared.pin() }
            focused = false
        }
    }

    /// tapping the field clears the screen at once: no fade, so the fear row never flashes back into view
    private func focus() {
        if backY == nil { backY = list.sv?.contentOffset.y }
        outToken += 1
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { active = true; dialGone = true; dialOut = true }
        list.sv?.contentOffset.y = 0
    }

    private func blur() {
        guard model.query.isEmpty else { return }
        active = false
        showDial()
        backToPlace()
    }

    private func cancel() {
        Taps.shared.openTap()                              // the field grows under the finger: a second tap there does not bring the keyboard back
        text = ""; model.query = ""
        active = false
        if focused { focused = false } else { showDial(); backToPlace() }
    }

    private func showDial() {
        outToken += 1
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { dialOut = false; dialGone = true }
        DispatchQueue.main.async { withAnimation(.easeInOut(duration: 0.25)) { dialGone = false } }
    }

    /// Cancel, or a tap on an empty spot, brings you back to the place you had scrolled to (not to the top)
    private func backToPlace() {
        guard let y = backY else { return }
        backY = nil
        DispatchQueue.main.async {
            list.sv?.contentOffset.y = y
            DispatchQueue.main.async { list.sv?.contentOffset.y = y }
        }
    }

    final class ListScroll { weak var sv: UIScrollView? }
}

/// The fear filter: one row of the five level names. Swipe it left or right; the name that stops in the middle is the
/// filter, a little bigger and in its own colour, with one neighbour faintly on each side. Tap a neighbour: it slides
/// to the middle (a quick double tap moves one step, not two).
struct FearRow: View {
    @EnvironmentObject var model: AppModel
    @State private var scroll: CGFloat = -1
    @State private var centred: Int? = nil
    @State private var settleToken = 0
    @State private var nameT = 0.0

    var body: some View {
        let names = L10n.list(model.lang, "fear")
        GeometryReader { g in
            let W = g.size.width, side = max(0, W / 2 - 66)
            let at = scroll < 0 ? CGFloat(model.fearLevel - 1) * 132 : scroll
            let look = Fear.paint(scroll: Double(at))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        Text(i < names.count ? names[i] : "")
                            .font(AppFont.ui(24, 800)).tracking(0.24).lineLimit(1).fixedSize()
                            .foregroundStyle(Color(hex: Fear.colours[i]))
                            .scaleEffect(look.scale[i]).opacity(look.opacity[i])
                            .frame(width: 132, height: 50)
                            .contentShape(Rectangle())
                            .tap("lvl\(i + 1)") {
                                let t = Taps.now()
                                if t - nameT < 0.35 { return }                 // a second tap on a name within 350 ms: ignored
                                nameT = t
                                withAnimation(.easeInOut(duration: 0.3)) { centred = i }
                            }
                            .id(i)
                    }
                }
                .scrollTargetLayout()
                .background(GeometryReader { c in
                    Color.clear.preference(key: FearScroll.self, value: -c.frame(in: .named("fear")).minX)
                })
            }
            .coordinateSpace(name: "fear")
            .contentMargins(.horizontal, side, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred, anchor: .center)
            .onPreferenceChange(FearScroll.self) { x in
                // -side: the first name in the middle
                let s = x + side
                if abs(s - scroll) > 0.01 { scroll = s; moved() }
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.24), .init(color: .black, location: 0.76), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: 50)
        .onAppear { centred = model.fearLevel - 1 }
        .accessibilityElement()
        .accessibilityLabel(names.indices.contains(model.fearLevel - 1) ? names[model.fearLevel - 1] : "")
        .accessibilityAdjustableAction { d in
            let k = max(1, min(5, model.fearLevel + (d == .increment ? 1 : -1)))
            model.fearLevel = k; centred = k - 1
        }
    }

    /// when the row comes to rest (140 ms without moving), the name in the middle becomes the filter
    private func moved() {
        settleToken += 1; let my = settleToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            guard my == settleToken else { return }
            let near = Fear.paint(scroll: Double(scroll)).near
            if near != model.fearLevel { model.fearLevel = near }
        }
    }
}

private struct FearScroll: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
