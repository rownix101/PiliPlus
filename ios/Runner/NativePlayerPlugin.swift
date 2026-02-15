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

    // Subtitle tracking
    private var currentVideoUrl: String?
    private var currentAudioUrl: String?
    private var currentHeaders: [String: String]?
    private var currentSubtitleTrack: String?
    private var subtitleAssets: [AVURLAsset] = []
    
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
            // Save current config for subtitle switching
            currentVideoUrl = videoUrl
            currentAudioUrl = audioUrl
            currentHeaders = headers
            currentSubtitleTrack = nil
            subtitleAssets.removeAll()
            let textureId = createPlayer(videoUrl: videoUrl, audioUrl: audioUrl, headers: headers)
            result(textureId)

        case "setSubtitleTrack":
            let id = args?["id"] as? String
            let title = args?["title"] as? String
            let language = args?["language"] as? String
            let uri = args?["uri"] as? Bool ?? false
            let data = args?["data"] as? Bool ?? false
            setSubtitleTrack(id: id, title: title, language: language, uri: uri, data: data)
            result(nil)
            
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
    
    private func setSubtitleTrack(id: String?, title: String?, language: String?, uri: Bool, data: Bool) {
        // Handle "no subtitle" selection
        guard let trackId = id, !trackId.isEmpty else {
            currentSubtitleTrack = nil
            subtitleAssets.removeAll()
            // Disable all text tracks
            if let currentItem = player?.currentItem {
                for track in currentItem.tracks where track.assetTrack?.mediaType == .text {
                    track.isEnabled = false
                }
            }
            return
        }

        currentSubtitleTrack = trackId

        // Clean up old temporary subtitle files
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "vtt" && file.lastPathComponent.starts(with: "subtitle_") {
                try? FileManager.default.removeItem(at: file)
            }
        }

        subtitleAssets.removeAll()

        // Handle URI-based subtitles (VTT URL)
        if uri && !data {
            let subtitleURL = URL(string: trackId)!
            let subtitleAsset = AVURLAsset(url: subtitleURL)
            subtitleAssets.append(subtitleAsset)
            rebuildPlayerWithSubtitles()
        } else if data {
            // Handle embedded VTT data
            // Create a temporary file with VTT content
            let tempDir = FileManager.default.temporaryDirectory
            let subtitleFileName = "subtitle_\(UUID().uuidString).vtt"
            let subtitleFileURL = tempDir.appendingPathComponent(subtitleFileName)

            do {
                try trackId.write(to: subtitleFileURL, atomically: true, encoding: .utf8)
                let subtitleAsset = AVURLAsset(url: subtitleFileURL)
                subtitleAssets.append(subtitleAsset)
                rebuildPlayerWithSubtitles()
            } catch {
                print("NativePlayerPlugin: Failed to write subtitle data: \(error)")
            }
        }
    }

    private func rebuildPlayerWithSubtitles() {
        guard let videoUrl = currentVideoUrl else { return }
        let audioUrl = currentAudioUrl
        let headers = currentHeaders

        // Remember current position and playing state
        let currentPosition = player?.currentTime() ?? .zero
        let wasPlaying = player?.timeControlStatus == .playing

        // Create video asset
        var options: [String: Any] = [:]
        if let headers = headers, !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }

        let videoAsset = AVURLAsset(url: URL(string: videoUrl)!, options: options)

        // Synchronously load video and audio tracks
        let semaphore = DispatchSemaphore(value: 0)
        var videoSourceTrack: AVAssetTrack?
        var audioSourceTrack: AVAssetTrack?
        var subtitleSourceTracks: [(AVAssetTrack, AVAsset)] = []

        videoAsset.loadTracks(withMediaType: .video) { tracks, error in
            videoSourceTrack = tracks?.first
            semaphore.signal()
        }
        semaphore.wait()

        if let audioUrl = audioUrl, !audioUrl.isEmpty {
            let audioAsset = AVURLAsset(url: URL(string: audioUrl)!, options: options)
            audioAsset.loadTracks(withMediaType: .audio) { tracks, error in
                audioSourceTrack = tracks?.first
                semaphore.signal()
            }
            semaphore.wait()
        }

        // Load subtitle tracks synchronously
        for subtitleAsset in subtitleAssets {
            subtitleAsset.loadTracks(withMediaType: .text) { tracks, error in
                if let track = tracks?.first {
                    subtitleSourceTracks.append((track, subtitleAsset))
                }
                semaphore.signal()
            }
            semaphore.wait()
        }

        // Create composition
        let composition = AVMutableComposition()

        // Get duration from video track
        let duration = videoSourceTrack?.timeRange.duration ?? .zero

        // Add video track
        if let sourceTrack = videoSourceTrack {
            if let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                do {
                    try videoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceTrack,
                        at: .zero
                    )
                } catch {
                    print("NativePlayerPlugin: Failed to insert video track: \(error)")
                }
            }
        }

        // Add audio track
        if let sourceTrack = audioSourceTrack {
            if let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                do {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceTrack,
                        at: .zero
                    )
                } catch {
                    print("NativePlayerPlugin: Failed to insert audio track: \(error)")
                }
            }
        }

        // Add subtitle tracks
        for (sourceTrack, subtitleAsset) in subtitleSourceTracks {
            if let compositionTrack = composition.addMutableTrack(
                withMediaType: .text,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                do {
                    try compositionTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceTrack,
                        at: .zero
                    )
                } catch {
                    print("NativePlayerPlugin: Failed to insert subtitle track: \(error)")
                }
            }
        }

        // Create new player item
        let newItem = AVPlayerItem(asset: composition)

        // Transfer video output
        if let output = videoOutput {
            playerItem?.remove(output)
            newItem.add(output)
        }

        // Replace current item
        player?.replaceCurrentItem(with: newItem)
        playerItem = newItem

        // Setup observations for new item
        setupObservations()

        // Restore position
        player?.seek(to: currentPosition, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            // Resume playing if it was playing before
            if wasPlaying {
                self.player?.play()
            }
        }

        // Select subtitle track
        if !subtitleAssets.isEmpty {
            newItem.tracks.forEach { track in
                if track.assetTrack?.mediaType == .text {
                    track.isEnabled = true
                }
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

        // Clean up subtitle temp files
        for subtitleAsset in subtitleAssets {
            if let url = subtitleAsset.url as? URL,
               url.pathExtension == "vtt",
               url.path.contains(FileManager.default.temporaryDirectory.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        subtitleAssets.removeAll()
    }
}

// MARK: - FlutterTexture

extension NativePlayerPlugin: FlutterTexture {
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBufferRef else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}
