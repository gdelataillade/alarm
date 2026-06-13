import AVFoundation

enum AlarmState {
    case scheduled
    case ringing
}

class AlarmConfiguration {
    let settings: AlarmSettings

    var state: AlarmState = .scheduled
    var timer: Timer?

    init(settings: AlarmSettings) {
        self.settings = settings
    }
}
