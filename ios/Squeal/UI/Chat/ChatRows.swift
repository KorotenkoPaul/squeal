import SwiftUI
import UIKit

/// The chat's own measures (template.html .log, .msg, .intro …).
enum ChatMetrics {
    static let side: CGFloat = 18                 // the log's left and right padding
    static let top: CGFloat = 16, bottom: CGFloat = 8
    static let gap: CGFloat = 6                   // between messages
    static let bubbleFont = AppFont.uiFont(16)
    static let lineHeight: CGFloat = 16 * 1.38
    /// a one-line message (and the "typing…" bubble): 9 + one line + 9
    static let oneLine: CGFloat = 18 + lineHeight

    /// the widest a bubble may be: 78 % of the log's inner width
    static func maxBubble(_ logWidth: CGFloat) -> CGFloat { (logWidth - 2 * side) * 0.78 }

    /// how tall a text bubble comes out (used only to guess whether answers will fit on screen)
    static func bubbleHeight(_ text: String, logWidth: CGFloat) -> CGFloat {
        let w = maxBubble(logWidth) - 28
        let r = (text as NSString).boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin], attributes: [.font: bubbleFont], context: nil)
        let lines = max(1, (r.height / bubbleFont.lineHeight).rounded())
        return 18 + lines * lineHeight
    }
}

extension View {
    /// Text set like the web: the font, with the CSS line height (extra leading shared above and below each line).
    func cssText(_ font: UIFont, lineHeight: CGFloat) -> some View {
        let extra = lineHeight - font.lineHeight
        return self.font(Font(font)).lineSpacing(max(0, extra)).padding(.vertical, extra / 2)
    }
}

/// How a new bubble comes into the chat (template.html inflate() and morph()): out of its pointed corner, while the
/// room for it opens at the same pace — it never overlaps the message above, and a full chat is pushed up exactly as
/// it grows.
struct Grow: Equatable {
    enum Kind: Equatable {
        case inflate                              // from nothing
        case morph(from: CGSize)                  // "typing…" stretches into the message
    }
    let kind: Kind
    let t0: Double
    /// the conversation's own height before this bubble came (with "typing…" still there, for a morph)
    let natBefore: CGFloat
    /// the height the chat is keeping after a choice (nil: none), and the log's height on screen
    let hold: CGFloat?
    let viewport: CGFloat

    static let duration = 0.26
    private static let curve = CubicBezier(0.2, 0.9, 0.3, 1)
    private static let soft = CubicBezier(0.3, 0.6, 0.3, 1)      // a tall one (a video circle) starts a little softer

    /// the room still standing empty under the conversation after a choice
    private var room: CGFloat { max(0, (hold ?? 0) - natBefore) }

    /// the top margin the bubble starts with (≤ 0): the part of it that has no room yet. `h`: its height with the gap.
    func margin0(_ h: CGFloat) -> CGFloat {
        switch kind {
        case .inflate:
            // a chat shorter than the screen: the bubble just grows in its own place; a full chat: it grows at the
            // bottom edge and pushes the conversation up as it grows — just the part that does not fit
            let over = max(viewport, natBefore + h + room) - viewport - 8
            return over > 0 ? -min(max(0, h - room), over) : 0
        case .morph(let from):
            return -max(0, h - ChatMetrics.gap - from.height - room)
        }
    }

    private func curve(_ h: CGFloat) -> CubicBezier {
        if case .morph = kind, -margin0(h) > 100 { return Self.soft }
        return Self.curve
    }

    /// "typing…" turned message: the size it stretches from
    var morphFrom: CGSize? {
        if case .morph(let from) = kind { return from }
        return nil
    }

    func progress(_ now: Double) -> Double { max(0, min(1, (now - t0) / Self.duration)) }
    /// eased 0…1
    func eased(_ now: Double, h: CGFloat) -> Double { curve(h)(progress(now)) }
    func margin(_ now: Double, h: CGFloat) -> CGFloat { margin0(h) * CGFloat(1 - eased(now, h: h)) }
    /// what is inside "typing…" turned message: nothing for the first 30 %, then it fades in
    func contentOpacity(_ now: Double) -> Double {
        guard case .morph = kind else { return 1 }
        let q = progress(now)
        return q <= 0.3 ? 0 : (q - 0.3) / 0.7
    }
}

