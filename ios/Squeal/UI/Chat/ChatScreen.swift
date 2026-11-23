import SwiftUI
import UIKit

/// The chat of one story, over everything else: it slides in from the right (or from below after a swipe up on the
/// story page), and slides away to the right — by the back arrow or a swipe from the very left edge — dropping the
/// reader on the screen the story was opened from.
struct ChatScreen: View {
    @StateObject private var chat: ChatController
    private let asked: Int?

    init(model: AppModel, story: Story, route: ChatRoute) {
        _chat = StateObject(wrappedValue: ChatController(model: model, story: story, route: route))
        asked = route.asked
    }

    var body: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                ChatHead(chat: chat, narrow: g.size.width <= 340)
                ZStack(alignment: .top) {
                    ForEach(chat.logs) { log in
                        LogView(log: log, chat: chat)
                            .frame(height: log.ghost ? log.ghostHeight : nil, alignment: .top)
                            .zIndex(log.ghost ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                ChatFoot(chat: chat)
            }
            .background(alignment: .top) { WallpaperView(keeper: chat.wall).ignoresSafeArea(edges: .bottom) }
            .background(Theme.bg.shadow(color: .black.opacity(0.35), radius: 20, x: -20, y: 0).ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if let text = chat.toast {
                    Text(text)
                        .font(AppFont.ui(14)).foregroundStyle(.white).multilineTextAlignment(.center)
                        .accessibilityIdentifier("toast")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.field))
                        .padding(.horizontal, 16).padding(.bottom, 84)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                        .allowsHitTesting(false)
                }
            }
            .background(EdgeSwipe(chat: chat, headHeight: g.safeAreaInsets.top + 60))
        }
        .offset(chat.offset)
        .overlay(alignment: .topLeading) { if TouchProbe.on { TouchProbe().environmentObject(chat.model) } }
        .accessibilityAddTraits(.isModal)
        .onAppear { chat.start(part: asked) }
    }
}

/// The chat's top bar: back, the other side's initial and name with "online" / "typing…" under it, and (a story of
/// several parts) the part numbers with the disc on the one being read.
struct ChatHead: View {
    @ObservedObject var chat: ChatController
    let narrow: Bool

    var body: some View {
        HStack(spacing: narrow ? 7 : 12) {
            Button { if Taps.shared.allows("chat-back") { Taps.shared.closeTap(); chat.close() } } label: {
                StrokeIcon(paths: ["M10 3 5 8l5 5"], viewBox: CGRect(x: 0, y: 0, width: 16, height: 16), width: 2, size: 16)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 14).contentShape(Rectangle())     // a 44 pt target round the small arrow
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -12).padding(.vertical, -14)
            .accessibilityLabel(chat.model.tr("back"))
            .accessibilityIdentifier("chat-back")
            Circle().fill(Theme.accent).frame(width: 38, height: 38)
                .overlay(Text(String(chat.part.left.prefix(1))).font(AppFont.ui(16, 700)).foregroundStyle(.white))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(chat.part.left).font(AppFont.ui(16, 600)).foregroundStyle(.white).lineLimit(1).truncationMode(.tail)
                Text(chat.statusText()).font(AppFont.ui(12)).foregroundStyle(Theme.muted).lineLimit(1)
                    .accessibilityIdentifier("chat-status")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if chat.story.parts.count > 1 { PartDisc(chat: chat) }
        }
        .padding(.horizontal, narrow ? 12 : 18).padding(.vertical, 12)
        .background(Theme.tabbar.ignoresSafeArea(edges: .top))
    }
}

/// Part switch: the parts' numbers sit right in the header; a lit disc marks the one being read. Tap a number, or drag
/// the disc along the numbers: it follows the finger and, let go, settles on the nearest part, which then opens.
/// It is one and the same view across a part switch, so no tap is lost and the disc carries on from where it is.
struct PartDisc: View {
    @ObservedObject var chat: ChatController
    @State private var base: CGFloat = 0
    @State private var moved = false
    @GestureState private var live = false

    private let step = ChatController.segStep

