import SwiftUI
import UIKit

/// CI screenshots and nothing else (launch arguments, see SquealApp): the chat reads on / answers by itself.
enum ChatDebug {
    static var autotap = 0          // -autotap N: N more messages are read, one after another
    static var autopick: Int? = nil // -autopick K: at a choice, answer K is picked
    static var autopart: Int? = nil // -autopart K: 2 s on, part K is picked on the disc
}

/// What the bottom panel shows.
struct FootState: Equatable {
    enum Mode: Equatable {
        case tap                    // "Tap to continue"
        case ask                    // "What do you say?" (the answers themselves stand in the chat)
        case end(ChatReader.End)    // Next part / Back to a choice / Read again
        case paywall
    }
    var mode: Mode = .tap
    /// the end's buttons wait, unseen, while the title rides up with the conversation
    var wait = false
    /// "What do you say?" going out with the answers not chosen
    var contGone = false
    /// after 10 s without a tap "Tap to continue" starts to breathe
    var idle = false

    var kind: Int {
        switch mode { case .tap: return 0; case .ask: return 1; case .end: return 2; case .paywall: return 3 }
    }
}

/// The panel's height never jumps: it changes over 0.4 s (fast first, soft at the end), `delay` after `t0`.
struct FootAnim: Equatable {
    let t0: Double
    let delay: Double
    let h0: CGFloat
    static let duration = 0.4
}

/// What FootLayout last drew (read when the next change starts from there).
final class FootBox { var shown: CGFloat = 0 }

/// One open chat: everything template.html's openStory() does on screen — the conversation and its motion, typing
/// and recording, the bottom panel, the part switch, the wallpaper, leaving. What is read and saved is ChatReader's.
@MainActor
final class ChatController: ObservableObject {
    enum Status { case online, typing, recA, recV, sending }

    let model: AppModel
    let story: Story
    let from: Edge
    private(set) var reader: ChatReader!

    @Published private(set) var ep: Int
    @Published private(set) var status: Status = .online
    @Published private(set) var logs: [LogModel] = []
    @Published var foot = FootState()
    @Published private(set) var footAnim: FootAnim? = nil
    /// "Tap to continue" fading out where it stood, at the end
    @Published private(set) var contGhost: String? = nil
    @Published private(set) var toast: String? = nil
    /// the part disc: the number lit, and where the disc is (pt from the first number)
    @Published var discEp: Int
    @Published var discX: CGFloat
    @Published var discDragging = false
    /// the whole screen, sliding in, following the finger, sliding away
    @Published var offset: CGSize
    @Published private(set) var started = false

    let wall = WallKeeper()
    let slide = SlideEngine()
    let media = ChatMedia()
    let footBox = FootBox()

    static let segStep: CGFloat = 44

    // what openStory() keeps in its closure
    private var gen = 0                      // every (re)opening: timers of the chat before it do nothing
    private(set) var born = 0.0
    private(set) var busy = false
    private(set) var leaving = false
    var swiping = false
    private var footFirst = true
    private var wantGlide = false
    private var endIn = false
    private var endLate = false
    private var endShown = 0.0
    private var skipT: Double? = nil
    var pickT: Double? = nil
    private var payAt = 0.0
    var picked = false
    private var typingRow: Row? = nil
    private var typingWork: DispatchWorkItem? = nil
    private var recTimer: Timer? = nil
    private var partWork: DispatchWorkItem? = nil
    private var idleWork: DispatchWorkItem? = nil
    private var toastWork: DispatchWorkItem? = nil
    private var autoTimer: Timer? = nil
    private var autoLeft = 0, autoLast = -1
    private let tapKey = "chat-" + UUID().uuidString

    init(model: AppModel, story: Story, route: ChatRoute) {
        self.model = model
        self.story = story
        from = route.from
        let k = max(0, min(story.parts.count - 1, route.ep))
        ep = k
        discEp = k
        discX = CGFloat(k) * Self.segStep
        let screen = UIScreen.main.bounds.size
        offset = reduceMotion() ? .zero : (route.from == .bottom ? CGSize(width: 0, height: screen.height) : CGSize(width: screen.width, height: 0))
    }

    var log: LogModel? { logs.last }
    var part: Part { story.parts[ep] }
    var fresh: Bool { !footFirst }
    func isCurrent(_ g: Int) -> Bool { g == gen && !leaving }
    var generation: Int { gen }

