// AudioEngine.swift
// Native AVPlayer background audio engine with lock screen controls

import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioEngine: NSObject, ObservableObject {
    static let shared = AudioEngine()

    @Published var isPlaying = false
    @Published var isConnecting = false
    @Published var currentTrack = "Greyman Live Voice Stream"
    @Published var volume: Float = 1.0
    @Published var outputRoute = "Speaker"

    private var player: AVPlayer?
    private var timeObserver: Any?

    let streamURLs = [
        "https://whenever-mods-homework-logan.trycloudflare.com/radio.mp3",
        "http://192.168.1.38:8090/radio.mp3"
    ]

    override init() {
        super.init()
        setupRemoteControls()
        setupRouteChangeObserver()
    }

    func play(urlIndex: Int = 0) {
        guard urlIndex < streamURLs.count else { return }
        isConnecting = true
        let url = URL(string: streamURLs[urlIndex])!
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.volume = volume
        player?.play()
        isPlaying = true
        isConnecting = false
        updateNowPlaying()

        // Fallback to next URL on failure
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if urlIndex + 1 < self.streamURLs.count { self.play(urlIndex: urlIndex + 1) }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func toggle() { isPlaying ? pause() : (player == nil ? play() : resume()) }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    func routeToSpeaker() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        outputRoute = "Speaker"
    }

    func routeToEarpiece() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        outputRoute = "Earpiece"
    }

    private func updateNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = "Greyman Executive Live Speech"
        info[MPMediaItemPropertyArtist] = "Greyman AI • Boss Command Center"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    private func setupRemoteControls() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        cc.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        cc.stopCommand.addTarget { [weak self] _ in self?.pause(); return .success }
    }

    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
        if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause() }
        let route = AVAudioSession.sharedInstance().currentRoute
        outputRoute = route.outputs.first?.portName ?? "Unknown"
    }
}
