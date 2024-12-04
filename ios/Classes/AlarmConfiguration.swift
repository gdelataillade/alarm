import AVFoundation

class AlarmConfiguration {
    let settings: AlarmSettings

    var triggerTime: Date?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var volumeEnforcementTimer: Timer?
    var task: DispatchWorkItem?

    init(settings: AlarmSettings) {
        self.settings = settings
    }
}
