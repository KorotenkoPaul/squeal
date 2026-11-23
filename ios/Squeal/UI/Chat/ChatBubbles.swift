import SwiftUI

/// A message bubble's outline: 18 pt corners, the pointed one (5 pt) at the bottom on the sender's side.
func bubbleShape(mine: Bool, pointed: Bool = true) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: !mine && pointed ? 5 : 18,
                           bottomTrailingRadius: mine && pointed ? 5 : 18, topTrailingRadius: 18, style: .circular)
}

/// The part's description at the top of the chat (.intro): small, centred, at most 34 characters wide.
struct IntroText: View {
    let text: String
    private static let font = AppFont.uiFont(13)
    private static let width: CGFloat = ceil(("0" as NSString).size(withAttributes: [.font: font]).width * 34)
    var body: some View {
        Text(text)
            .cssText(Self.font, lineHeight: 13 * 1.5)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: Self.width)
            .padding(.bottom, 10)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A message: text, a voice message, or a round video message.
struct MessageBubble: View {
    let msg: ChatMsg
    let mine: Bool
    let maxWidth: CGFloat
    /// how much of what is inside shows (it fades in while "typing…" stretches into the message)
    let inside: Double
    let chat: ChatController

    var body: some View {
        if let video = msg.video {
            VideoCircle(file: video, dur: msg.dur ?? 0, label: msg.text, chat: chat)
                .opacity(inside)
        } else if let voice = msg.voice {
            // as wide as its caption on one line: never narrower than 230 pt of content (.msg.voice { min-width }),
            // never wider than any bubble (78 %); the waveform takes the room there is
            VoiceBubble(file: voice, dur: msg.dur ?? 0, text: msg.text, chat: chat)
                .opacity(inside)
                .frame(width: VoiceBubble.contentWidth(msg.text, maxBubble: maxWidth), alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(bubbleShape(mine: mine).fill(mine ? Theme.me : Theme.them))
        } else {
            Text(msg.text)
                .cssText(ChatMetrics.bubbleFont, lineHeight: ChatMetrics.lineHeight)
                .foregroundStyle(Color.white.opacity(inside))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(bubbleShape(mine: mine).fill(mine ? Theme.me : Theme.them))
                .accessibilityIdentifier(mine ? "msg-me" : "msg-them")
        }
    }
}

/// "typing…" (three dots) or recording (a microphone or a record sign, and a running timer): exactly as tall as a
/// one-line message, by construction — an invisible line of the message's own text stands in it.
struct TypingBubble: View {
    let kind: Row.Typing
    let sec: Int
    let sending: Bool

    var body: some View {
        HStack(spacing: kind == .text ? 4 : 8) {
            Text("\u{200b}").cssText(ChatMetrics.bubbleFont, lineHeight: ChatMetrics.lineHeight).frame(width: 0)
                .padding(.trailing, kind == .text ? -4 : -8)
            switch kind {
            case .text:
                ForEach(0..<3, id: \.self) { k in Blink(period: 1, delay: 0.15 * Double(k)) { Circle().fill(Theme.muted).frame(width: 7, height: 7) } }
            case .voice, .video:
                Blink(period: 1.2, delay: 0, still: sending, calm: 1) {
                    RecIcon(video: kind == .video).frame(width: 18, height: 18).foregroundStyle(sending ? Theme.muted : Theme.red)
                }
                Text("0:" + (sec < 10 ? "0" : "") + String(sec))
                    .font(AppFont.ui(14)).monospacedDigit().foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(bubbleShape(mine: false).fill(Theme.them))
        .fixedSize()
        .accessibilityHidden(true)
    }
}

/// CSS `blink`: opacity .25 → 1 → .25, each half eased, for ever. With Reduce Motion it stands still at 70 %.
struct Blink<Content: View>: View {
    let period: Double
    let delay: Double
    var still = false
    /// how it stands with Reduce Motion: the dots at 70 %, the recording sign plainly there (as the web)
    var calm = 0.7
    @ViewBuilder let content: () -> Content
    @State private var born = Date()

    var body: some View {
        if still { content() }
        else if reduceMotion() { content().opacity(calm) }
        else {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(born) - delay
                content().opacity(Self.value(t, period))
            }
        }
    }

    static func value(_ t: Double, _ period: Double) -> Double {
        if t < 0 { return 0.25 }
        let q = (t / period).truncatingRemainder(dividingBy: 1)
        return keyframes(q, [(0, 0.25), (0.5, 1), (1, 0.25)], ease: .ease)
    }
}

/// the recording sign: a microphone (voice) or a dot in a ring (video)
struct RecIcon: View {
    let video: Bool
    var body: some View {
        ZStack {
            if video {
                SVGShape(d: "M17 12a5 5 0 1 1-10 0a5 5 0 1 1 10 0z")
                SVGShape(d: "M21 12a9 9 0 1 1-18 0a9 9 0 1 1 18 0z").stroke(style: StrokeStyle(lineWidth: 1.8 * 18 / 24))
            } else {
                SVGShape(d: "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z")
                SVGShape(d: "M6 11a6 6 0 0 0 12 0M12 17v4M9 21h6").stroke(style: StrokeStyle(lineWidth: 1.8 * 18 / 24, lineCap: .round))
            }
        }
    }
}

/// The end of a part: the story's title (and the part), and for an interactive one "Ending 2 of 3 · its name".
struct EndTitle: View {
    let title: String
    let sub: String?
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(AppFont.ui(13)).foregroundStyle(Theme.muted)
            if let sub { Text(sub).font(AppFont.ui(13)).foregroundStyle(Theme.muted).padding(.top, 2) }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 16).padding(.horizontal, 8).padding(.bottom, 4)
        .fixedSize(horizontal: false, vertical: true)
        // one element with its own label (a combined one went missing from the accessibility tree on iOS 26)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sub.map { title + ", " + $0 } ?? title)
        .accessibilityIdentifier("chat-end")
    }
}

/// A voice message: play / pause, a waveform (fixed for each clip), the length; what is said is written small
/// underneath, for reading without sound. One clip plays at a time.
struct VoiceBubble: View {
    let file: String
    let dur: Int
    let text: String
    let chat: ChatController
    @StateObject private var clip = VoiceClip()

