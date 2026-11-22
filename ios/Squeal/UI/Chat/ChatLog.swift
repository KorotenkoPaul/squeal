import SwiftUI
import UIKit

/// One conversation on screen: the part being read, or (during a part switch) an old part's conversation on its way out.
final class LogModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var rows: [Row]
    /// an old part's conversation: a still picture whose messages slide away; it takes no touches
    @Published var ghost = false
    @Published var ghostHeight: CGFloat? = nil
    /// The room left by the answers not chosen (holdHeight): the chat keeps this height — an empty space under the sent
    /// answer — and every new message takes its place from that space instead of pushing the chat up; once it is used
    /// up, the chat scrolls as usual.
    @Published var hold: CGFloat? = nil
    /// not shown yet: its messages are still being put at the edges they slide in from
    @Published var veiled = false

    let pin = ScrollPin()
    var width: CGFloat = 0
    var viewport: CGFloat = 0
    /// the conversation's own height (its padding included), without any room kept
    var innerH: CGFloat = 0
    var onReady: (() -> Void)? = nil
    private var ready = false

    init(rows: [Row]) { self.rows = rows }

    func measured(_ h: CGFloat) {
        innerH = h
        if let hold, h >= hold { self.hold = nil }
    }

    /// the height the scroll view's content has (the web's scrollHeight)
    var contentHeight: CGFloat { max(viewport, max(innerH, hold ?? 0)) }

    func attached(_ sv: UIScrollView) {
        pin.attach(sv)
        if !ghost { pin.land() }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.ready else { return }
            self.ready = true
            let go = self.onReady
            self.onReady = nil
            go?()
        }
    }

    /// is any of this row on screen?
    func seen(_ row: Row) -> Bool {
        let f = row.frame(logWidth: width)
        let top = pin.top
        let h = ghostHeight ?? viewport
        return f.maxY > top && f.minY < top + h
    }
}

/// The conversation: it scrolls with the phone's own spring at both ends (the description too), shows no scroll bar,
/// and a tap anywhere on it reads on.
struct LogView: View {
    static let space = "chat-log"
    @ObservedObject var log: LogModel
    let chat: ChatController

    var body: some View {
        GeometryReader { g in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(log.rows) { row in
                        RowView(row: row, log: log, chat: chat, logWidth: g.size.width)
                    }
                }
                .padding(.top, ChatMetrics.top).padding(.bottom, ChatMetrics.bottom).padding(.horizontal, ChatMetrics.side)
                .background(GeometryReader { c in
                    Color.clear
                        .onAppear { log.measured(c.size.height) }
                        .onChange(of: c.size.height) { _, h in log.measured(h) }
                })
                .frame(minHeight: max(g.size.height, log.hold ?? 0), alignment: .top)
                .coordinateSpace(name: LogView.space)
                .contentShape(Rectangle())
                .onTapGesture { if !log.ghost { chat.logTapped() } }
                .background(ScrollFinder { log.attached($0) })
            }
            .onAppear { log.viewport = g.size.height; log.width = g.size.width }
            .onChange(of: g.size) { _, s in
                log.viewport = s.height; log.width = s.width
                if log.hold != nil { log.hold = nil }            // the phone turned: the kept room no longer fits, let it go
            }
        }
        .opacity(log.veiled ? 0 : 1)
        .allowsHitTesting(!log.ghost)
        .accessibilityHidden(log.ghost)
    }
}

/// Finds the UIScrollView that SwiftUI's ScrollView is drawn with (the conversation's glide needs its real offset).
struct ScrollFinder: UIViewRepresentable {
    let found: (UIScrollView) -> Void

    func makeUIView(context: Context) -> Probe {
        let v = Probe()
        v.found = found
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ v: Probe, context: Context) { v.found = found }

    final class Probe: UIView {
        var found: ((UIScrollView) -> Void)?
        private weak var seen: UIScrollView?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.look() }
        }
        private func look() {
            var v = superview
            while let s = v {
                if let sv = s as? UIScrollView {
                    if seen !== sv { seen = sv; found?(sv) }
                    return
                }
                v = s.superview
            }
        }
    }
}

/// The bottom of the conversation keeps to the bottom panel's edge (template.html glideDown / keep): something new at
/// the bottom glides it up over 0.26 s, easing out; a growing panel pushes it up with its edge. It never moves the
/// conversation down, and only a finger really scrolling stops it — a quick tap to read on does not.
final class ScrollPin: NSObject {
    private weak var sv: UIScrollView?
    private var observers: [NSKeyValueObservation] = []
    private lazy var loop = FrameLoop { [weak self] now in self?.frame(now) }

