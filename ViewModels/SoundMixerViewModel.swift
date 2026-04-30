import Foundation
import Observation
import ServiceManagement
import UserNotifications

extension Notification.Name {
    /// Posted after ``SoundMixerViewModel/resetToFactoryDefaults()`` so SwiftUI reloads `AppStorage`.
    public static let hushReloadStoredChrome = Notification.Name("Hush.reloadStoredChrome")
}

/// Preset durations for automatic shutoff scheduling.
public enum SleepTimerPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case disabled
    case minutes15
    case minutes30
    case minutes45
    case minutes60
    case custom

    public var id: String { rawValue }

    /// Human-readable label for segmented controls or menus.
    public var menuTitle: String {
        switch self {
        case .disabled: return "Off"
        case .minutes15: return "15 min"
        case .minutes30: return "30 min"
        case .minutes45: return "45 min"
        case .minutes60: return "60 min"
        case .custom: return "Custom"
        }
    }

    public var durationSeconds: TimeInterval? {
        switch self {
        case .disabled: return nil
        case .minutes15: return 900
        case .minutes30: return 1_800
        case .minutes45: return 2_700
        case .minutes60: return 3_600
        case .custom: return nil
        }
    }
}

/// Persisted knob state for each ambient stem.
public struct SoundTrackRuntime: Codable, Hashable, Sendable {
    /// Whether the backing node should audition after launch.
    public var isEnabled: Bool
    /// Normalized amplitude (0 ... 1) before master attenuation is applied.
    public var normalizedVolume: Double

    public init(isEnabled: Bool, normalizedVolume: Double = 0.5) {
        self.isEnabled = isEnabled
        self.normalizedVolume = normalizedVolume
    }
}

/// Central coordinator for UI state, persistence, audio routing, and timing.
@Observable
@MainActor
public final class SoundMixerViewModel {
    // MARK: – Non-UI state (excluded from observation to avoid spurious view updates)

    @ObservationIgnored private let audio: AudioEngineService
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var resumeObserver: NSObjectProtocol?

    // MARK: – Observable properties

    /// Master gain applied to the ambient bus (`0 ... 1`).
    public var masterVolume: Double {
        didSet {
            DefaultsKeys.storeMaster(masterVolume)
            Task { await audio.setMasterVolume(Float(masterVolume)) }
        }
    }

    /// Stem states keyed by `Sound.id`.
    public var tracks: [String: SoundTrackRuntime]

    /// `true` when any stem is auditioning loops.
    public private(set) var isGloballyPlaying = false

    /// Deadline for timer-driven shutdown (`nil` when timers are inactive).
    public var timerEndsAt: Date?

    /// Describes the UX preset powering the countdown.
    public var timerPreset: SleepTimerPreset {
        didSet { DefaultsKeys.storeTimerDefault(timerPreset) }
    }

    /// Persisted helper hours/minutes backing the `.custom` option (total minutes).
    public var customTimerMinutesTotal: Int {
        didSet { DefaultsKeys.storeCustomMinutes(customTimerMinutesTotal) }
    }

    /// Exposes the discrete hour spinner for `.custom`.
    public var customTimerHourComponent: Int {
        min(5, customTimerMinutesTotal / 60)
    }

    /// Exposes the discrete minute spinner for `.custom`.
    public var customTimerMinuteComponent: Int {
        customTimerMinutesTotal % 60
    }

    /// Default master amplitude surfaced in onboarding Settings.
    public var defaultMasterVolumeStored: Double {
        didSet { DefaultsKeys.storeSettingsDefaultMaster(defaultMasterVolumeStored) }
    }

    /// Default timer preset surfaced in onboarding Settings.
    public var defaultTimerStored: SleepTimerPreset {
        didSet { DefaultsKeys.storeSettingsDefaultTimer(defaultTimerStored) }
    }

    /// Whether macOS should relaunch Hush after login.
    public var launchAtLoginEnabled: Bool {
        didSet { Self.applyLaunchAtLogin(launchAtLoginEnabled) }
    }

    /// Whether the user wants a macOS notification when timers fire.
    public var notifyOnTimerEnd: Bool {
        didSet { DefaultsKeys.storeNotifyOnEnd(notifyOnTimerEnd) }
    }

    /// Indicates whether decoded buffers finished loading.
    public private(set) var isAudioReady = false

    /// Sound IDs with a decoded PCM buffer (mirrored from ``AudioEngineService`` after preload for sync UI lookups).
    public private(set) var loadedSoundIDs: Set<String> = []

