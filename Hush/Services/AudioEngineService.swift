@preconcurrency import AVFoundation
import Foundation
import os

extension Notification.Name {
    /// Posted when ambient playback should pause due to interruption or routing changes.
    public static let hushAudioInterruption =
    Notification.Name("HushAudioInterruptionNotification")
    /// Posted after the AVAudioEngine graph is rebuilt so the mixer can reschedule sounds.
    public static let hushEngineNeedsResume = Notification.Name("HushEngineNeedsResumeNotification")
}

private enum HushAudioLog {
    nonisolated static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Hush", category: "AudioEngine")

    nonisolated static func formatSummary(_ format: AVAudioFormat?) -> String {
        guard let format else { return "(nil format)" }
        return "sr=\(format.sampleRate) ch=\(format.channelCount) common=\(String(describing: format.commonFormat)) interleaved=\(format.isInterleaved)"
    }
}

/// Mixes looping ambient pads with ``AVAudioEngine``.
///
/// Graph control runs on this **actor**, not ``MainActor``. Multiple ``AVAudioPlayerNode`` instances attach to
/// ``mainMixerNode`` on **distinct mixer input buses** (see
/// [Stack Overflow: multiple buffers + mixer](https://stackoverflow.com/questions/57343150/how-to-play-multiple-sounds-from-buffer-simultaneously-using-nodes-connected-to)).
///
/// ## Fix notes (vs original)
/// 1. **`engine.connect` uses `format: nil`** so AVAudioEngine inserts a sample-rate / channel-count
///    converter automatically. Without this, nodes whose buffers have a different format than the
///    hardware output (e.g. 24 kHz or 44.1 kHz mono into a 48 kHz stereo graph) render silence on macOS.
/// 2. **`scheduleBuffer` is called synchronously** (no `await`). The async overload introduces a
///    suspension point between `scheduleBuffer` and `player.play()`, creating a window where a
///    concurrent `stopSound` can reset the node, leaving it broken for all future reuse calls.
/// 3. **Reuse path checks `player.isPlaying`** and re-schedules if the node has silently died,
///    preventing permanent silence after any interruption.
public actor AudioEngineService {
    private let engine = AVAudioEngine()
    private var playerNodes: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var notificationTokens: [NSObjectProtocol] = []
    private var deferredStartAttempts = 0
    private var configurationObserverInstalled = false
    /// IDs whose looping buffer has been scheduled in the current engine session.
    private var stemLoopsScheduled = Set<String>()

    /// Whether rendering I/O has started successfully.
    public private(set) var isEngineRunning = false

    public init() {}

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// IDs whose assets decoded successfully into PCM (for UI mirroring without crossing the actor synchronously).
    public func loadedSoundIDs() -> Set<String> {
        Set(buffers.keys)
    }

    /// Preloads PCM buffers for every sound by decoding bundles off the caller's actor.
    public func preloadSounds(_ sounds: [Sound]) async {
        diag("preloadSounds begin count=\(sounds.count)")
        installConfigurationObserverIfNeeded()
        Self.activatePlaybackSessionIfAvailable()

        var provisional: [(String, AVAudioPCMBuffer?)] = []
        await withTaskGroup(of: (String, AVAudioPCMBuffer?).self) { group in
            for sound in sounds {
                group.addTask {
                    let buffer = await Self.decodeBuffer(for: sound)
                    return (sound.id, buffer)
                }
            }
            for await tuple in group {
                provisional.append(tuple)
            }
        }

        var decodedCount = 0
        var failedIDs: [String] = []
        for pair in provisional {
            if let buffer = pair.1 {
                buffers[pair.0] = buffer
                decodedCount += 1
                let bufFormat = buffer.format
                diag("decode OK id=\(pair.0) frames=\(buffer.frameLength) \(HushAudioLog.formatSummary(bufFormat))")
            } else {
                failedIDs.append(pair.0)
            }
        }
        if !failedIDs.isEmpty {
            diag("decode failed or missing bundle for ids=\(failedIDs.joined(separator: ","))")
        }
        diag("preloadSounds buffers ready decoded=\(decodedCount)/\(provisional.count)")

        rebuildGraph(for: sounds)
        startEngineIfNeeded()
        diag("preloadSounds end running=\(engine.isRunning)")
    }

    nonisolated private static func activatePlaybackSessionIfAvailable() {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            HushAudioLog.logger.notice("AVAudioSession playback active (iOS)")
        } catch {
            let ns = error as NSError
            HushAudioLog.logger.warning("AVAudioSession failed \(error.localizedDescription) code=\(ns.code)")
        }
#else
        HushAudioLog.logger.notice("activatePlaybackSession: macOS skips AVAudioSession (CoreAudio/graph only)")
#endif
    }

    nonisolated private static func decodeBuffer(for sound: Sound) async -> AVAudioPCMBuffer? {
        guard let url = bundledAudioURL(resourceBaseName: sound.resourceName, extension: "m4a") else {
            HushAudioLog.logger.error("bundle URL missing id=\(sound.id) resource=\(sound.resourceName)")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                HushAudioLog.logger.error("AVAudioPCMBuffer alloc failed id=\(sound.id)")
                return nil
            }
            try file.read(into: buffer)
            buffer.frameLength = AVAudioFrameCount(file.length)
            return buffer
        } catch {
            HushAudioLog.logger.error("decode exception id=\(sound.id) \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated private static func bundledAudioURL(resourceBaseName: String, extension ext: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: resourceBaseName, withExtension: ext, subdirectory: "Audio") {
            return url
        }
        return bundle.url(forResource: resourceBaseName, withExtension: ext)
    }

    public func rebuildGraph(for sounds: [Sound]) {
        diag("rebuildGraph begin sounds=\(sounds.count)")
        stopEngineSilently()
        engine.reset()

        for (_, node) in playerNodes {
            node.stop()
            engine.detach(node)
        }
        playerNodes.removeAll()
        stemLoopsScheduled.removeAll()

        let mixer = engine.mainMixerNode
        var mixerInputBus: AVAudioNodeBus = 0

        for sound in sounds {
            guard let buffer = buffers[sound.id] else {
                diag("rebuildGraph skip id=\(sound.id) (no buffer)")
                continue
            }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            // Connect with the buffer's own format so the player node's output channel count
            // matches what scheduleBuffer will deliver. AVAudioMixerNode up/down-mixes
            // automatically (e.g. mono→stereo), so different formats across stems are fine.
            engine.connect(player, to: mixer, fromBus: 0, toBus: mixerInputBus, format: buffer.format)
            diag("rebuildGraph connect id=\(sound.id) → mainMixer bus=\(mixerInputBus) \(HushAudioLog.formatSummary(buffer.format))")
            mixerInputBus += 1
            player.volume = 0
            playerNodes[sound.id] = player
        }

        engine.prepare()
        let outFmt = engine.outputNode.outputFormat(forBus: 0)
        let mixOut = mixer.outputFormat(forBus: 0)
        let playerCount = playerNodes.count
        diag(
            "rebuildGraph prepared playerCount=\(playerCount) outputNode=\(HushAudioLog.formatSummary(outFmt)) mainMixerOut=\(HushAudioLog.formatSummary(mixOut)) mainMixer.outputVolume=\(mixer.outputVolume)"
        )
    }

    /// Normalized master attenuation feeding the hardware mixer (`0 … 1`).
    public func setMasterVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        engine.mainMixerNode.outputVolume = clamped
        diag("setMasterVolume \(clamped)")
    }

    public func hasBuffer(for id: String) -> Bool {
        buffers[id] != nil
    }

    /// Starts (or adjusts the volume of) a looping ambient stem.
    ///
    /// First call per session: schedules the buffer synchronously (non-async overload), sets the
    /// target volume, then calls `play()` — audio is audible immediately.
    ///
    /// Subsequent calls while the loop is already running: directly sets `player.volume` to the
    /// new target so the slider change is reflected at once without any scheduling overhead.
    public func playSound(id: String, targetLinearVolume: Float) async {
        diag("playSound begin id=\(id) targetLinear=\(targetLinearVolume)")
        guard let player = playerNodes[id], let buffer = buffers[id] else {
            let keys = playerNodes.keys.sorted().joined(separator: ",")
            diag("playSound abort id=\(id) no player/buffer (players=[\(keys)])")
            return
        }
        await awaitEngineRunningForPlayback()
        guard engine.isRunning else {
            diag("playSound abort id=\(id) engine not running")
            return
        }

        let target = amplitude(fromNormalized: targetLinearVolume)

        if stemLoopsScheduled.contains(id) {
            // Already looping — just update gain directly; no scheduling needed.
            player.volume = target
            diag("playSound gain-only id=\(id) vol=\(target)")
            return
        }

        // Fresh start: schedule synchronously, set volume, play.
        diag("playSound schedule+play id=\(id) bufferFrames=\(buffer.frameLength) vol=\(target)")
        stemLoopsScheduled.insert(id)
        player.volume = target
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil) // async not works
        player.play()
        diag("playSound play() issued id=\(id) isPlaying=\(player.isPlaying) vol=\(player.volume) engineRunning=\(engine.isRunning)")
    }

    public func stopSound(id: String, fadeDuration: TimeInterval) async {
        guard let player = playerNodes[id] else {
            diag("stopSound no player id=\(id)")
            return
        }
        diag("stopSound id=\(id) fade=\(fadeDuration)")
        await rampVolume(player: player, to: 0, duration: fadeDuration)
        player.stop()
        player.reset()
        stemLoopsScheduled.remove(id)
    }

    public func fadeOutAll(stopAfter duration: TimeInterval) async {
        diag("fadeOutAll duration=\(duration)")
        let playingIDs = playerNodes.keys.filter { playerNodes[$0]?.isPlaying == true }
        await withTaskGroup(of: Void.self) { group in
            for id in playingIDs {
                group.addTask {
                    await self.stopSound(id: id, fadeDuration: duration)
                }
            }
        }
    }

    public func suspendAllPlayback() {
        diag("suspendAllPlayback")
        stemLoopsScheduled.removeAll()
        for (_, player) in playerNodes {
            player.volume = 0
            player.stop()
            player.reset()
        }
        stopEngineSilently()
    }

    public func resume(ids: [(id: String, normalizedVolume: Float)]) async {
        diag("resume count=\(ids.count)")
        for item in ids {
            await playSound(id: item.id, targetLinearVolume: item.normalizedVolume)
        }
    }
}

