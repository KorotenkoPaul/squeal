import SwiftUI
import UIKit

/// "HORROR · 7 MIN" (+ the gamepad of an interactive story): the caption under a title in Favourites, Search and the reel.
struct MetaLine: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    var size: CGFloat = 12
    var tracking: CGFloat = 0.05
    var body: some View {
        let locale = Locale(identifier: model.lang)
        HStack(spacing: 0) {
            Text((model.genreName(story.genre) + " · " + model.minutes(story) + (story.interactive ? " · " : "")).uppercased(with: locale))
                .font(AppFont.ui(size)).tracking(size * tracking)
            if story.interactive {
                Icons.pad(size * 1.3).accessibilityLabel(model.tr("interactive"))
            }
        }
        .foregroundStyle(Theme.muted)
        .lineLimit(1)
    }
}

/// .label: a section heading (TOP THIS WEEK, HORROR)
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(AppFont.ui(13, 700)).tracking(13 * 0.06).foregroundStyle(Theme.muted)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// p.hint: a muted line in the middle (with a paragraph's own 13 px above and below)
struct HintText: View {
    let text: String
    var body: some View {
        Text(text).font(AppFont.ui(13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
    }
}

/// A square cover with the story's progress line (Search rows, the reel)
struct Thumb: View {
    @EnvironmentObject var model: AppModel
    let story: Story
    var body: some View {
        let f = Double(model.percent(story)) / 100
        let _ = model.progressRev
        ZStack(alignment: .bottom) {
            CoverImage(file: story.cover)
            if f > 0 { ProgressLine(id: story.id, fraction: f, height: 2) }
        }
        .frame(width: 64, height: 64)
        .background(Theme.deep)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A pan of our own on the UIScrollView a SwiftUI ScrollView is drawn with. `begins` decides, at the finger's first
/// clear move, whether the touch is ours; if it is, the scroll view never gets it (its own pan waits for ours to fail),
/// so the page does not scroll under a sideways swipe or a pull of ours.
final class HeldPan: NSObject, UIGestureRecognizerDelegate {
    struct Move { var translation: CGPoint; var velocity: CGPoint; var location: CGPoint; var start: CGPoint; var time: Double }
    var begins: (Move) -> Bool = { _ in false }
    var changed: (Move) -> Void = { _ in }
    var ended: (Move, _ cancelled: Bool) -> Void = { _, _ in }

    private weak var sv: UIScrollView?
    private var pan: UIPanGestureRecognizer?
    private var start = CGPoint.zero

    func attach(_ s: UIScrollView) {
        guard sv !== s else { return }
        detach()
        let p = UIPanGestureRecognizer(target: self, action: #selector(moved(_:)))
        p.delegate = self
        p.maximumNumberOfTouches = 1
        p.cancelsTouchesInView = false
        s.addGestureRecognizer(p)
        pan = p; sv = s
    }

    func detach() {
        if let pan { sv?.removeGestureRecognizer(pan) }
        pan = nil; sv = nil
    }

    var scrollView: UIScrollView? { sv }

    private func move(_ g: UIPanGestureRecognizer) -> Move {
        let t = g.translation(in: nil), l = g.location(in: nil)
        return Move(translation: t, velocity: g.velocity(in: nil), location: l, start: CGPoint(x: l.x - t.x, y: l.y - t.y), time: CACurrentMediaTime())
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let g = g as? UIPanGestureRecognizer else { return false }
        return begins(move(g))
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other !== sv?.panGestureRecognizer
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        other === sv?.panGestureRecognizer
    }

    @objc private func moved(_ g: UIPanGestureRecognizer) {
        let m = move(g)
        switch g.state {
        case .began, .changed: changed(m)
        case .ended: ended(m, false)
        case .cancelled, .failed: ended(m, true)
        default: break
        }
    }
}

/// A finger on a card (a tile, a slider card), read by UIKit the way a UIButton inside a scroll view reads it: the
/// press comes down, and the moment the page starts scrolling the scroll view takes the touch away (`cancelled`).
/// It never holds the page still: a drag up or down that starts on the card scrolls the page natively. (A SwiftUI
/// `DragGesture(minimumDistance: 0)` on the card — even as a simultaneous gesture — kept the page from scrolling on
/// iOS 26 when the finger came down on it: BUGS #169.) Points are in the view's own space.
struct PressSurface: UIViewRepresentable {
    /// the finger came down here; `late`: how long ago it really touched (the scroll view may hand a still finger over
    /// a moment late)
    var began: (_ at: CGPoint, _ late: Double) -> Void
    var moved: (_ translation: CGSize) -> Void
    /// lifted (`cancelled` false), or taken away by the scroll view or the phone (`cancelled` true)
    var ended: (_ cancelled: Bool) -> Void

    func makeUIView(context: Context) -> Surface {
        let v = Surface()
        v.backgroundColor = .clear
        v.isMultipleTouchEnabled = false
        v.isAccessibilityElement = false
        v.owner = self
        return v
    }
    func updateUIView(_ v: Surface, context: Context) { v.owner = self }

    final class Surface: UIView {
        var owner: PressSurface?
        private weak var finger: UITouch?
        private var start = CGPoint.zero

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard finger == nil, let t = touches.first else { return }
            finger = t
            start = t.location(in: self)
            owner?.began(start, max(0, CACurrentMediaTime() - t.timestamp))
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let t = finger, touches.contains(t) else { return }
            let p = t.location(in: self)
            owner?.moved(CGSize(width: p.x - start.x, height: p.y - start.y))
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let t = finger, touches.contains(t) else { return }
            finger = nil
            owner?.ended(false)
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let t = finger, touches.contains(t) else { return }
            finger = nil
            owner?.ended(true)
        }
    }
}