    /// Saved sound-mix presets, persisted in UserDefaults.
    public var presets: [SoundPreset] {
        didSet { DefaultsKeys.storePresets(presets) }
    }

    // MARK: – Init

    /// Creates a fully wired mixer with bundled sounds and audio services.
    public init(audio: AudioEngineService) {
        self.audio = audio
        let loadedTracks = DefaultsKeys.loadTracks()
        var merged: [String: SoundTrackRuntime] = [:]
        for sound in Sound.library {
            var runtime = loadedTracks[sound.id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
            runtime.isEnabled = false
            merged[sound.id] = runtime
        }
        tracks = merged
        DefaultsKeys.storeTracks(merged)
        masterVolume = DefaultsKeys.loadMaster()
        timerPreset = DefaultsKeys.loadTimerDefault()
        customTimerMinutesTotal = DefaultsKeys.loadCustomMinutes()
        defaultMasterVolumeStored = DefaultsKeys.loadSettingsDefaultMaster()
        defaultTimerStored = DefaultsKeys.loadSettingsDefaultTimer()
        launchAtLoginEnabled = Self.readLaunchAtLoginState()
        notifyOnTimerEnd = DefaultsKeys.loadNotifyOnEnd()
        presets = DefaultsKeys.loadPresets()
        bindResumeObserver()
        Task { await bootstrapAudio() }
    }

    deinit {
        if let resumeObserver {
            NotificationCenter.default.removeObserver(resumeObserver)
        }
    }

    // MARK: – Public interface

    /// Returns whether a buffer exists for the track (UI can dim missing assets).
    public func isBufferAvailable(for id: String) -> Bool {
        loadedSoundIDs.contains(id)
    }

    /// Updates spinner selections backing the `.custom` preset (capped to five-hour sessions).
    public func setCustomTimerComponents(hours: Int, minutes: Int) {
        let clampedHours = max(0, min(5, hours))
        let clampedMinutes = max(0, min(59, minutes))
        customTimerMinutesTotal = clampedHours * 60 + clampedMinutes
    }

    /// Persists the toggle and applies a fade to the corresponding node.
    public func setEnabled(_ enabled: Bool, for id: String) {
        var runtime = tracks[id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
        runtime.isEnabled = enabled
        tracks[id] = runtime
        DefaultsKeys.storeTracks(tracks)
        Task {
            if enabled {
                await audio.playSound(id: id, targetLinearVolume: Float(runtime.normalizedVolume))
            } else {
                await audio.stopSound(id: id, fadeDuration: 0.3)
            }
            await MainActor.run { self.recomputeGlobalPlayingFlag() }
        }
    }

    /// Updates per-stem gain with immediate reflection in the engine.
    public func setVolume(_ value: Double, for id: String) {
        var runtime = tracks[id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
        runtime.normalizedVolume = value
        tracks[id] = runtime
        DefaultsKeys.storeTracks(tracks)
        Task {
            if runtime.isEnabled {
                await audio.playSound(id: id, targetLinearVolume: Float(runtime.normalizedVolume))
            }
        }
    }

    /// Starts the sleep timer using the active preset (custom uses stored minutes).
    public func startTimer() {
        cancelTimer()
        guard let seconds = resolvedTimerDuration() else {
            timerEndsAt = nil
            return
        }
        let end = Date().addingTimeInterval(seconds)
        timerEndsAt = end
        timerTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self.handleTimerElapsed()
        }
    }

    /// Cancels an in-flight countdown without fading audio.
    public func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerEndsAt = nil
    }

    /// Restores factory defaults for audio and timer preferences.
    public func resetToFactoryDefaults() {
        cancelTimer()
        DefaultsKeys.resetAll()
        timerPreset = .disabled
        customTimerMinutesTotal = 30
        defaultMasterVolumeStored = 0.75
        defaultTimerStored = .disabled
        notifyOnTimerEnd = true
        DefaultsKeys.storeNotifyOnEnd(true)
        launchAtLoginEnabled = false
        var fresh: [String: SoundTrackRuntime] = [:]
        for sound in Sound.library {
            fresh[sound.id] = SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
        }
        tracks = fresh
        DefaultsKeys.storeTracks(tracks)
        masterVolume = 0.75
        DefaultsKeys.storeMaster(masterVolume)
        DefaultsKeys.storeSettingsDefaultMaster(defaultMasterVolumeStored)
        DefaultsKeys.storeSettingsDefaultTimer(defaultTimerStored)
        Task { await audio.fadeOutAll(stopAfter: 0.2) }
        recomputeGlobalPlayingFlag()
        NotificationCenter.default.post(name: .hushReloadStoredChrome, object: nil)
    }

    /// Captures currently active sounds and their volumes as a new preset.
    public func saveCurrentAsPreset() {
        let activeTracks = tracks.compactMapValues { runtime -> Double? in
            runtime.isEnabled ? runtime.normalizedVolume : nil
        }
        guard !activeTracks.isEmpty else { return }
        let symbolNames = Sound.library
            .filter { activeTracks[$0.id] != nil }
            .map(\.symbolName)
        let preset = SoundPreset(
            tracks: activeTracks,
            symbolNames: symbolNames,
            hue: Double.random(in: 0 ... 1)
        )
        presets.append(preset)
    }

    /// Enables the sounds in the preset (disabling all others) and starts playback.
    public func loadPreset(_ preset: SoundPreset) {
        for sound in Sound.library {
            var runtime = tracks[sound.id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
            runtime.isEnabled = preset.tracks[sound.id] != nil
            if let volume = preset.tracks[sound.id] {
                runtime.normalizedVolume = volume
            }
            tracks[sound.id] = runtime
        }
        DefaultsKeys.storeTracks(tracks)
        recomputeGlobalPlayingFlag()
        Task {
            for sound in Sound.library where preset.tracks[sound.id] == nil {
                await audio.stopSound(id: sound.id, fadeDuration: 0.25)
            }
            for sound in Sound.library {
                guard let volume = preset.tracks[sound.id] else { continue }
                await audio.playSound(id: sound.id, targetLinearVolume: Float(volume))
            }
        }
    }

    /// Removes a preset permanently.
    public func deletePreset(_ preset: SoundPreset) {
        presets.removeAll { $0.id == preset.id }
    }

    /// Randomly enables 1–4 available sounds with randomised volumes, disabling everything else.
    public func randomizeMix() {
        let available = Sound.library.filter { loadedSoundIDs.contains($0.id) }
        guard !available.isEmpty else { return }
        let pickCount = Int.random(in: 1 ... min(4, available.count))
        let selected = Set(available.shuffled().prefix(pickCount).map(\.id))
        for sound in Sound.library {
            var runtime = tracks[sound.id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
            runtime.isEnabled = selected.contains(sound.id)
            if selected.contains(sound.id) {
                runtime.normalizedVolume = Double.random(in: 0.30 ... 0.80)
            }
            tracks[sound.id] = runtime
        }
        DefaultsKeys.storeTracks(tracks)
        recomputeGlobalPlayingFlag()
        Task {
            for sound in Sound.library where !selected.contains(sound.id) {
                await audio.stopSound(id: sound.id, fadeDuration: 0.25)
            }
            for sound in Sound.library {
                guard let runtime = tracks[sound.id], runtime.isEnabled else { continue }
                await audio.playSound(id: sound.id, targetLinearVolume: Float(runtime.normalizedVolume))
            }
        }
    }

    /// Formats the remaining timer for header presentation.
    public func formattedCountdown(referenceDate: Date = Date()) -> String? {
        guard let end = timerEndsAt else { return nil }
        let interval = max(0, end.timeIntervalSince(referenceDate))
        guard interval > 1 else { return "Ending…" }
        let totalSeconds = Int(interval.rounded(.up))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: – Private helpers

private extension SoundMixerViewModel {
    func bootstrapAudio() async {
        await audio.preloadSounds(Sound.library)
        let ids = await audio.loadedSoundIDs()
        loadedSoundIDs = ids
        isAudioReady = true
        await audio.setMasterVolume(Float(masterVolume))
        recomputeGlobalPlayingFlag()
    }

    func recomputeGlobalPlayingFlag() {
        isGloballyPlaying = tracks.contains { id, runtime in
            runtime.isEnabled && loadedSoundIDs.contains(id)
        }
        HushMenuBarGlyphSync.schedule(isPlaying: isGloballyPlaying)
    }

    func resolvedTimerDuration() -> TimeInterval? {
        switch timerPreset {
        case .disabled:
            return Optional<TimeInterval>.none
        case .custom:
            guard customTimerMinutesTotal > 0 else {
                return Optional<TimeInterval>.none
            }
            return TimeInterval(customTimerMinutesTotal * 60)
        default:
            return timerPreset.durationSeconds
        }
    }

    func handleTimerElapsed() async {
        await audio.fadeOutAll(stopAfter: 3)
        for sound in Sound.library {
            var runtime = tracks[sound.id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
            runtime.isEnabled = false
            tracks[sound.id] = runtime
        }
        DefaultsKeys.storeTracks(tracks)
        await MainActor.run {
            timerEndsAt = nil
            recomputeGlobalPlayingFlag()
            if notifyOnTimerEnd {
                Task { await Self.fireTimerNotification() }
            }
        }
    }

    func bindResumeObserver() {
        resumeObserver = NotificationCenter.default.addObserver(
            forName: .hushEngineNeedsResume,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let payload = self.tracks.compactMap { id, runtime -> (String, Float)? in
                    guard runtime.isEnabled else { return nil }
                    return (id, Float(runtime.normalizedVolume))
                }
                await self.audio.resume(ids: payload)
                self.recomputeGlobalPlayingFlag()
            }
        }
    }

    static func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort: ignore registration failures to keep UI responsive.
        }
    }

    static func readLaunchAtLoginState() -> Bool {
        switch SMAppService.mainApp.status {
        case .enabled: true
        default: false
        }
    }

    static func fireTimerNotification() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        guard granted == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Hush"
        content.body = "Your sleep timer ended and playback faded out."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}

// MARK: – UserDefaults persistence

private enum DefaultsKeys {
    private static let master = "hush.defaults.masterVolume"
    private static let tracksArchive = "hush.defaults.tracks.json"
    private static let timer = "hush.defaults.timerPreset"
    private static let custom = "hush.defaults.customMinutes"
    private static let defaultsMaster = "hush.defaults.settings.master"
    private static let defaultsTimer = "hush.defaults.settings.timer"
    private static let notify = "hush.defaults.notify.timer"
    private static let presetsArchive = "hush.defaults.presets.json"

    static func loadTracks() -> [String: SoundTrackRuntime] {
        guard
            let data = UserDefaults.standard.data(forKey: tracksArchive),
            let decoded = try? JSONDecoder().decode([String: SoundTrackRuntime].self, from: data)
        else { return [:] }
        return decoded
    }

    static func storeTracks(_ map: [String: SoundTrackRuntime]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: tracksArchive)
        }
    }

    static func loadMaster() -> Double {
        let value = UserDefaults.standard.object(forKey: master) as? Double
        return value ?? 0.85
    }

    static func storeMaster(_ value: Double) {
        UserDefaults.standard.set(value, forKey: master)
    }

    static func loadTimerDefault() -> SleepTimerPreset {
        guard
            let raw = UserDefaults.standard.string(forKey: timer),
            let preset = SleepTimerPreset(rawValue: raw)
        else { return .disabled }
        return preset
    }

    static func storeTimerDefault(_ preset: SleepTimerPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: timer)
    }