    /// the waveform: 30 bars, 4…18 pt tall, from the clip's own name (the same as the web draws)
    static func bars(_ file: String) -> [CGFloat] {
        var x: UInt32 = 3
        for c in file.utf16 { x = x &* 31 &+ UInt32(c) }
        return (0..<30).map { k in
            x = x &* 1664525 &+ 1013904223
            let r = Double(x) / 4294967296
            return CGFloat(4 + Reading.jsRound(r * 14 * (0.45 + 0.55 * sin(Double.pi * Double(k + 1) / 31))))
        }
    }

    static func time(_ t: Int) -> String { String(t / 60) + ":" + (t % 60 < 10 ? "0" : "") + String(t % 60) }

    static let captionFont = UIFont(name: "AvenirNext-Italic", size: 13) ?? AppFont.uiFont(13)
    /// the width of what is inside the bubble (its 14 pt padding each side not counted)
    static func contentWidth(_ caption: String, maxBubble: CGFloat) -> CGFloat {
        let oneLine = ceil((caption as NSString).size(withAttributes: [.font: captionFont]).width)
        return max(120, min(maxBubble - 28, max(230, oneLine)))
    }

    var body: some View {
        let bars = Self.bars(file)
        let lit = Int(Reading.jsRound(clip.fraction * Double(bars.count)))
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button { } label: {
                    Circle().fill(Color.white.opacity(0.14)).frame(width: 34, height: 34)
                        .overlay(
                            SVGShape(d: clip.playing ? "M7 5h3.5v14H7zM13.5 5H17v14h-3.5z" : "M8 5.5v13l11-6.5z")
                                .fill(Color.white).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .spotTap(chat, "voice:" + file) { clip.toggle(file: file, media: chat.media) }
                .accessibilityLabel(chat.model.tr(clip.playing ? "a11yPause" : "a11yPlayVoice"))
                HStack(spacing: 2) {
                    ForEach(bars.indices, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(k < lit ? 1 : 0.35))
                            .frame(minWidth: 2, maxWidth: .infinity).frame(height: bars[k])
                    }
                }
                .frame(height: 22)
                .animation(.easeInOut(duration: 0.15), value: lit)
                Text(Self.time(clip.started ? min(dur > 0 ? dur : 99, Int(Reading.jsRound(clip.time))) : dur))
                    .font(AppFont.ui(12)).monospacedDigit().foregroundStyle(Color.white.opacity(0.7))
                    .frame(minWidth: 12 * 2.4, alignment: .trailing)
            }
            Text(text)
                .font(Font(Self.captionFont))
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear { clip.stop() }
    }
}

/// A round video message: it plays silently on a loop as a preview; a tap plays it from the start with sound, a ring
/// round the edge showing how far it has played; a second tap stops. What it shows is said to VoiceOver only.
struct VideoCircle: View {
    let file: String
    let dur: Int
    let label: String
    let chat: ChatController
    @StateObject private var clip = VideoClip()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            PlayerSurface(player: clip.player)
            Circle().inset(by: 210 * 1.5 / 100)
                .trim(from: 0, to: clip.playing ? clip.fraction : 0)
                .stroke(Color.white, lineWidth: 210 * 2.4 / 100)
                .rotationEffect(.degrees(-90))
                .opacity(clip.playing ? 0.9 : 0)
                .animation(.linear(duration: 0.2), value: clip.playing)
            Text("0:" + Self.two(clip.playing ? min(dur > 0 ? dur : 99, Int(Reading.jsRound(clip.time))) : dur))
                .font(AppFont.ui(12)).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .padding(.bottom, 12)
        }
        .frame(width: 210, height: 210)
        .clipShape(Circle())
        .contentShape(Circle())
        .onTapGesture { clip.toggle(media: chat.media) }
        .onAppear { clip.load(file) }
        .onDisappear { clip.close() }
        .accessibilityElement()
        .accessibilityLabel(chat.model.tr("a11yVideo") + ": " + label)
        .accessibilityAddTraits(.isButton)
    }

    static func two(_ n: Int) -> String { (n < 10 ? "0" : "") + String(n) }
}
