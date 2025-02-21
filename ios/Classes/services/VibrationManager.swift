import AVFoundation
import os.log

class VibrationManager: NSObject {
    static let shared = VibrationManager()

    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "VibrationManager")

    #if targetEnvironment(simulator)
        private let isSimulator = true
    #else
        private let isSimulator = false
    #endif

    private var vibrationTimer: Timer?

    override private init() {
        super.init()
    }

    func start() {
        if isSimulator {
            return
        }

        if vibrationTimer != nil {
            os_log(.debug, log: VibrationManager.logger, "Vibration already active.")
            return
        }

        DispatchQueue.main.async {
            // Avoid race conditions
            self.vibrationTimer?.invalidate()
            self.vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                os_log(.info, log: VibrationManager.logger, "Vibrating.")
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
            os_log(.debug, log: VibrationManager.logger, "Vibration started.")
        }
    }

    func stop() {
        if isSimulator {
            return
        }

        guard let timer = vibrationTimer else {
            os_log(.debug, log: VibrationManager.logger, "Vibration already inactive.")
            return
        }

        timer.invalidate()
        vibrationTimer = nil
        os_log(.debug, log: VibrationManager.logger, "Vibration stopped.")
    }
}
