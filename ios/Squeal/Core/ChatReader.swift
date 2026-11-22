import Foundation

/// One message as the chat shows it: a story message, or the reader's own answer at a choice.
struct ChatMsg: Equatable {
    let message: Message
    var answer = false

    var from: String { message.from }
    var text: String { message.text }
    var voice: String? { message.voice }
    var video: String? { message.video }
    var dur: Int? { message.dur }
    /// ms the other side takes before this message appears (typing, or recording and sending)
    var wait: Double { Reading.msgWait(message) }
}

/// The reading of one part of one story — everything template.html's openStory() decides, without the screen:
/// where the chat opens, the path through an interactive part, what a tap or an answer does, what is saved,
/// free taps and the paywall. The screen (ChatController) only adds time and motion.
final class ChatReader {
    /// Where progress and the free taps live (the app: AppModel + Store; tests: a Store alone).
    struct IO {
        let prog: () -> Progress
        let setProg: (Progress) -> Void
        let premium: () -> Bool
        let taps: () -> Int
        let setTaps: (Int) -> Void
    }

    struct End: Equatable {
        let last: Bool                       // no part after this one: no "Next part"
        let interactive: Bool                // "Start over" instead of "Read again"
        let which: Int, of: Int              // "Ending 2 of 3"
        let name: String
        let turns: Int                       // choices made on the way here: one "back to a choice" button each
    }

    enum Foot: Equatable { case tap, ask([Choice]), end(End), paywall }
    enum Step: Equatable { case none, paywall, mine(ChatMsg), theirs(ChatMsg) }

    let story: Story
    let ep: Int
    let part: Part
    let io: IO
    private(set) var path: [String]?
    private(set) var messages: [ChatMsg]
    private(set) var i: Int
    /// on its way out (back, swipe, another part): nothing new is read or saved
    var leaving = false
    /// a free tap paid for a message not shown yet: given back if the chat closes first
    private(set) var paid = false

    /// Opens `part` (nil: carry on — the current part or the next unfinished one). `progress` is the saved progress
    /// as it stands while the chat before this one (if any) is still the one on screen.
    init(story: Story, part k: Int?, progress: Progress, io: IO) {
        self.story = story
        self.io = io
        var pr = progress
        let k0 = max(0, min(story.parts.count - 1, k ?? Reading.nextPart(story, pr)))
        pr.ep = k0
        io.setProg(pr)
        let thePart = story.parts[k0]
        var at = pr.pos[k0]
        var thePath: [String]? = nil
        var all: [ChatMsg]
        if let nodes = thePart.nodes, let start = thePart.start, nodes[start] != nil {
            // interactive: the chat is the path chosen through the nodes; it is saved with the progress
            var p = [start]
            if at > 0, let saved = pr.path { p = saved }
            // a saved path from an older version of the story (branches renamed or removed): start fresh
            if !ChatReader.valid(p, thePart) { p = [start]; at = 0 }
            thePath = p
            all = ChatReader.flatten(p, thePart)
            at = min(at, all.count)
        } else {
            all = thePart.messages.map { ChatMsg(message: $0) }
        }
        ep = k0
        part = thePart
        path = thePath
        messages = all
        i = at
    }

    static func valid(_ path: [String], _ part: Part) -> Bool {
        guard let nodes = part.nodes, path.first == part.start else { return false }
        for (k, n) in path.enumerated() {
            guard nodes[n] != nil else { return false }
            if k > 0, !(nodes[path[k - 1]]?.choices ?? []).contains(where: { $0.next == n }) { return false }
        }
        return true
    }

    /// the conversation along a path: each node's messages, with the answer that led to it before them
    static func flatten(_ path: [String], _ part: Part) -> [ChatMsg] {
        guard let nodes = part.nodes else { return [] }
        var seq: [ChatMsg] = []
        for (k, n) in path.enumerated() {
            if k > 0, let c = nodes[path[k - 1]]?.choices?.first(where: { $0.next == n }) {
                seq.append(ChatMsg(message: Message(from: part.right, text: c.text, voice: nil, video: nil, dur: nil), answer: true))
            }
            seq += (nodes[n]?.messages ?? []).map { ChatMsg(message: $0) }
        }
        return seq
    }

    /// the node the path stands on
    var node: Node? { path.flatMap { $0.last }.flatMap { part.nodes?[$0] } }
    var premium: Bool { io.premium() }
    var outOfTaps: Bool { !io.premium() && io.taps() <= 0 }