private extension AudioEngineService {
    /// Builds the message on the actor so `Logger` does not infer autoclosure captures over isolated state.
    func diag(_ message: String) {
        HushAudioLog.logger.notice("\(message, privacy: .public)")
    }

    func stopEngineSilently() {
        if engine.isRunning {
            diag("engine.stop()")
            engine.stop()
        }
        isEngineRunning = false
    }

    func amplitude(fromNormalized value: Float) -> Float {
        max(0, min(1, value))
    }

    func rampVolume(player: AVAudioPlayerNode, to target: Float, duration: TimeInterval) async {
        let start = player.volume
        let steps = max(1, Int(duration / 0.02))
        for step in 0 ... steps {
            let t = Float(step) / Float(steps)
            player.volume = start + (target - start) * t
            if step < steps {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
    }

    func startEngineIfNeeded() {
        if engine.isRunning {
            isEngineRunning = true
            deferredStartAttempts = 0
            diag("startEngineIfNeeded already running")
            return
        }

        engine.prepare()
        if tryStartOnce(label: "first") {
            deferredStartAttempts = 0
            return
        }
        engine.prepare()
        if tryStartOnce(label: "second") {
            deferredStartAttempts = 0
        } else {
            let scheduledFor = deferredStartAttempts + 1
            diag("startEngineIfNeeded failed twice — scheduling defer attempt \(scheduledFor)")
            deferOutputStartRetry()
        }
    }

    func awaitEngineRunningForPlayback(maxAttempts: Int = 100) async {
        if engine.isRunning {
            return
        }
        for attempt in 0 ..< maxAttempts {
            startEngineIfNeeded()
            if engine.isRunning {
                diag("awaitEngineRunning success attempt=\(attempt)")
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        let exhaustedRunning = engine.isRunning
        diag("awaitEngineRunning exhausted attempts=\(maxAttempts) running=\(exhaustedRunning)")
    }

    func deferOutputStartRetry() {
        guard deferredStartAttempts < 40 else {
            let dit = deferredStartAttempts
            diag("deferOutputStartRetry giving up after \(dit) attempts")
            return
        }
        deferredStartAttempts += 1
        let attemptNow = deferredStartAttempts
        diag("deferOutputStartRetry schedule attempt \(attemptNow)")
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await self.performDeferredStartAttempt()
        }
    }

    func performDeferredStartAttempt() async {
        diag("performDeferredStartAttempt")
        startEngineIfNeeded()
    }

    func tryStartOnce(label: String) -> Bool {
        do {
            try engine.start()
            isEngineRunning = true
            let out = engine.outputNode.outputFormat(forBus: 0)
            diag("engine.start() OK [\(label)] outputFormat=\(HushAudioLog.formatSummary(out))")
            return true
        } catch {
            let ns = error as NSError
            diag(
                "engine.start() FAILED [\(label)] \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code)"
            )
            isEngineRunning = false
            return false
        }
    }

    func installConfigurationObserverIfNeeded() {
        guard configurationObserverInstalled == false else { return }
        configurationObserverInstalled = true
        diag("install AVAudioEngineConfigurationChange observer")
        let engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { _ in
            Task {
                await self.routeChangeRebuildAndNotify()
            }
        }
        notificationTokens.append(engineObserver)
    }

    func routeChangeRebuildAndNotify() {
        diag("AVAudioEngineConfigurationChange — rebuild + notify resume")
        suspendAllPlayback()
        rebuildGraph(for: Sound.library)
        NotificationCenter.default.post(name: .hushEngineNeedsResume, object: nil)
    }
}