    func statusText() -> String {
        switch status {
        case .online: return model.tr("online")
        case .typing: return model.tr("typing")
        case .recA: return model.tr("recA")
        case .recV: return model.tr("recV")
        case .sending: return model.tr("sending")
        }
    }

    private func io() -> ChatReader.IO {
        let model = self.model, story = self.story
        return ChatReader.IO(
            prog: { model.prog(story) },
            setProg: { model.setProg(story, $0) },
            premium: { model.store.premium },
            taps: { model.store.taps },
            setTaps: { model.store.set("taps", $0) })
    }

    func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: - opening

    /// The screen is up: open the part asked for and slide in.
    func start(part: Int?) {
        guard !started else { return }
        started = true
        // any touch on the chat (a scroll, the header) puts off the hint's "breathing" by another 10 s, as on the web
        Taps.shared.onDown[tapKey] = { [weak self] _ in self?.nudge() }
        open(part: part, first: true)
        if offset != .zero { withAnimation(reduceMotion() ? nil : .timingCurve(0.25, 0.8, 0.25, 1, duration: 0.34)) { offset = .zero } }
        // the story page under the chat is gone: back returns to the screen the story was opened from
        after(0.4) { [weak self] in if let self, !self.leaving, self.model.chat != nil { self.model.previewID = nil } }
        autoplay()
    }

    /// openStory(): a part of this story opens in this chat (the first time, a part switch, "Next part", "Read again",
    /// back to a choice). A part switch replaces the conversation in place: nothing blinks, the header and its part
    /// disc stay the very same.
    func open(part k: Int?, first: Bool = false) {
        partWork?.cancel()                                   // a part picked on the disc a moment before never overrides what opens now
        let prevEp: Int? = first ? nil : ep
        if !first { stopCurrent() }                          // whatever the old chat was typing or recording stops with it
        gen += 1
        let pr = model.prog(story)                           // while the part before this one is still the open one
        reader = ChatReader(story: story, part: k, progress: pr, io: io())
        ep = reader.ep
        model.chatShows(part: ep)
        born = chatNow()
        busy = false; picked = false; footFirst = true; wantGlide = false; endIn = false; endLate = false
        endShown = 0; skipT = nil; pickT = nil; typingRow = nil
        status = .online
        footAnim = nil; contGhost = nil
        foot = FootState()

        // the conversation: messages read before are simply there
        var rows = [Row(.intro(part.prologue))]
        for m in reader.messages.prefix(reader.i) { rows.append(Row(.message(m, mine: m.from == part.right))) }
        let new = LogModel(rows: rows)
        let old = log
        // a part switch: the old conversation, as it stood, stays as a still picture whose messages slide out to their
        // own sides; then the new part's — already laid out — slides in the same way
        let switching = old != nil && prevEp != nil && prevEp != ep && !reduceMotion()
        if switching, let old {
            old.ghost = true
            old.ghostHeight = old.viewport
            new.veiled = true
            logs.append(new)
        } else {
            for l in logs { for r in l.rows { slide.drop(r) } }
            new.veiled = first && !reduceMotion()
            logs = [new]
        }
        let g = gen
        new.onReady = { [weak self] in self?.slides(new: new, old: switching ? old : nil, first: first, gen: g) }
        after(0.6) { if new.veiled { new.veiled = false } }  // whatever happens, the conversation shows

        // the wallpaper: interactive parts show the whole story's doodles plus those of the endings still in reach
        wall.show(Doodles.config(part), seed: story.id + ":" + String(ep), vis: reader.inReach, switching: !first, same: prevEp == ep)

        discEp = ep
        if !discDragging { discX = CGFloat(ep) * Self.segStep }

        controls()
        // opened just after the reader's own answer (left before the reply came): the other side answers by itself,
        // 1 s on, free — as it does right after picking
        if reader.owesReply {
            let at = reader.i
            busy = true                                      // a tap meanwhile does not read (it would cost a free tap for a free reply)
            after(1) { [weak self] in
                guard let self, g == self.gen else { return }
                self.busy = false
                if !self.leaving, self.reader.i == at { self.step(free: true) }
            }
        }
    }