    static func loadCustomMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: custom)
        return stored > 0 ? stored : 45
    }

    static func storeCustomMinutes(_ minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: custom)
    }

    static func loadSettingsDefaultMaster() -> Double {
        let stored = UserDefaults.standard.object(forKey: defaultsMaster) as? Double
        return stored ?? 0.75
    }

    static func storeSettingsDefaultMaster(_ value: Double) {
        UserDefaults.standard.set(value, forKey: defaultsMaster)
    }

    static func loadSettingsDefaultTimer() -> SleepTimerPreset {
        guard
            let raw = UserDefaults.standard.string(forKey: defaultsTimer),
            let preset = SleepTimerPreset(rawValue: raw)
        else { return .disabled }
        return preset
    }

    static func storeSettingsDefaultTimer(_ preset: SleepTimerPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: defaultsTimer)
    }

    static func loadNotifyOnEnd() -> Bool {
        if UserDefaults.standard.object(forKey: notify) == nil { return true }
        return UserDefaults.standard.bool(forKey: notify)
    }

    static func storeNotifyOnEnd(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: notify)
    }

    static func loadPresets() -> [SoundPreset] {
        guard
            let data = UserDefaults.standard.data(forKey: presetsArchive),
            let decoded = try? JSONDecoder().decode([SoundPreset].self, from: data)
        else { return [] }
        return decoded
    }

    static func storePresets(_ presets: [SoundPreset]) {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsArchive)
        }
    }

    static func resetAll() {
        [master, tracksArchive, timer, custom, defaultsMaster, defaultsTimer, notify,
         presetsArchive, "colorScheme"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.synchronize()
    }
}
