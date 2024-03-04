import AVFoundation

class AlarmConfiguration {
    let id: Int
    let assetAudio: String
    let vibrationsEnabled: Bool
    let loopAudio: Bool
    let fadeDuration: Double
    let volume: Float?
    var triggerTime: Date?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var task: DispatchWorkItem?

    init(id: Int, assetAudio: String, vibrationsEnabled: Bool, loopAudio: Bool, fadeDuration: Double, volume: Float?) {
        self.id = id
        self.assetAudio = assetAudio
        self.vibrationsEnabled = vibrationsEnabled
        self.loopAudio = loopAudio
        self.fadeDuration = fadeDuration
        self.volume = volume
    }
}