    /// What the bottom panel holds now (controlsNow()).
    var foot: Foot {
        if let node, let choices = node.choices, i >= messages.count {
            return outOfTaps ? .paywall : .ask(choices)             // no taps left: the paywall, not answers that cannot be picked
        }
        if i >= messages.count {
            let ids = part.endingIDs
            let here = path?.last
            let which = here.flatMap { ids.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            return .end(End(last: ep + 1 >= story.parts.count, interactive: path != nil, which: which, of: ids.count,
                            name: node?.ending ?? "", turns: max(0, (path?.count ?? 1) - 1)))
        }
        return outOfTaps ? .paywall : .tap
    }

    /// one free tap is spent per message shown, silently
    private func spendTap() -> Bool {
        if io.premium() { return true }
        let left = io.taps()
        if left <= 0 { return false }
        io.setTaps(left - 1)
        return true
    }

    /// A tap to read on (step()). `.mine`: the reader's own message is there at once, read and saved.
    /// `.theirs`: the other side starts typing or recording; call `arrived()` when the message has come.
    /// `free`: the reply that comes by itself after an answer.
    func begin(free: Bool = false) -> Step {
        guard i < messages.count, !leaving else { return .none }
        if !free && !spendTap() { return .paywall }
        paid = !free && !io.premium()
        let m = messages[i]
        if m.from == part.right { paid = false; i += 1; save(); return .mine(m) }
        return .theirs(m)
    }

    func arrived() {
        guard !leaving, i < messages.count else { return }
        paid = false
        i += 1
        save()
    }

    /// Leaving, or dropping the message under way: a tap paid for it comes back.
    func stop() {
        if paid { paid = false; io.setTaps(io.taps() + 1) }
    }

    func save() {
        var p = io.prog()
        p.ep = ep
        p.pos[ep] = i
        if let path {
            p.path = path
            // an ending reached = read
            if i >= messages.count, !(node?.ending ?? "").isEmpty { p.pos[ep] = max(i, part.messages.count) }
        }
        io.setProg(p)
    }

    /// An answer is picked: it is sent as the reader's own message (the pick is the tap). Out of taps: nothing changes.
    func pick(_ k: Int) -> Step {
        guard !leaving, let choices = node?.choices, i >= messages.count, choices.indices.contains(k), path != nil else { return .none }
        if outOfTaps { return .paywall }
        path!.append(choices[k].next)
        messages = Self.flatten(path!, part)
        return begin()
    }

    /// after the reader's own answer the other side answers by itself (1 s on, free)
    var replyComesByItself: Bool { i < messages.count && messages[i].from != part.right }
    /// opened just after the reader's own answer (left before the reply came): the reply still comes by itself
    var owesReply: Bool { path != nil && i > 0 && i < messages.count && messages[i - 1].answer && messages[i].from != part.right }

    /// "Read again" / "Start over": the part to open. The end of the last part with every part read: the whole story
    /// again; else this part only.
    func again() -> Int {
        var p = io.prog()
        let last = ep + 1 >= story.parts.count
        let whole = last && p.pos.enumerated().allSatisfy { k, n in k == ep || n >= story.parts[k].messages.count }
        if whole { p.pos = p.pos.map { _ in 0 }; p.ep = 0 } else { p.pos[ep] = 0 }
        p.path = nil                                               // interactive: choose again
        io.setProg(p)
        return whole ? 0 : ep
    }

    /// "Back to a choice" number k (0 = the first one made): the chat opens again standing at that choice.
    func backToChoice(_ k: Int) {
        guard let path, k >= 0, k < path.count - 1 else { return }
        let upto = Array(path.prefix(k + 1))
        var p = io.prog()
        p.ep = ep
        p.pos[ep] = Self.flatten(upto, part).count
        p.path = upto
        io.setProg(p)
    }

    // MARK: - wallpaper

    /// the endings still within reach from a node of an interactive part
    static func endingsFrom(_ nodes: [String: Node], _ id: String, _ seen: inout Set<String>) -> Set<String> {
        var out = Set<String>()
        guard let n = nodes[id], !seen.contains(id) else { return out }
        seen.insert(id)
        if !(n.ending ?? "").isEmpty { out.insert(id) }
        for c in n.choices ?? [] { out.formUnion(endingsFrom(nodes, c.next, &seen)) }
        return out
    }

    /// the doodle groups to show: the whole story's ("*") and those of the endings still in reach; nil = all
    var inReach: Set<String>? {
        guard let path, let last = path.last, let nodes = part.nodes, part.wallpaperEndings != nil else { return nil }
        var seen = Set<String>()
        return Self.endingsFrom(nodes, last, &seen).union(["*"])
    }
}

extension ChatReader.IO {
    /// progress and taps straight in a Store (the unit tests; the app goes through AppModel so its screens redraw)
    static func store(_ store: Store, _ story: Story, liveEp: @escaping () -> Int?) -> ChatReader.IO {
        ChatReader.IO(
            prog: { Reading.prog(story, raw: store.progressRaw(story.id), liveEp: liveEp()) },
            setProg: { store.set("p:" + story.id, $0.saved(v: story.v)) },
            premium: { store.premium },
            taps: { store.taps },
            setTaps: { store.set("taps", $0) })
    }
}
