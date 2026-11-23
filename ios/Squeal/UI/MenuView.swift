import SwiftUI
import UIKit

/// Menu (template.html menu()): plain white words, centred, evenly spaced; nothing else. Five rows; "Language" turns
/// the same five places into the five languages: the words fade out where they stand (0.3 s) and the others fade in in
/// the very same places (0.3 s); nothing moves. The current language carries a tick beside it; the back arrow (top
/// left) or a swipe from left to right brings the menu back the same way. A tap on a language switches the whole app
/// at once.
struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @State private var mode = "menu"           // what the rows show: "menu" or "lang"
    @State private var backOn = false
    @State private var busy = false
    @State private var swapAt = -1e9
    @State private var rowsOpacity = 1.0
    @State private var horiz: Bool? = nil
    @State private var swipeT0 = 0.0
    @GestureState private var swipeLive = false

    static let keys = ["sub", "restore", "lang", "idea", "mail"]

    var body: some View {
        let words = L10n.list(model.lang, "menu")
        ZStack(alignment: .topLeading) {
            VStack(spacing: 44) {
                ForEach(0..<5, id: \.self) { i in
                    let lang = L10n.langNames[i]
                    let title = mode == "menu" ? (i < words.count ? words[i] : "") : lang.1
                    Button { tapped(i, title) } label: {
                        Text(title).font(AppFont.ui(20, 600)).multilineTextAlignment(.center)
                            .foregroundStyle(mode == "menu" && i == 0 ? Theme.red : .white)      // Subscription in the app's red
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16).padding(.vertical, 4)
                            .overlay(alignment: .trailing) {
                                // the tick sits beside the word, the word stays centred
                                if mode == "lang" && lang.0 == model.lang {
                                    StrokeIcon(paths: ["M4.5 12.5l5 5L20 7"], width: 2.6, size: 18).foregroundStyle(Theme.me).offset(x: 18 + 2)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuRowStyle())
                    .accessibilityIdentifier("menu-row-\(i)")
                    .environment(\.locale, Locale(identifier: mode == "lang" ? lang.0 : model.lang))
                    .accessibilityAddTraits(mode == "lang" && lang.0 == model.lang ? .isSelected : [])
                }
            }
            .opacity(rowsOpacity)
            .padding(.vertical, 24).padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { if Taps.shared.allows("m-back") { swap("menu") } } label: {
                StrokeIcon(paths: ["M10 3 5 8l5 5"], viewBox: CGRect(x: 0, y: 0, width: 16, height: 16), width: 2, size: 18)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .padding(8).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14 - 8).padding(.leading, 12 - 8)
            .opacity(backOn ? 1 : 0).animation(.easeInOut(duration: 0.35), value: backOn)
            .allowsHitTesting(backOn)
            .accessibilityLabel(model.tr("back")).accessibilityHidden(!backOn)
            .accessibilityIdentifier("menu-back")
        }
        .contentShape(Rectangle())
        .gesture(swipeBack)
        // a swipe the phone took away changes nothing (and the next one starts afresh)
        .onChange(of: swipeLive) { _, on in if !on { DispatchQueue.main.async { horiz = nil } } }
        .onAppear {
            let a = LaunchArgs(ProcessInfo.processInfo.arguments)        // CI screenshots
            if a.value("-menu") == "lang" { mode = "lang"; backOn = true }
            if let i = a.value("-menutap").flatMap({ Int($0) }) { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tapped(i, L10n.list(model.lang, "menu")[i]) } }
        }
    }

    /// the languages → the menu: a swipe from left to right anywhere on the page. The words do not follow the finger;
    /// the swipe (more than 50 pt, or a short quick one) just starts the same change.
    private var swipeBack: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($swipeLive) { _, s, _ in s = true }
            .onChanged { v in
                guard mode == "lang", !busy else { return }
                if horiz == nil { horiz = abs(v.translation.width) > abs(v.translation.height) && v.translation.width > 0; swipeT0 = Taps.now() }
                if horiz == true && v.translation.width > 50 { horiz = false; swap("menu") }
            }
            .onEnded { v in
                defer { horiz = nil }
                guard horiz == true, mode == "lang" else { return }
                let dx = v.translation.width, ms = max(1, (Taps.now() - swipeT0) * 1000)
                if dx > 50 || (dx > 20 && dx / ms > 0.3) { swap("menu") }
            }
    }

    private func swap(_ to: String) {
        if busy || mode == to { return }
        busy = true; swapAt = Taps.now()
        backOn = to == "lang"
        if reduceMotion() { mode = to; busy = false; return }
        withAnimation(.timingCurve(0.42, 0, 1, 1, duration: 0.3)) { rowsOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            mode = to
            withAnimation(.timingCurve(0, 0, 0.58, 1, duration: 0.3)) { rowsOpacity = 1 }
            busy = false
        }
    }

    private func tapped(_ i: Int, _ title: String) {
        guard Taps.shared.allows("m-row\(i)") else { return }
        // the rows that just faded in take no tap yet: a double tap never picks a language or the subscription
        if busy || Taps.now() - swapAt < 0.75 { return }
        if mode == "lang" {                                   // a language: the app speaks it from now on
            let code = L10n.langNames[i].0
            if code == model.lang { return }
            model.setLang(code)
            Haptics.tap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { swap("menu") }   // the tick moves, then the list folds back into the menu (in the new language)
            return
        }
        switch Self.keys[i] {
        case "lang": swap("lang")
        case "sub": model.toggleSubscription()
        default: model.showToast(model.tr("inApp", ["x": title]))
        }
    }
}

/// .m-row:active { opacity: .5 } (0.15 s)
private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.5 : 1).animation(.linear(duration: 0.15), value: configuration.isPressed)
    }
}