    private(set) var gliding = false
    private(set) var glideEnd = 0.0
    /// the bottom panel is still changing its height until then: the glide follows it frame by frame
    var footEnd = 0.0
    private var t0 = 0.0, off: CGFloat = 0
    private var pending = false, pendingFrames = 0
    private var stickUntil = 0.0
    private var setting = false
    private var lastHeight: CGFloat = 0

    func attach(_ s: UIScrollView) {
        guard sv !== s else { return }
        sv = s
        s.alwaysBounceVertical = true
        s.showsVerticalScrollIndicator = false
        lastHeight = s.bounds.height
        observers = [
            s.observe(\.contentSize, options: [.new]) { [weak self] _, _ in self?.changed() },
            s.observe(\.bounds, options: [.new]) { [weak self] v, _ in
                guard let self, abs(v.bounds.height - self.lastHeight) > 0.01 else { return }
                self.lastHeight = v.bounds.height
                self.changed()
            },
        ]
    }

    /// the scroll that shows the very bottom
    var natural: CGFloat {
        guard let sv else { return 0 }
        let inset = sv.adjustedContentInset
        return max(-inset.top, sv.contentSize.height + inset.bottom - sv.bounds.height)
    }

    var top: CGFloat {
        get { sv?.contentOffset.y ?? 0 }
        set {
            guard let sv, abs(sv.contentOffset.y - newValue) > 0.01 else { return }
            setting = true
            sv.contentOffset = CGPoint(x: sv.contentOffset.x, y: newValue)
            setting = false
        }
    }

    var fromBottom: CGFloat { natural - top }
    var contentHeight: CGFloat { sv?.contentSize.height ?? 0 }
    private var fingerScrolls: Bool { sv?.isDragging ?? false }

    /// A chat opens on the last message read — and stays there while its first layout settles.
    func land() {
        stickUntil = chatNow() + 0.4
        top = natural
    }

    func glideDown() {
        guard sv != nil else { return }
        if reduceMotion() {                                    // at once, but still never down
            top = max(top, natural)
            stickUntil = max(stickUntil, chatNow() + 0.1)
            return
        }
        // a glide already under way goes straight on into the new one: no frame standing still between them
        let now = chatNow()
        t0 = gliding ? now - 1.0 / 60 : now
        glideEnd = now + 0.26
        pending = true; pendingFrames = 0
        gliding = true
        loop.start()
    }

    func stop() { gliding = false; pending = false; loop.stop() }

    /// the content or the log's own height changed: the bottom is followed in the same layout pass
    private func changed() {
        guard !setting, sv != nil else { return }
        let now = chatNow()
        if now < stickUntil && !fingerScrolls { top = max(top, natural); if !gliding { return } }
        if gliding {
            if pending { off = max(0, natural - top); pending = false }
            keep(now)
        } else if !fingerScrolls, let sv, !sv.isDecelerating, top > natural + 0.5 {
            top = natural                                      // the panel shrank: no empty room is left under the conversation
        }
    }

    private func frame(_ now: Double) {
        guard gliding else { loop.stop(); return }
        if pending {
            // nothing changed the content's height (scrolled up, then an answer picked): the way to go is what it is now
            pendingFrames += 1
            if pendingFrames < 2 { return }
            off = max(0, natural - top); pending = false
        }
        keep(now)
    }

    private func keep(_ now: Double) {
        if fingerScrolls { stop(); return }
        let n = natural
        let q = max(0, min(1, (now - t0) / 0.26))
        let rest = off * CGFloat(pow(1 - q, 3))
        top = max(top, n - rest)                               // never down
        gliding = q < 1 || now < footEnd
        if !gliding { loop.stop() }
    }
}

/// Messages sliding sideways on a part switch and when a chat opens (template.html SLIDE): every message has one
/// sideways offset pulled by a spring towards its goal — home (0), or just past its own side of the screen (the other
/// side's to the left, the reader's to the right). Leaving and arriving are the same spring, so a switch at any moment
/// only changes goals: whatever is moving keeps its speed and turns smoothly, nothing restarts. Nothing fades but the
/// description and an ending's title. Arrivals wait until everything leaving has gone off the screen, then come in
/// nearest the bottom first, 25 ms apart.
final class SlideEngine {
    final class Spring {
        var x: CGFloat = 0, v: CGFloat = 0, goal: CGFloat = 0, need: CGFloat = 0
        var wait = false, launch = false, fade = false
        var lag = 0.0, at = 0.0, ms = 0.34
    }
    private struct Entry { let row: Row; let log: LogModel }

    static let rateIn: CGFloat = 16, rateOut: CGFloat = 12       // an arrival is home in ≈0.4 s, a leaver off in ≈0.15 s
    private var items: [Entry] = []
    private var t = 0.0
    private lazy var loop = FrameLoop { [weak self] now in self?.tick(now) }

