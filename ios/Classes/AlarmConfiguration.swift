import AVFoundation

class AlarmConfiguration {
    let id: Int
    let assetAudio: String
    let vibrationsEnabled: Bool
    let loopAudio: Bool
    let fadeDuration: Double
    let fadeStopTimes: [Double]
    let fadeStopVolumes: [Float]
    let volume: Float?
    var volumeEnforced: Bool
    var volumeEnforcementTimer: Timer?
    var triggerTime: Date?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var task: DispatchWorkItem?
    
    init(id: Int, assetAudio: String, vibrationsEnabled: Bool, loopAudio: Bool, fadeDuration: Double, fadeStopTimes: [Double], fadeStopVolumes: [Float], volume: Float?, volumeEnforced: Bool) {
        self.id = id
        self.assetAudio = assetAudio
        self.vibrationsEnabled = vibrationsEnabled
        self.loopAudio = loopAudio
        self.fadeDuration = fadeDuration
        self.fadeStopTimes = fadeStopTimes
        self.fadeStopVolumes = fadeStopVolumes
        self.volume = volume
        self.volumeEnforced = volumeEnforced
    }
}