    /// Once the new conversation is laid out: the messages on screen come in from their own sides, nearest the bottom
    /// first; the description (and an ending's title) only fades — and on opening a chat the description is simply there.
    private func slides(new: LogModel, old: LogModel?, first: Bool, gen g: Int) {
        defer { new.veiled = false }
        guard g == gen, !reduceMotion() else { return }
        func arrive(_ lag: Double, _ wait: Bool, _ intro: Bool) {
            var k = 0
            for row in new.rows.reversed() where new.seen(row) {
                if row.side != 0 {
                    slide.slideIn(row, new, lag: lag + min(Double(k) * 0.025, 0.15), wait: wait)
                    k += 1
                } else {
                    var isIntro = false
                    if case .intro = row.kind { isIntro = true }
                    if intro || !isIntro { slide.fadeIn(row, new, lag: lag, wait: wait, ms: 0.4 + min(Double(max(0, k - 1)) * 0.025, 0.15)) }
                }
            }
        }
        if first { arrive(0.24, false, false); return }
        guard let old else { return }
        // the old part's messages go off to their own sides: those moving keep their speed and turn, those at rest
        // start softly (nearest the bottom first); the ones not on screen are simply hidden
        var k = 0
        for row in old.rows.reversed() {
            if row.side == 0 { slide.fadeOut(row, ms: 0.15 + min(Double(max(0, k - 1)) * 0.025, 0.15)); continue }
            if !old.seen(row) { slide.drop(row); row.hidden = true; continue }
            slide.slideOut(row, old, lag: slide.isMoving(row) ? 0 : min(Double(k) * 0.025, 0.15))
            k += 1
        }
        ghostGone(old, since: chatNow())
        arrive(0, true, true)                                // the new ones: as soon as the old ones are off screen
    }

    /// an old part's conversation goes once nothing in it moves any more
    private func ghostGone(_ old: LogModel, since: Double) {
        after(0.05) { [weak self] in
            guard let self else { return }
            if self.slide.busy(old) || chatNow() - since < 0.35 { self.ghostGone(old, since: since); return }
            self.logs.removeAll { $0 === old }
        }
    }

    // MARK: - reading on

    /// the second tap of a double tap on "Next part", "Read again", "Read" or a tile lands on the new chat and must not
    /// read its first message: for its first 0.5 s the chat takes no taps, and a tap within 0.3 s of an ignored one
    /// belongs to the same burst
    func early() -> Bool {
        let t = chatNow()
        let burst = skipT.map { t - $0 < 0.3 && t - born < 1.2 } ?? false
        let justPicked = pickT.map { t - $0 < 0.45 } ?? false
        if t - born < 0.5 || burst || justPicked { skipT = t; return true }
        return false
    }

    /// the end's buttons take no tap for their first 0.45 s on screen (tapping fast through to the end)
    private func endEarly() -> Bool { chatNow() - endShown < 0.45 }

    /// One rule for every double tap (the web's SPOT, 2026-11-13): a tap that lands, within 0.8 s and 40 pt of the tap
    /// before it, on a DIFFERENT control from the one that tap pressed is the second half of that double tap, not a
    /// choice — a control has just appeared or slid under the finger ("Read again" after the last message, an answer
    /// after "back to a choice" or after the tap that read the last message). It does nothing. The same control again
    /// (a voice message's play, the conversation itself) still works. `control` nil: the conversation or the hint.
    func spotAllows(_ control: String?, at p: CGPoint) -> Bool {
        Taps.shared.allows(control.map { "chat:" + $0 }, at: p)       // the app's one rule (SpotRule), shared with every screen
    }

    func logTapped(at p: CGPoint) {
        nudge()
        guard spotAllows(nil, at: p) else { return }
        if !early() { step() }
    }

    func footTapped(at p: CGPoint) {
        nudge()
        guard spotAllows(nil, at: p), foot.mode == .tap else { return }
        if !early() { step() }
    }

    private func addMessage(_ m: ChatMsg, grows: Bool) -> Row {
        let row = Row(.message(m, mine: m.from == part.right))
        if grows { grow(row, .inflate) }
        log?.rows.append(row)
        return row
    }

    /// a new bubble grows out of its own corner (0.26 s) and the chat makes room for it as it grows
    private func grow(_ row: Row, _ kind: Grow.Kind) {
        guard !reduceMotion(), let log else { return }
        let g = Grow(kind: kind, t0: chatNow(), natBefore: log.innerH, hold: log.hold, viewport: log.viewport)
        row.grow = g
        after(Grow.duration + 0.06) { if row.grow == g { row.grow = nil } }
    }

