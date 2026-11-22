import SwiftUI
import AVFoundation
import UIKit

/// Sound in a chat: one clip (a voice message or a video with sound) plays at a time; everything stops when the chat
/// is left, a part is switched, or the app goes to the background. Media files sit in the app as the web has them:
/// "voice/<name>.mp3", "video/<name>.mp4" (folders `voice` and `video` in the bundle). A clip whose file is not there
/// yet shows as usual and simply does not play.
final class ChatMedia {
    private var stopPlaying: (() -> Void)? = nil
    private var token: NSObjectProtocol? = nil

    init() {
        token = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopAll()
        }
    }
    deinit { if let token { NotificationCenter.default.removeObserver(token) } }

    static func url(_ file: String) -> URL? {
        guard let root = Bundle.main.resourceURL else { return nil }
        let u = root.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// a clip starts with sound: whatever was playing stops
    func began(_ stop: @escaping () -> Void) {
        let old = stopPlaying
        stopPlaying = nil
        old?()
        stopPlaying = stop
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// the clip that was playing has ended or was stopped by its own button
    func ended() {
        stopPlaying = nil
        Self.quiet()
    }

    func stopAll() {
        let old = stopPlaying
        stopPlaying = nil
        old?()
        Self.quiet()
    }

    /// silent previews never interrupt the reader's own music
    static func quiet() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
}

/// One voice message's player (template.html voiceBubble).
final class VoiceClip: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playing = false
    /// how far it has played, 0…1 (the waveform's lit bars) and in seconds
    @Published private(set) var fraction = 0.0
    @Published private(set) var time = 0.0
    /// playing, or paused half way: the time reached is shown instead of the length
    var started: Bool { playing || time > 0 }

    private var audio: AVAudioPlayer? = nil
    private var timer: Timer? = nil
    private weak var media: ChatMedia? = nil

    func toggle(file: String, media: ChatMedia) {
        self.media = media
        if audio == nil, let url = ChatMedia.url(file) {
            audio = try? AVAudioPlayer(contentsOf: url)
            audio?.delegate = self
        }
        guard let audio else { return }                       // no file yet: nothing plays
        if audio.isPlaying { audio.pause(); playing = false; paint(); stopTimer(); media.ended(); return }
        media.began { [weak self] in self?.stop() }
        playing = true
        paint()                                               // the time shows at once
        if !audio.play() { playing = false; paint(); media.ended(); return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.paint() }
    }

    /// stopped from outside (another clip, leaving the chat): back to the start
    func stop() {
        guard let audio else { return }
        audio.pause(); audio.currentTime = 0
        playing = false
        stopTimer(); paint()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing = false
        player.currentTime = 0
        stopTimer(); paint()
        media?.ended()
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func paint() {
        guard let audio else { return }
        if playing && !audio.isPlaying && audio.currentTime > 0 { playing = false; stopTimer() }   // paused by the phone (a call)
        time = audio.currentTime
        fraction = audio.duration > 0 ? audio.currentTime / audio.duration : 0
    }
}

/// One round video message's player (template.html videoCircle).
final class VideoClip: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var playing = false               // with sound, from the start
    @Published private(set) var fraction = 0.0
    @Published private(set) var time = 0.0
    private var endToken: NSObjectProtocol? = nil
    private var timeToken: Any? = nil
    private weak var media: ChatMedia? = nil
    private var loaded = false

    func load(_ file: String) {
        guard !loaded else { preview(); return }
        loaded = true
        guard let url = ChatMedia.url(file) else { return }   // no file yet: a black circle with its length
        ChatMedia.quiet()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        endToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.playing { self.stop(); self.media?.ended() } else { self.player.seek(to: .zero); self.player.play() }
        }
        timeToken = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { [weak self] t in
            guard let self, self.playing else { return }
            let d = self.player.currentItem?.duration.seconds ?? 0
            self.time = t.seconds
            self.fraction = d.isFinite && d > 0 ? max(0, min(1, t.seconds / d)) : 0
            if t.seconds > 0.3, self.player.timeControlStatus == .paused { self.stop(); self.media?.ended() }   // paused by the phone: back to the silent loop
        }
        preview()
    }

    private func preview() {
        player.isMuted = true
        player.play()
    }

    func toggle(media: ChatMedia) {
        self.media = media
        guard player.currentItem != nil else { return }
        if playing { stop(); media.ended(); return }
        media.began { [weak self] in self?.stop() }
        playing = true; fraction = 0; time = 0
        player.seek(to: .zero)
        player.isMuted = false
        player.play()
    }

    /// back to the silent loop
    func stop() {
        guard playing else { return }
        playing = false; fraction = 0; time = 0
        preview()
    }

    func close() {
        if playing { stop(); media?.ended() }
        player.pause()
    }

    deinit {
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let timeToken { player.removeTimeObserver(timeToken) }
    }
}

/// The video itself, filling its frame (object-fit: cover).
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> Surface {
        let v = Surface()
        v.isUserInteractionEnabled = false
        v.playerLayer?.player = player
        v.playerLayer?.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: Surface, context: Context) { if v.playerLayer?.player !== player { v.playerLayer?.player = player } }

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }
}