/// A row of the log that takes `margin` less room than its content (≤ 0, see Grow): the content keeps its bottom on
/// the row's bottom and reaches up over the row above — CSS's negative margin-top.
struct GrowLayout: Layout {
    var grow: Grow?
    var now: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let v = subviews.first else { return .zero }
        let s = v.sizeThatFits(proposal)
        guard let grow else { return s }
        return CGSize(width: s.width, height: max(0, s.height + grow.margin(now, h: s.height)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let v = subviews.first else { return }
        v.place(at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

/// The bubble itself growing out of its pointed corner: bottom left for theirs, bottom right for the reader's.
struct GrowEffect: GeometryEffect {
    var e: Double                                 // eased 0…1
    var from: CGSize?                             // nil: from nothing
    var right: Bool

    func effectValue(size: CGSize) -> ProjectionTransform {
        if e >= 1 { return ProjectionTransform(.identity) }
        let fx = from.map { min(1, Double($0.width) / max(1, Double(size.width))) } ?? 0
        let fy = from.map { min(1, Double($0.height) / max(1, Double(size.height))) } ?? 0
        let sx = CGFloat(max(0.001, fx + (1 - fx) * e)), sy = CGFloat(max(0.001, fy + (1 - fy) * e))
        let ax = right ? size.width : 0, ay = size.height
        let t = CGAffineTransform(translationX: ax, y: ay).scaledBy(x: sx, y: sy).translatedBy(x: -ax, y: -ay)
        return ProjectionTransform(t)
    }
}

/// An answer sliding in from the right: translateX(100% + 40px) → none.
struct EnterEffect: GeometryEffect {
    var p: Double                                 // 0 off to the right … 1 in place
    var animatableData: Double { get { p } set { p = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: CGFloat(1 - p) * (size.width + 40), y: 0))
    }
}

/// One thing in the conversation: the description at the top, a message, the "typing…" / recording bubble, an answer
/// to choose (ChoiceDrafts.swift), or the title at the end.
final class Row: ObservableObject, Identifiable {
    enum Typing: Equatable { case text, voice, video }
    enum Kind: Equatable {
        case intro(String)
        case message(ChatMsg, mine: Bool)
        case typing(Typing)
        case draft(Int, String)
        case end(title: String, sub: String?)
    }

    private static var counter = 0
    let id: Int
    @Published var kind: Kind
    @Published var grow: Grow? = nil
    /// sideways, on a part switch (the SLIDE spring)
    @Published var x: CGFloat = 0
    @Published var hidden = false
    @Published var opacity: Double = 1
    /// an answer: 0 off to the right … 1 in place; chosen; melting away
    @Published var enter: Double = 1
    @Published var chosen = false
    @Published var melted = false
    /// the sent answer glides up to the first answer's place
    @Published var lift: CGFloat = 0
    /// recording: seconds run, and "sending…" once recorded
    @Published var recSec = 0
    @Published var recSending = false

    /// the bubble's own size, and the row's place (its slot, gap included) in the log's content — kept up to date by
    /// the view, and never touched by the row's motion (sliding, growing)
    var size: CGSize = .zero
    var slot: CGRect = .zero
    /// its spring on a part switch (SlideEngine)
    var spring: SlideEngine.Spring? = nil

    init(_ kind: Kind) {
        Row.counter += 1
        id = Row.counter
        self.kind = kind
    }

    /// -1: the other side's (leaves to the left), 1: the reader's (to the right), 0: neither (it only fades)
    var side: CGFloat {
        switch kind {
        case .message(_, let mine): return mine ? 1 : -1
        case .typing: return -1
        case .draft: return 1
        case .intro, .end: return 0
        }
    }
}

extension Row {
    /// where the bubble stands in the log's content when nothing moves it
    func frame(logWidth: CGFloat) -> CGRect {
        let x = side < 0 ? ChatMetrics.side : side > 0 ? logWidth - ChatMetrics.side - size.width : (logWidth - size.width) / 2
        return CGRect(x: x, y: slot.maxY - size.height, width: size.width, height: size.height)
    }
}

/// One row of the log, with whatever motion it is in.
struct RowView: View {
    @ObservedObject var row: Row
    let log: LogModel
    let chat: ChatController
    let logWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: row.grow == nil)) { _ in
            let now = chatNow()
            GrowLayout(grow: row.grow, now: now) {
                placed(now)
            }
        }
        .background(GeometryReader { g in
            let f = g.frame(in: .named(LogView.space))
            Color.clear.onAppear { row.slot = f }.onChange(of: f) { _, n in row.slot = n }
        })
        .offset(x: row.x)
        .opacity(row.hidden ? 0 : row.opacity)
    }

    private var alignment: Alignment { row.side > 0 ? .trailing : row.side < 0 ? .leading : .center }

    @ViewBuilder private func placed(_ now: Double) -> some View {
        let g = row.grow
        let h = row.size.height + ChatMetrics.gap
        let e = g.map { $0.eased(now, h: h) } ?? 1
        let from = g?.morphFrom
        let inside = g.map { $0.contentOpacity(now) } ?? 1
        // the bubble hugs its words, up to 78 % of the log; the description and the end's title may take the whole width
        let limit: CGFloat = row.side == 0 ? .infinity : ChatMetrics.maxBubble(logWidth)
        bubble(inside)
            .background(GeometryReader { g in
                Color.clear.onAppear { row.size = g.size }.onChange(of: g.size) { _, n in row.size = n }
            })
            .modifier(GrowEffect(e: e, from: from, right: row.side > 0))
            .opacity(from == nil ? e : 1)
            .offset(y: row.lift)
            .frame(maxWidth: limit, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.top, topGap)
    }

    private var topGap: CGFloat {
        if case .intro = row.kind { return 0 }
        return ChatMetrics.gap
    }

    @ViewBuilder private func bubble(_ inside: Double) -> some View {
        let maxW = ChatMetrics.maxBubble(logWidth)
        switch row.kind {
        case .intro(let text):
            IntroText(text: text)
        case .message(let m, let mine):
            MessageBubble(msg: m, mine: mine, maxWidth: maxW, inside: inside, chat: chat)
        case .typing(let t):
            TypingBubble(kind: t, sec: row.recSec, sending: row.recSending)
        case .draft(let k, let text):
            DraftBubble(row: row, index: k, text: text, maxWidth: maxW, chat: chat)
        case .end(let title, let sub):
            EndTitle(title: title, sub: sub)
        }
    }
}