    /// how far a message has to go from its own place to be wholly off the screen
    private func need(_ row: Row, _ log: LogModel) -> CGFloat {
        let f = row.frame(logWidth: log.width)
        return (row.side < 0 ? f.maxX : log.width - f.minX) + 12
    }

    private func run(_ row: Row, _ log: LogModel) {
        if !items.contains(where: { $0.row === row }) { items.append(Entry(row: row, log: log)) }
        if !loop.running { t = chatNow(); loop.start() }
    }

    func isMoving(_ row: Row) -> Bool { items.contains { $0.row === row } }
    func busy(_ log: LogModel) -> Bool { items.contains { $0.log === log } }
    func drop(_ row: Row) { items.removeAll { $0.row === row } }
    func dropAll() { items = []; loop.stop() }

    private func spring(_ row: Row, _ log: LogModel) -> Spring {
        let s = row.spring ?? Spring()
        row.spring = s
        s.need = need(row, log)
        return s
    }

    /// off to its own side: from where it is, at the speed it has; one still off the screen stays off
    func slideOut(_ row: Row, _ log: LogModel, lag: Double) {
        let s = spring(row, log)
        s.fade = false
        s.goal = row.side * s.need * 1.5
        s.wait = false; s.launch = false
        if abs(s.x) >= s.need { s.v = 0 }
        s.at = lag > 0 ? chatNow() + lag : 0
        run(row, log)
    }

    /// in from its own side: it waits at the edge standing still and sets off softly only when its turn comes
    func slideIn(_ row: Row, _ log: LogModel, lag: Double, wait: Bool) {
        let s = spring(row, log)
        s.fade = false
        s.x = row.side * s.need; s.v = 0; s.launch = true; s.goal = 0
        s.wait = wait; s.lag = lag
        s.at = lag > 0 ? chatNow() + lag : 0
        row.x = s.x
        run(row, log)
    }

    /// the description (and an ending's title) fades for as long as the messages take
    func fadeIn(_ row: Row, _ log: LogModel, lag: Double, wait: Bool, ms: Double) {
        row.opacity = 0
        let s = Spring()
        s.fade = true; s.goal = 0; s.wait = wait; s.lag = lag; s.ms = ms
        s.at = lag > 0 ? chatNow() + lag : 0
        row.spring = s
        run(row, log)
    }

    func fadeOut(_ row: Row, ms: Double) {
        if row.spring?.fade == true { drop(row) }
        let op = row.opacity
        if op > 0.02 { withAnimation(.linear(duration: ms * op)) { row.opacity = 0 } } else { row.opacity = 0 }
    }

    private func tick(_ now: Double) {
        // at most two frames' worth per step: after a long frame the messages carry on from where they were
        let dt = CGFloat(max(0, min(1.0 / 30, now - t)))
        t = now
        let leaving = items.contains { ($0.row.spring?.goal ?? 0) != 0 }
        for e in items { if let s = e.row.spring, !s.fade { s.need = need(e.row, e.log) } }      // all the measuring first
        var done: [Row] = []
        for e in items {
            guard let s = e.row.spring else { done.append(e.row); continue }
            if s.launch { s.x = e.row.side * s.need }               // not set off yet: it waits right at the edge, out of sight
            if s.wait {
                if leaving { if !s.fade { e.row.x = s.x }; continue }
                s.wait = false
                s.at = s.lag > 0 ? now + s.lag : 0
            }
            if now < s.at { if !s.fade { e.row.x = s.x }; continue }
            s.launch = false                                        // set off: from standing, softly
            if s.fade {
                withAnimation(.linear(duration: s.ms)) { e.row.opacity = 1 }
                done.append(e.row)
                continue
            }
            if s.goal != 0 { s.goal = e.row.side * max(abs(s.goal), 1.3 * s.need) }   // always aiming well past the edge
            // a critically damped spring, exact for any frame length
            let w = s.goal != 0 ? Self.rateOut : Self.rateIn
            let y = s.x - s.goal
            let c = s.v + w * y
            let k = CGFloat(exp(-Double(w * dt)))
            s.x = s.goal + (y + c * dt) * k
            s.v = (c - w * (y + c * dt)) * k
            let arrived = s.goal != 0 ? abs(s.x) >= s.need : (abs(s.x) < 0.3 && abs(s.v) < 20)
            if arrived {
                if s.goal == 0 { s.x = 0; s.v = 0 }
                done.append(e.row)                                  // wholly off the screen / home
            }
            e.row.x = s.x
        }
        if !done.isEmpty { items.removeAll { e in done.contains { $0 === e.row } } }
        if items.isEmpty { loop.stop() }
    }
}