    func glideDown() { log?.pin.glideDown() }

    /// One tap: the next message. The reader's own is there at once; the other side first types (or records) it.
    func step(free: Bool = false) {
        guard started, !busy, !leaving else { return }
        switch reader.begin(free: free) {
        case .none:
            return
        case .paywall:
            showPaywall()
        case .mine(let m):
            _ = addMessage(m, grows: true)
            glideDown()
            controls()
        case .theirs(let m):
            busy = true
            status = m.video != nil ? .recV : m.voice != nil ? .recA : .typing
            // a voice or video message is "recorded" first: a bubble with a running timer, for exactly as long as the
            // message lasts, then about a second to send; then the message itself appears
            let kind: Row.Typing = m.video != nil ? .video : m.voice != nil ? .voice : .text
            let t = Row(.typing(kind))
            grow(t, .inflate)
            log?.rows.append(t)
            typingRow = t
            let g = gen
            if kind != .text {
                let t0 = Date(), dur = m.dur ?? 3
                recTimer?.invalidate()
                recTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, g == self.gen else { return }
                        let sec = min(dur, Int(Date().timeIntervalSince(t0)))
                        if t.recSec != sec { t.recSec = sec }
                        if sec >= dur && !t.recSending { t.recSending = true; self.status = .sending }
                    }
                }
            }
            glideDown()
            // the same with Reduce Motion: "typing…" and recording are pacing, not motion
            let work = DispatchWorkItem { [weak self] in self?.arrive(m, typing: t, gen: g) }
            typingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + m.wait / 1000, execute: work)
        }
    }

    /// "typing…" turns into the message: the same bubble stretches from its size to the message's, from its pointed
    /// corner, while the words fade in — no second bubble grows.
    private func arrive(_ m: ChatMsg, typing t: Row, gen g: Int) {
        recTimer?.invalidate(); recTimer = nil
        guard g == gen, !leaving else { return }
        let from = t.size
        typingRow = nil
        t.kind = .message(m, mine: false)
        t.grow = nil
        grow(t, .morph(from: from))
        reader.arrived()
        status = .online
        busy = false
        // the web's conversation is a live region: VoiceOver reads a message as it comes
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: (m.video != nil ? model.tr("a11yVideo") + ": " : "") + m.text)
        }
        glideDown()
        controls()
    }

    /// the other side answers by itself, 1 s after the reader's own answer; a tap meanwhile does not hurry it
    func replySoon() {
        guard reader.replyComesByItself else { return }
        busy = true
        let g = gen
        after(1) { [weak self] in
            guard let self, self.isCurrent(g) else { return }
            self.busy = false
            self.step(free: true)
        }
    }

    func setBusy(_ b: Bool) { busy = b }

    /// the hint stays still; only after 10 s with no tap does it start to breathe
    func nudge() {
        guard !leaving else { return }
        idleWork?.cancel()
        if foot.idle { foot.idle = false }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.leaving, self.foot.mode == .tap else { return }
            self.foot.idle = true
        }
        idleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    // MARK: - the bottom panel

    /// The panel shows what comes next. It never jumps to a new height: it grows (or shrinks) over 0.4 s and the
    /// conversation glides with its edge, as if a new message had pushed it.
    func controls() {
        let h0 = footBox.shown
        let atBottom = (log?.pin.fromBottom ?? 0) < 8
        let was = foot.kind
        footAnim = nil
        controlsNow()
        let glide = wantGlide
        wantGlide = false
        if footFirst { footFirst = false; return }
        let ending = endIn
        endIn = false
        let g = gen
        if ending {
            // the title first, then the buttons: they fade in where they stand (0.125 s) once the panel has made room
            after(endLate ? 0.4 : 0.125) { [weak self] in
                guard let self, self.isCurrent(g) else { return }
                withAnimation(.timingCurve(0, 0, 0.58, 1, duration: 0.125)) { self.foot.wait = false }
            }
        }
        let gliding = log?.pin.gliding ?? false
        if reduceMotion() { glideDown(); return }
        if foot.kind != was, h0 > 0 {
            // growing while a new message is still gliding into view: the message settles first, then the panel opens
            // (not at the end: there everything moves up together, while "Tap to continue" fades)
            let now = chatNow()
            let d = gliding && !ending ? max(0, (log?.pin.glideEnd ?? now) - now) : 0
            let a = FootAnim(t0: now, delay: d, h0: h0)
            footAnim = a
            log?.pin.footEnd = now + d + FootAnim.duration
            after(d + FootAnim.duration + 0.05) { [weak self] in if self?.footAnim == a { self?.footAnim = nil } }
            if atBottom || gliding || glide { glideDown() }
        } else if glide || gliding {
            glideDown()
        }
    }

    private func controlsNow() {
        switch reader.foot {
        case .ask(let choices):
            showChoices(choices)                             // ChoiceDrafts.swift
            wantGlide = true
        case .end(let end):
            showEnd(end)
        case .paywall:
            showPaywall()
        case .tap:
            foot.mode = .tap
            foot.contGone = false
            nudge()
        }
    }

    private func showEnd(_ end: ChatReader.End) {
        let calm = !footFirst && !reduceMotion()             // reached now, while reading (not opened already finished)
        if calm, foot.mode == .tap || foot.mode == .ask {    // "Tap to continue" fades out where it stands
            contGhost = model.tr(foot.mode == .ask ? "ask" : "tap")
            DispatchQueue.main.async { [weak self] in
                withAnimation(.timingCurve(0, 0, 0.58, 1, duration: 0.125)) { self?.contGhost = nil }
            }
        }
        // the title comes in once the message before it has grown (a video circle grows 210 pt in 0.26 s; the title
        // added in the same frame made the chat jump), then rides up with the conversation
        let words = ChatText.end(story, part: ep, end: end, lang: model.lang)
        let title = Row(.end(title: words.title, sub: words.sub))
        let last = log?.rows.last
        let growing = calm && (last?.size.height ?? 0) > 120 && last?.grow != nil
        let g = gen
        let put: () -> Void = { [weak self] in
            guard let self, self.isCurrent(g), let log = self.log else { return }
            if growing { self.grow(title, .inflate) }
            log.rows.append(title)
            if growing, log.pin.fromBottom < 140 { self.glideDown() }      // (scrolled up meanwhile: left where it is)
        }
        endLate = growing
        if growing { after(0.27, put) } else { put() }
        if calm { endIn = true; foot.wait = true }           // the title rides up with the conversation; the buttons wait
        wantGlide = true
        idleWork?.cancel()
        foot.idle = false
        foot.contGone = false
        foot.mode = .end(end)
        endShown = chatNow() + (calm ? (endLate ? 0.4 : 0.125) : 0)
    }

    func showPaywall() {
        idleWork?.cancel()
        if foot.mode != .paywall { payAt = chatNow() }
        foot.idle = false
        foot.contGone = false
        foot.mode = .paywall
    }

    /// "Subscribe to keep reading" (fast reading into the paywall never presses it)
    func payTapped() {
        if chatNow() - payAt < 0.45 { return }
        let first = L10n.list(model.lang, "menu").first ?? ""
        showToast(model.tr("inApp", ["x": first]))
    }

    func nextTapped() {
        guard !early(), !endEarly(), !leaving else { return }
        open(part: ep + 1)
    }

    /// "Read again" / "Start over"
    func againTapped() {
        guard !early(), !endEarly(), !leaving else { return }
        let k = reader.again()
        open(part: k)
    }

    /// "Back to a choice": straight back to a turning point on the path just read
    func turnTapped(_ k: Int) {
        guard !early(), !endEarly(), !leaving else { return }
        reader.backToChoice(k)
        open(part: ep)
    }

    func showToast(_ text: String) {
        toastWork?.cancel()
        let quick = reduceMotion()
        withAnimation(quick ? nil : .timingCurve(0.25, 0.8, 0.25, 1, duration: 0.28)) { toast = text }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(quick ? nil : .timingCurve(0.42, 0, 1, 1, duration: 0.2)) { self?.toast = nil }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: - the part disc

    /// A part is picked on the disc (a tap on its number, or the disc let go on it): the disc glides there and, 0.26 s
    /// on, that part opens. Only the last choice counts, however quick the taps; back on the open part, nothing was
    /// stopped and it reads on.
    func goPart(_ k: Int) {
        let k = max(0, min(story.parts.count - 1, k))
        discEp = k
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: reduceMotion() ? 0 : 0.32)) { discX = CGFloat(k) * Self.segStep }
        partWork?.cancel()
        if k == ep { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.leaving else { return }
            if self.swiping {                                // dropped for a swipe: the disc goes back to the open part
                self.discEp = self.ep
                withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.32)) { self.discX = CGFloat(self.ep) * Self.segStep }
                return
            }
            self.open(part: k)
        }
        partWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion() ? 0 : 0.26), execute: work)
    }

    /// a drag takes over from a tap made a moment before
    func discDragBegan() { partWork?.cancel(); discDragging = true }

    // MARK: - leaving

    /// leaving the chat or the part: the message being typed or recorded is dropped (a free tap paid for it comes
    /// back), and whatever plays stops
    private func stopCurrent() {
        reader?.stop()
        typingWork?.cancel(); typingWork = nil
        recTimer?.invalidate(); recTimer = nil
        idleWork?.cancel()
        media.stopAll()
    }

    /// Back (the arrow, or the swipe let go far enough): the chat slides away to the right and you land where you opened
    /// the story. On its way out it takes no taps: nothing new is read or saved.
    func close() {
        guard !leaving else { return }
        leaving = true
        reader?.leaving = true
        stopCurrent()
        partWork?.cancel()
        autoTimer?.invalidate()
        model.chatLeaves()
        model.previewID = nil
        let width = UIScreen.main.bounds.width
        let token = model.chat?.token
        Taps.shared.onDown[tapKey] = nil
        let done: () -> Void = { [weak self] in
            guard let self else { return }
            self.slide.dropAll()
            self.model.chatGone(token)
        }
        if reduceMotion() { done(); return }
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { offset = CGSize(width: width, height: 0) }
        after(0.3, done)
    }

    // MARK: - the swipe back

    /// The finger has taken the chat (from the very left edge): it follows 1:1 and the screen you came from shows behind.
    /// The message being typed keeps coming: the swipe may be called off.
    func swipeMoved(_ dx: CGFloat) {
        guard !leaving else { return }
        if !swiping { swiping = true; model.previewID = nil }
        offset = CGSize(width: max(0, dx), height: 0)
    }

    /// Let go: far enough (over 35 % of the width) or with a flick (over 0.5 pt/ms) it slides away; else it comes back.
    func swipeEnded(_ dx: CGFloat, velocity: CGFloat, cancelled: Bool) {
        guard swiping else { return }
        swiping = false
        let width = UIScreen.main.bounds.width
        let go = !cancelled && (dx > width * 0.35 || velocity > 500)
        if go { close(); return }
        withAnimation(reduceMotion() ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { offset = .zero }
    }

    // MARK: - CI screenshots

    private func autoplay() {
        if let k = ChatDebug.autopart { after(2) { [weak self] in self?.goPart(k) } }
        guard ChatDebug.autotap > 0 || ChatDebug.autopick != nil else { return }
        autoLeft = ChatDebug.autotap
        autoLast = -1
        autoTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.leaving, chatNow() - self.born > 1.2 else { return }
                if self.autoLeft > 0, !self.busy, self.foot.mode == .tap {
                    if self.reader.i != self.autoLast { self.autoLast = self.reader.i; self.autoLeft -= 1; self.step() }
                } else if self.autoLeft <= 0, let k = ChatDebug.autopick, self.foot.mode == .ask, !self.picked, !self.busy {
                    if let row = self.log?.rows.first(where: { if case .draft(let j, _) = $0.kind { return j == k } else { return false } }) {
                        ChatDebug.autopick = nil
                        self.pickDraft(row)
                    }
                }
            }
        }
    }
}

/// The words at the end of a part.
enum ChatText {
    /// "Nobody's Home · Part 1", and for an interactive story "Ending 2 of 3 · Out Alive"
    static func end(_ story: Story, part: Int, end: ChatReader.End, lang: String) -> (title: String, sub: String?) {
        let title = story.title + (story.parts.count > 1 ? " · " + L10n.tr(lang, "part", ["n": String(part + 1)]) : "")
        let sub = end.interactive ? L10n.tr(lang, "ending", ["n": String(end.which), "m": String(end.of)]) + " · " + end.name : nil
        return (title, sub)
    }
}
