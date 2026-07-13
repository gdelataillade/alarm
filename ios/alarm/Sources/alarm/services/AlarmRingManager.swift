import AVFoundation
import Flutter
import MediaPlayer
import os.log

class AlarmRingManager: NSObject {
    static let shared = AlarmRingManager()

    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "AlarmRingManager")

    /// State is confined to the main actor; see AlarmManager.
    private var previousVolume: Float?
    private var volumeEnforcementTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var currentAlarmId: Int?
    /// Pending tasks (audio completion callback and volume fades) that must
    /// not outlive the current ring. Cancelled on stop so a stale completion
    /// can never stop an alarm that was re-scheduled with the same id.
    private var pendingTasks: [Task<Void, Never>] = []

    override private init() {
        super.init()
    }

    @MainActor
    func start(id: Int, registrar: FlutterPluginRegistrar, assetAudioPath: String?, loopAudio: Bool, volumeSettings: VolumeSettings, onComplete: (() -> Void)?) async {
        let start = Date()

        // If another alarm is already ringing, stop it before starting the new one
        if let currentId = self.currentAlarmId, currentId != id {
            os_log(.info, log: AlarmRingManager.logger, "Overriding previous alarm ID=%d with new alarm ID=%d", currentId, id)
            self.cancelPendingTasks()
            self.audioPlayer?.stop()
            self.audioPlayer = nil
            self.volumeEnforcementTimer?.invalidate()
            self.volumeEnforcementTimer = nil
        }

        self.currentAlarmId = id

        self.duckOtherAudios()

        let targetSystemVolume: Float
        if let systemVolume = volumeSettings.volume.map({ Float($0) }) {
            targetSystemVolume = systemVolume
            self.previousVolume = await self.setSystemVolume(volume: systemVolume)
        } else {
            targetSystemVolume = self.getSystemVolume()
        }

        if volumeSettings.volumeEnforced {
            let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
                AlarmRingManager.shared.enforcementTimerTriggered(targetSystemVolume: targetSystemVolume)
            }
            RunLoop.main.add(timer, forMode: .common)
            self.volumeEnforcementTimer = timer
        }

        guard let audioPlayer = self.loadAudioPlayer(registrar: registrar, assetAudioPath: assetAudioPath) else {
            await self.stop()
            return
        }

        if loopAudio {
            audioPlayer.numberOfLoops = -1
        }

        audioPlayer.prepareToPlay()
        audioPlayer.volume = 0.0
        audioPlayer.play()
        self.audioPlayer = audioPlayer

        if !volumeSettings.fadeSteps.isEmpty {
            self.fadeVolume(steps: volumeSettings.fadeSteps)
        } else if let fadeDuration = volumeSettings.fadeDuration {
            self.fadeVolume(steps: [VolumeFadeStep(time: 0, volume: 0), VolumeFadeStep(time: fadeDuration, volume: 1.0)])
        } else {
            audioPlayer.volume = 1.0
        }

        if !loopAudio, let onComplete = onComplete {
            let completionTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(audioPlayer.duration * 1_000_000_000))
                if Task.isCancelled {
                    return
                }
                onComplete()
            }
            self.pendingTasks.append(completionTask)
        }

        let runDuration = Date().timeIntervalSince(start)
        os_log(.debug, log: AlarmRingManager.logger, "Alarm ring started in %.2fs.", runDuration)
    }

    @MainActor
    func stop(id: Int? = nil) async {
        if let id = id, self.currentAlarmId != id {
            os_log(.debug, log: AlarmRingManager.logger,
                "Skipping stop for alarm ID=%d because current alarm is ID=%d", id, self.currentAlarmId ?? -1)
            return
        }

        self.cancelPendingTasks()

        if self.volumeEnforcementTimer == nil && self.previousVolume == nil && self.audioPlayer == nil {
            os_log(.debug, log: AlarmRingManager.logger, "Alarm ringer already stopped.")
            self.currentAlarmId = nil
            return
        }

        let start = Date()

        self.audioPlayer?.stop()
        self.audioPlayer = nil

        self.volumeEnforcementTimer?.invalidate()
        self.volumeEnforcementTimer = nil

        if let previousVolume = self.previousVolume {
            await self.setSystemVolume(volume: previousVolume)
            self.previousVolume = nil
        }

        self.currentAlarmId = nil
        self.mixOtherAudios()

        let runDuration = Date().timeIntervalSince(start)
        os_log(.debug, log: AlarmRingManager.logger, "Alarm ring stopped in %.2fs.", runDuration)
    }

    @MainActor
    private func cancelPendingTasks() {
        self.pendingTasks.forEach { $0.cancel() }
        self.pendingTasks.removeAll()
    }

    private func duckOtherAudios() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            os_log(.debug, log: AlarmRingManager.logger, "Stopped other audio sources.")
        } catch {
            os_log(.error, log: AlarmRingManager.logger, "Error setting up audio session with option duckOthers: %@", error.localizedDescription)
        }
    }

    private func mixOtherAudios() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            os_log(.debug, log: AlarmRingManager.logger, "Play concurrently with other audio sources.")
        } catch {
            os_log(.error, log: AlarmRingManager.logger, "Error setting up audio session with option mixWithOthers: %@", error.localizedDescription)
        }
    }

    private func getSystemVolume() -> Float {
        let audioSession = AVAudioSession.sharedInstance()
        return audioSession.outputVolume
    }

    @discardableResult
    @MainActor
    private func setSystemVolume(volume: Float) async -> Float? {
        let volumeView = MPVolumeView()

        // We need to pause for 100ms to ensure the slider loads.
        try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))

        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            os_log(.error, log: AlarmRingManager.logger, "Volume slider could not be found.")
            return nil
        }

        let previousVolume = slider.value
        os_log(.info, log: AlarmRingManager.logger, "Setting system volume to %f.", volume)
        slider.value = volume
        volumeView.removeFromSuperview()

        return previousVolume
    }

    private func enforcementTimerTriggered(targetSystemVolume: Float) {
        Task { @MainActor in
            let currentSystemVolume = self.getSystemVolume()
            if abs(currentSystemVolume - targetSystemVolume) > 0.01 {
                os_log(.debug, log: AlarmRingManager.logger, "System volume changed. Restoring to %f.", targetSystemVolume)
                await self.setSystemVolume(volume: targetSystemVolume)
            }
        }
    }

    private func loadAudioPlayer(registrar: FlutterPluginRegistrar, assetAudioPath: String?) -> AVAudioPlayer? {
        let audioURL: URL

        if let assetAudioPath = assetAudioPath {
            // Use provided audio path
            if assetAudioPath.hasPrefix("assets/") || assetAudioPath.hasPrefix("asset/") {
                let filename = registrar.lookupKey(forAsset: assetAudioPath)
                guard let audioPath = Bundle.main.path(forResource: filename, ofType: nil) else {
                    os_log(.error, log: AlarmRingManager.logger, "Audio file not found: %@", assetAudioPath)
                    return nil
                }
                audioURL = URL(fileURLWithPath: audioPath)
            } else {
                guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    os_log(.error, log: AlarmRingManager.logger, "Document directory not found.")
                    return nil
                }
                audioURL = documentsDirectory.appendingPathComponent(assetAudioPath)
            }
        } else {
            // Use the bundled default alarm sound for iOS.
            // Under SwiftPM the resources are exposed via Bundle.module; under
            // CocoaPods they live in a nested alarm.bundle inside the framework.
            #if SWIFT_PACKAGE
            let resourceBundle: Bundle = .module
            #else
            let frameworkBundle = Bundle(for: Self.self)
            guard let bundleURL = frameworkBundle.url(forResource: "alarm", withExtension: "bundle"),
                  let nestedBundle = Bundle(url: bundleURL) else {
                os_log(.error, log: AlarmRingManager.logger, "alarm.bundle not found inside the framework")
                return nil
            }
            let resourceBundle = nestedBundle
            #endif
            guard let audioPath = resourceBundle.path(forResource: "default", ofType: "m4a") else {
                os_log(.error, log: AlarmRingManager.logger, "Default alarm sound 'default.m4a' not found in resource bundle")
                return nil
            }
            audioURL = URL(fileURLWithPath: audioPath)
            os_log(.debug, log: AlarmRingManager.logger, "Using bundled default alarm sound: %@", audioURL.absoluteString)
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            os_log(.debug, log: AlarmRingManager.logger, "Audio player loaded from: %@", audioURL.absoluteString)
            return audioPlayer
        } catch {
            os_log(.error, log: AlarmRingManager.logger, "Error loading audio player: %@", error.localizedDescription)
            return nil
        }
    }

    @MainActor
    private func fadeVolume(steps: [VolumeFadeStep]) {
        guard let audioPlayer = self.audioPlayer else {
            os_log(.error, log: AlarmRingManager.logger, "Cannot fade volume because audioPlayer is nil.")
            return
        }

        if !audioPlayer.isPlaying {
            os_log(.error, log: AlarmRingManager.logger, "Cannot fade volume because audioPlayer isn't playing.")
            return
        }

        audioPlayer.volume = Float(steps[0].volume)

        for i in 0 ..< steps.count - 1 {
            let startTime = steps[i].time
            let nextStep = steps[i + 1]
            // Subtract 50ms to avoid weird jumps that might occur when two fades collide.
            let fadeDuration = nextStep.time - startTime - 0.05
            let targetVolume = Float(nextStep.volume)

            // Schedule the fade using setVolume for a smooth transition
            let fadeTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(startTime * 1_000_000_000))
                if Task.isCancelled || !audioPlayer.isPlaying {
                    return
                }
                os_log(.info, log: AlarmRingManager.logger, "Fading volume to %f over %f seconds.", targetVolume, fadeDuration)
                audioPlayer.setVolume(targetVolume, fadeDuration: fadeDuration)
            }
            self.pendingTasks.append(fadeTask)
        }
    }
}
