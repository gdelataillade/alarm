import AudioToolbox

class VibrationService {
    #if targetEnvironment(simulator)
        private let isDevice = false
    #else
        private let isDevice = true
    #endif

    public var vibrate = false

    func triggerVibrations() {
        if vibrate && isDevice {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    AudioServicesDisposeSystemSoundID(kSystemSoundID_Vibrate)
                    self.triggerVibrations()
                }
        }
    }

    func setVibrations(enable: Bool) {
        vibrate = enable
    }
}