    var body: some View {
        let n = chat.story.parts.count
        ZStack(alignment: .topLeading) {
            Circle().fill(Theme.accent).frame(width: 40, height: 40).offset(x: chat.discX)
            HStack(spacing: 4) {
                ForEach(0..<n, id: \.self) { k in
                    Text(String(k + 1))
                        .font(AppFont.ui(15, 800)).monospacedDigit()
                        .foregroundStyle(k == chat.discEp ? Color.white : Theme.muted)
                        .animation(.easeInOut(duration: 0.25), value: chat.discEp)
                        .frame(width: 40, height: 40)
                        .accessibilityLabel(chat.model.tr("part", ["n": String(k + 1)]))
                        .accessibilityIdentifier("disc-\(k + 1)")
                        .accessibilityAddTraits(k == chat.discEp ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { chat.goPart(k) }
                }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .contentShape(Capsule())
        // a drag the phone took away never lifts: the disc goes back to the part that is open (BUGS #149)
        .onChange(of: live) { _, on in
            if !on { DispatchQueue.main.async {
                guard moved else { return }
                moved = false
                chat.discDragging = false
                chat.goPart(chat.ep)
            } }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($live) { _, s, _ in s = true }
                .onChanged { v in
                    let dx = v.translation.width
                    if !moved && abs(dx) < 4 { return }
                    if !moved {
                        moved = true
                        chat.discDragBegan()                 // it is taken from where it stands now, not from the open part
                        base = chat.discX - dx
                    }
                    let x = max(0, min(CGFloat(n - 1) * step, base + dx))
                    chat.discX = x
                    chat.discEp = Int((x / step).rounded())
                }
                .onEnded { v in
                    if moved {
                        let x = max(0, min(CGFloat(n - 1) * step, base + v.translation.width))
                        chat.discDragging = false
                        chat.goPart(Int((x / step).rounded()))
                    } else {
                        let k = Int(((v.location.x - 3) / step).rounded(.down))            // the number under the finger
                        if Taps.shared.allows("disc\(k)") { chat.goPart(k) }
                    }
                    moved = false
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chat.model.tr("a11yParts"))
    }
}

/// Messenger-style swipe back: drag the chat to the right from the very left edge; it follows the finger and, let go
/// far enough (or with a flick), slides away. The top bar never closes the chat, and the conversation still scrolls
/// from anywhere (the phone's own edge-swipe recogniser decides which is which).
struct EdgeSwipe: UIViewRepresentable {
    let chat: ChatController
    let headHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(chat) }

    func makeUIView(context: Context) -> Host {
        let v = Host()
        v.isUserInteractionEnabled = false
        v.coordinator = context.coordinator
        context.coordinator.headHeight = headHeight
        return v
    }

    func updateUIView(_ v: Host, context: Context) { context.coordinator.headHeight = headHeight }

    static func dismantleUIView(_ v: Host, coordinator: Coordinator) { coordinator.detach() }

    final class Host: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { coordinator?.attach(to: window) } else { coordinator?.detach() }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let chat: ChatController
        var headHeight: CGFloat = 0
        private var pan: UIScreenEdgePanGestureRecognizer?
        private weak var window: UIWindow?

        init(_ chat: ChatController) { self.chat = chat }

        func attach(to w: UIWindow) {
            guard pan == nil else { return }
            let p = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(moved(_:)))
            p.edges = .left
            p.delegate = self
            w.addGestureRecognizer(p)
            pan = p
            window = w
        }

        func detach() {
            if let pan { window?.removeGestureRecognizer(pan) }
            pan = nil
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let w = window else { return false }
            return g.location(in: w).y > headHeight                      // the top bar (back, name, part numbers) never closes the chat
        }

        @objc func moved(_ g: UIScreenEdgePanGestureRecognizer) {
            guard let w = window else { return }
            let dx = g.translation(in: w).x
            let vx = g.velocity(in: w).x
            MainActor.assumeIsolated {
                switch g.state {
                case .began, .changed: chat.swipeMoved(dx)
                case .ended: chat.swipeEnded(dx, velocity: vx, cancelled: false)
                case .cancelled, .failed: chat.swipeEnded(dx, velocity: 0, cancelled: true)
                default: break
                }
            }
        }
    }
}
