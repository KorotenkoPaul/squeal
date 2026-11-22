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
struct HintLine: View {
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
