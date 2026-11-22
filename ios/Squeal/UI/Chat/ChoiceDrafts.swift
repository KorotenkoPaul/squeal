import SwiftUI

// THE CHOICE POINT — the "drafts" design (owner's decision of 2026-11-14, ON TRIAL; see IDEAS.md).
//
// Everything that belongs to how answers are offered and picked lives in this one file, so the design can be swapped:
// the chat (ChatController) only calls `showChoices(_:)` when it is the reader's turn, and expects, once an answer is
// picked, `reader.pick(k)` to have been called and the reader's message to stand in the log. The rest of the chat
// knows drafts only as a kind of row (`Row.Kind.draft`, drawn by `DraftBubble`).
//
// The design: the answers are not a panel that grows under the chat. They come into the chat itself, on the reader's
// side, as outlined drafts of the reader's own message — the very size, place and line breaks they will have once
// sent. The bottom panel keeps its height ("Tap to continue" becomes "What do you say?"), so the chat only moves as
// it does for any new message. A tap fills the chosen draft with colour and it is sent where it stands; the others
// melt away and leave their room empty, and the next messages come into that room — the chat does not move at all.

extension ChatController {
    /// It is the reader's turn: the answers come into the conversation as drafts.
    func showChoices(_ choices: [Choice]) {
        guard let log else { return }
        foot.idle = false
        foot.contGone = false
        foot.mode = .ask
        log.rows.removeAll { if case .draft = $0.kind { return true } else { return false } }
        let drafts = choices.enumerated().map { Row(.draft($0.offset, $0.element.text)) }
        picked = false
        // reached while reading (not a chat opened at a choice): a full chat first glides up to open their room (as for
        // any message, 0.26 s); then they slide in from the right, one by one (0.34 s each, 70 ms apart)
        let slideIn = fresh && !reduceMotion()
        if slideIn {
            let tall = drafts.reduce(CGFloat(0)) { h, d in
                if case .draft(_, let text) = d.kind { return h + ChatMetrics.bubbleHeight(text, logWidth: log.width) + ChatMetrics.gap }
                return h
            }
            let away = max(log.viewport, max(log.innerH + tall, log.hold ?? 0)) - log.viewport - log.pin.top
            let lag = away > 8 ? 0.26 : 0.06
            for d in drafts { d.enter = 0 }
            DispatchQueue.main.async {
                for (k, d) in drafts.enumerated() {
                    withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.34).delay(lag + Double(k) * 0.07)) { d.enter = 1 }
                }
            }
        }
        log.rows.append(contentsOf: drafts)
    }

    /// An answer is tapped. It fills with colour and gets its pointed corner (0.24 s) while the others melt away to the
    /// right; then it is sent where it stands (one that stood lower glides up to the first place, 0.3 s). The chat keeps
    /// its height. The other side answers by itself 1 s on.
    func pickDraft(_ row: Row) {
        guard let log, case .draft(let k, _) = row.kind else { return }
        // (0.6 s: still coming in) the second tap of a double tap on "back to a choice" never picks
        if picked || busy || leaving || chatNow() - born < 0.6 { return }
        if reader.outOfTaps { showPaywall(); return }        // out of taps: the choice is not made
        picked = true
        setBusy(true)
        pickT = chatNow()                                    // the second tap of a double tap on an answer reads nothing
        let drafts = log.rows.filter { if case .draft = $0.kind { return true } else { return false } }
        let height = log.contentHeight                       // the chat keeps exactly this height: nothing moves
        let away = log.pin.fromBottom > 8
        if away { glideDown() }                              // scrolled up to reread: it first comes down to the drafts
        let quick = reduceMotion()
        withAnimation(.timingCurve(0, 0, 0.58, 1, duration: quick ? 0 : 0.24)) {
            row.chosen = true                                // the chosen one fills with colour
            foot.contGone = true
        }
        withAnimation(.timingCurve(0.42, 0, 1, 1, duration: quick ? 0 : 0.24)) {
            for d in drafts where d !== row { d.melted = true }
        }
        let g = generation
        after(away ? 0.28 : quick ? 0 : 0.24) { [weak self] in
            guard let self, self.isCurrent(g), let log = self.log else { return }     // closed meanwhile: nothing is sent
            let dy = row.slot.minY - (drafts.first?.slot.minY ?? row.slot.minY)
            log.rows.removeAll { r in drafts.contains { $0 === r } }
            log.hold = height                                // the room the drafts took stays, empty, until new messages fill it
            self.setBusy(false)
            let sent = self.reader.pick(k)                   // the pick is the tap (one free tap)
            self.wall.setVis(self.reader.inReach)            // the endings this choice closed off: their doodles fall
            guard case .mine(let m) = sent else { self.controls(); return }
            let msg = Row(.message(m, mine: true))
            if dy != 0 && !reduceMotion() {                  // a lower one glides up to the first place
                msg.lift = dy
                DispatchQueue.main.async { withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.3)) { msg.lift = 0 } }
            }
            log.rows.append(msg)
            self.glideDown()
            self.controls()
            self.replySoon()
        }
    }
}

/// An answer to choose: a draft of the reader's own message, outlined (1.5 pt, the colour of sent messages), in the
/// chat itself. Chosen, it fills with that colour and takes a sent message's pointed corner.
struct DraftBubble: View {
    @ObservedObject var row: Row
    let index: Int
    let text: String
    let maxWidth: CGFloat
    let chat: ChatController

    var body: some View {
        Button { chat.pickDraft(row) } label: {
            Text(text)
                .cssText(ChatMetrics.bubbleFont, lineHeight: ChatMetrics.lineHeight)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .buttonStyle(DraftStyle(chosen: row.chosen))
        .modifier(EnterEffect(p: row.enter))
        .opacity(row.enter)
        .offset(x: row.melted ? 24 : 0)
        .opacity(row.melted ? 0 : 1)
        .allowsHitTesting(!row.melted && !row.chosen)
        .accessibilityHint(chat.model.tr("a11yAnswer"))
    }
}

private struct DraftStyle: ButtonStyle {
    let chosen: Bool
    func makeBody(configuration: Configuration) -> some View {
        let shape = bubbleShape(mine: true, pointed: chosen)
        configuration.label
            .background(shape.fill(chosen ? Theme.me : Color(hex: 0x6a4bb8, configuration.isPressed ? 0.25 : 0)))
            .overlay(shape.strokeBorder(Theme.me, lineWidth: 1.5))
            .contentShape(shape)
    }
}
