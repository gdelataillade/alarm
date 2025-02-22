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
            os_log(.debug, log: VibrationManager.logger, "Simulator does not support vibrations.")
            return
        }

        if vibrationTimer != nil {
            os_log(.debug, log: VibrationManager.logger, "Vibration already active.")
            return
        }

        let timer = Timer(timeInterval: 1.0,
                          target: self,
                          selector: #selector(vibrationTimerFired(_:)),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        vibrationTimer = timer
        timer.fire()

        os_log(.debug, log: VibrationManager.logger, "Vibration started.")
    }

    func stop() {
        if isSimulator {
            os_log(.debug, log: VibrationManager.logger, "Simulator does not support vibrations.")
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

    @objc private func vibrationTimerFired(_ timer: Timer) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
