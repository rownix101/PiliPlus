import Flutter
import AVFoundation

public class NativePlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var registrar: FlutterPluginRegistrar?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var textureEntry: FlutterTextureEntry?
    private var displayLink: CADisplayLink?
    private var eventSink: FlutterEventSink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var pixelBufferRef: CVPixelBuffer?
    private var timeObserverToken: Any?
    
    // KVO observation
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var errorObservation: NSKeyValueObservation?
    private var itemErrorObservation: NSKeyValueObservation?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativePlayerPlugin()
        instance.registrar = registrar
        
        let methodChannel = FlutterMethodChannel(
            name: "com.pilipro/native_player",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        let eventChannel = FlutterEventChannel(
            name: "com.pilipro/native_player/events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - FlutterPlugin
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        switch call.method {
        case "create":
            let videoUrl = args?["videoUrl"] as! String
            let audioUrl = args?["audioUrl"] as? String
            let headers = args?["headers"] as? [String: String]
            let textureId = createPlayer(videoUrl: videoUrl, audioUrl: audioUrl, headers: headers)
            result(textureId)
            
        case "play":
            player?.play()
            result(nil)
            
        case "pause":
            player?.pause()
            result(nil)
            
        case "seekTo":
            let position = args?["position"] as! Int
            let time = CMTime(value: Int64(position), timescale: 1000)
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            result(nil)
            
        case "setPlaybackSpeed":
            let speed = args?["speed"] as! Double
            player?.rate = Float(speed)
            result(nil)
            
        case "setVolume":
            let volume = args?["volume"] as! Double
            player?.volume = Float(volume)
            result(nil)
            
        case "setLooping":
            // Looping is handled via notification observation
            result(nil)
            
        case "setVideoTrackEnabled":
            let enabled = args?["enabled"] as! Bool
            setVideoTrackEnabled(enabled)
            result(nil)
            
        case "dispose":
            disposePlayer()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Player Creation
    
    private func createPlayer(videoUrl: String, audioUrl: String?, headers: [String: String]?) -> Int64 {
        disposePlayer()
        
        // Configure audio session for playback (sound even with silent switch)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("NativePlayerPlugin: Audio session error: \(error)")
        }
        
        // Create asset with headers
        var options: [String: Any] = [:]
        if let headers = headers, !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        
        let videoAsset = AVURLAsset(url: URL(string: videoUrl)!, options: options)
        
        let item: AVPlayerItem
        
        if let audioUrl = audioUrl, !audioUrl.isEmpty {
            // Merge video + audio using AVMutableComposition
            let audioAsset = AVURLAsset(url: URL(string: audioUrl)!, options: options)
            let composition = AVMutableComposition()
            
            // Add video track
            if let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                videoAsset.loadTracks(withMediaType: .video) { tracks, error in
                    if let sourceTrack = tracks?.first {
                        try? videoTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: videoAsset.duration),
                            of: sourceTrack,
                            at: .zero
                        )
                    }
                }
            }
            
            // Add audio track
            if let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                audioAsset.loadTracks(withMediaType: .audio) { tracks, error in
                    if let sourceTrack = tracks?.first {
                        try? audioTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: audioAsset.duration),
                            of: sourceTrack,
                            at: .zero
                        )
                    }
                }
            }
            
            item = AVPlayerItem(asset: composition)
        } else {
            item = AVPlayerItem(asset: videoAsset)
        }
        
        // Buffer config
        item.preferredForwardBufferDuration = 50
        
        playerItem = item
        player = AVPlayer(playerItem: item)
        
        // Create texture entry for Flutter
        guard let textureRegistry = registrar?.textures() else { return -1 }
        textureEntry = textureRegistry.register(self)
        
        // Video output for pixel buffer
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        item.add(videoOutput!)
        
        // Setup observations
        setupObservations()
        
        // Start display link for rendering
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        
        // Periodic time observer for position updates
        let interval = CMTime(value: 1, timescale: 5) // 200ms
        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.sendPositionUpdate()
        }
        
        // End of playback notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndOfTime,
            object: item
        )
        
        return textureEntry?.textureId ?? -1
    }
    
    private func setupObservations() {
        // Player status
        statusObservation = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.sendEvent([
                        "type": "playbackState",
                        "state": "ready"
                    ])
                    // Send video size
                    if let track = item.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
                       let size = track.assetTrack?.naturalSize {
                        self?.sendEvent([
                            "type": "videoSize",
                            "width": Int(size.width),
                            "height": Int(size.height)
                        ])
                    }
                case .failed:
                    let errorMsg = item.error?.localizedDescription ?? "Unknown playback error"
                    self?.sendEvent([
                        "type": "error",
                        "error": errorMsg
                    ])
                default:
                    break
                }
            }
        }
        
        // Time control status (playing/paused/waiting)
        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                switch player.timeControlStatus {
                case .playing:
                    self?.sendEvent(["type": "isPlaying", "value": true])
                    self?.sendEvent(["type": "playbackState", "state": "ready"])
                case .paused:
                    self?.sendEvent(["type": "isPlaying", "value": false])
                case .waitingToPlayAtSpecifiedRate:
                    self?.sendEvent(["type": "playbackState", "state": "buffering"])
                @unknown default:
                    break
                }
            }
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        sendEvent([
            "type": "playbackState",
            "state": "ended"
        ])
        sendEvent(["type": "isPlaying", "value": false])
    }
    
    @objc private func displayLinkFired() {
        guard let output = videoOutput,
              let textureEntry = textureEntry else { return }
        
        let currentTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: currentTime) {
            pixelBufferRef = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil)
            textureEntry.textureFrameAvailable()
        }
    }
    
    private func sendPositionUpdate() {
        guard let p = player, let item = playerItem else { return }
        let position = CMTimeGetSeconds(p.currentTime())
        let duration = CMTimeGetSeconds(item.duration)
        
        // Calculate buffered position
        var buffered: Double = 0
        if let range = item.loadedTimeRanges.last {
            let r = range.timeRangeValue
            buffered = CMTimeGetSeconds(r.start) + CMTimeGetSeconds(r.duration)
        }
        
        if position.isNaN || duration.isNaN { return }
        
        sendEvent([
            "type": "position",
            "position": Int(position * 1000),
            "duration": Int(max(duration, 0) * 1000),
            "buffered": Int(max(buffered, 0) * 1000)
        ])
    }
    
    private func sendEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
    
    private func setVideoTrackEnabled(_ enabled: Bool) {
        guard let item = playerItem else { return }
        for track in item.tracks {
            if track.assetTrack?.mediaType == .video {
                track.isEnabled = enabled
            }
        }
    }
    
    private func disposePlayer() {
        displayLink?.invalidate()
        displayLink = nil
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        errorObservation?.invalidate()
        errorObservation = nil
        itemErrorObservation?.invalidate()
        itemErrorObservation = nil
        
        if let output = videoOutput, let item = playerItem {
            item.remove(output)
        }
        videoOutput = nil
        
        player?.pause()
        player = nil
        playerItem = nil
        pixelBufferRef = nil
        
        textureEntry?.deregister()
        textureEntry = nil
    }
}

// MARK: - FlutterTexture

extension NativePlayerPlugin: FlutterTexture {
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBufferRef else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}
