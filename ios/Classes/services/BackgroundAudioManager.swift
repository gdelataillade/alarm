import AVFoundation
import Flutter
import os.log

class BackgroundAudioManager: NSObject {
    static let shared = BackgroundAudioManager()

    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "BackgroundAudioManager")

    private var scheduledAlarms: Set<Int> = []
    private var silentAudioPlayer: AVAudioPlayer?

    override private init() {
        super.init()
    }

    func start(registrar: FlutterPluginRegistrar) {
        if self.silentAudioPlayer != nil {
            os_log(.debug, log: BackgroundAudioManager.logger, "Silent player already running.")
            return
        }

        let filename = registrar.lookupKey(forAsset: "assets/long_blank.mp3", fromPackage: "alarm")
        guard let audioPath = Bundle.main.path(forResource: filename, ofType: nil) else {
            os_log(.error, log: BackgroundAudioManager.logger, "Could not find silent audio file.")
            return
        }
        let audioUrl = URL(fileURLWithPath: audioPath)

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: audioUrl)
        } catch {
            os_log(.error, log: BackgroundAudioManager.logger, "Could not create and play silent audio player: %@", error.localizedDescription)
            return
        }

        self.mixOtherAudios()
        player.numberOfLoops = -1
        player.volume = 0.01
        player.play()
        self.silentAudioPlayer = player
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)

        os_log(.debug, log: BackgroundAudioManager.logger, "Started silent player.")
    }

    func refresh(registrar: FlutterPluginRegistrar) {
        guard let player = self.silentAudioPlayer else {
            os_log(.debug, log: BackgroundAudioManager.logger, "Cannot refresh silent player since it's not running. Starting it.")
            self.start(registrar: registrar)
            return
        }

        self.mixOtherAudios()
        player.pause()
        player.play()
        os_log(.debug, log: BackgroundAudioManager.logger, "Refreshed silent player.")
    }

    func stop() {
        guard let player = self.silentAudioPlayer else {
            os_log(.debug, log: BackgroundAudioManager.logger, "Silent player already stopped.")
            return
        }

        self.mixOtherAudios()
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        player.stop()
        self.silentAudioPlayer = nil
        os_log(.debug, log: BackgroundAudioManager.logger, "Stopped silent player.")
    }

    // Play concurrently with other audio sources.
    private func mixOtherAudios() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            os_log(.error, log: BackgroundAudioManager.logger, "Error setting up audio session with option mixWithOthers: %@", error.localizedDescription)
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
            case .began:
                os_log(.debug, log: BackgroundAudioManager.logger, "Interruption began.")
                self.silentAudioPlayer?.play()
            case .ended:
                os_log(.debug, log: BackgroundAudioManager.logger, "Interruption ended.")
                self.silentAudioPlayer?.play()
            default:
                break
        }
    }
}
