import SwiftUI

/// The bottom panel takes the height of what it holds — or, while it is changing (FootAnim), a height on its way from
/// the old one to the new one (0.4 s, fast first and soft at the end), set frame by frame from this very moment.
/// What it holds keeps to its bottom edge: the panel opens upwards, what is at the bottom stays put.
struct FootLayout: Layout {
    var anim: FootAnim?
    var now: Double
    let box: FootBox

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let v = subviews.first else { return .zero }
        let s = v.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        var h = s.height
        if let a = anim {
            let q = max(0, min(1, (now - a.t0 - a.delay) / FootAnim.duration))
            let e = CGFloat(1 - pow(1 - q, 3))
            h = a.h0 + (s.height - a.h0) * e
        }
        box.shown = h
        return CGSize(width: proposal.width ?? s.width, height: max(0, h))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let v = subviews.first else { return }
        v.place(at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

/// The chat's bottom panel: "Tap to continue" (the whole panel is the button), "What do you say?" at a choice, the
/// end's buttons, or the paywall when the free taps have run out.
struct ChatFoot: View {
    @ObservedObject var chat: ChatController

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: chat.footAnim == nil)) { _ in
            FootLayout(anim: chat.footAnim, now: chatNow(), box: chat.footBox) {
                content.frame(maxWidth: .infinity)
            }
        }
        .clipped()
        .overlay(alignment: .bottom) {
            // "Tap to continue" fades out right where it stood while the end's buttons take its place
            if let ghost = chat.contGhost {
                hintText(ghost).opacity(0.9).padding(.bottom, 26).transition(.opacity).allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch chat.foot.mode {
        case .tap, .ask:
            HintLine(text: chat.model.tr(chat.foot.mode == .ask ? "ask" : "tap"), breathing: chat.foot.idle && chat.foot.mode == .tap)
                .opacity(chat.foot.contGone ? 0 : 1)
                .padding(.vertical, 26).padding(.horizontal, ChatMetrics.side)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { chat.footTapped() }
                .accessibilityAddTraits(chat.foot.mode == .tap ? .isButton : [])
        case .end(let end):
            EndButtons(chat: chat, end: end)
                .opacity(chat.foot.wait ? 0 : 1)
                .allowsHitTesting(!chat.foot.wait)
                .padding(.top, 10).padding(.bottom, 12).padding(.horizontal, ChatMetrics.side)
        case .paywall:
            VStack(spacing: 12) {
                Text(chat.model.tr("payT")).font(AppFont.ui(14)).foregroundStyle(Theme.muted)
                Button { chat.payTapped() } label: {
                    Text(chat.model.tr("payB"))
                        .cssText(AppFont.uiFont(16, 800), lineHeight: 20)
                        .foregroundStyle(.white).multilineTextAlignment(.center)
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(Capsule().fill(Theme.red))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10).padding(.bottom, 12).padding(.horizontal, ChatMetrics.side)
        }
    }
}

/// the panel's one line of small capitals
private func hintText(_ text: String) -> some View {
    Text(text.uppercased())
        .font(AppFont.ui(14, 700)).tracking(14 * 0.14)
        .foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center)
}

/// "Tap to continue" / "What do you say?"; left alone for 10 s it starts to breathe (opacity .9 ↔ .4, 2.4 s).
private struct HintLine: View {
    let text: String
    let breathing: Bool
    @State private var since = Date()

    var body: some View {
        if breathing && !reduceMotion() {
            TimelineView(.animation) { tl in
                let q = (tl.date.timeIntervalSince(since) / 2.4).truncatingRemainder(dividingBy: 1)
                hintText(text).opacity(keyframes(q, [(0, 0.9), (0.5, 0.4), (1, 0.9)], ease: .easeInOut))
            }
            .onAppear { since = Date() }
        } else {
            hintText(text).opacity(0.9)
        }
    }
}

/// The end of a part: "Read again" / "Start over" at the very bottom, its word exactly where "Tap to continue" stood;
/// "Next part" and "Back to a choice" above it.
private struct EndButtons: View {
    let chat: ChatController
    let end: ChatReader.End

    var body: some View {
        VStack(spacing: 10) {
            if end.turns > 0 {
                HStack(spacing: 8) {
                    Text(chat.model.tr("turns").uppercased())
                        .font(AppFont.ui(12, 700)).tracking(12 * 0.1).foregroundStyle(Theme.muted)
                        .padding(.trailing, 4)
                    ForEach(0..<end.turns, id: \.self) { k in
                        Button { chat.turnTapped(k) } label: {
                            HStack(spacing: 5) {
                                StrokeIcon(paths: ["M6 3 2.5 6.5 6 10", "M3 6.5h6.5a4 4 0 0 1 0 8H7"], viewBox: CGRect(x: 0, y: 0, width: 16, height: 16), width: 1.6, size: 14)
                                Text(String(k + 1)).font(AppFont.ui(14, 700))
                            }
                            .foregroundStyle(.white)
                            .padding(.leading, 10).padding(.trailing, 13).padding(.vertical, 7)
                        }
                        .buttonStyle(TurnStyle())
                        .accessibilityLabel(chat.model.tr("a11yBackChoice", ["n": String(k + 1)]))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
            }
            if !end.last {
                Button { chat.nextTapped() } label: {
                    Text(chat.model.tr("next")).font(AppFont.ui(16, 600)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
            Button { chat.againTapped() } label: {
                Text(chat.model.tr(end.interactive ? "startOver" : "readAgain").uppercased())
                    .font(AppFont.ui(14, 700)).tracking(14 * 0.14).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.field))
            }
            .buttonStyle(.plain)
        }
    }
}

/// a small outlined pill back to a turning point (a taller target than it looks: 6 pt more above and below)
private struct TurnStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Capsule().fill(Color(hex: 0x7b57c9, configuration.isPressed ? 0.25 : 0)))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
            .padding(.vertical, 6).contentShape(Rectangle()).padding(.vertical, -6)
    }
}
