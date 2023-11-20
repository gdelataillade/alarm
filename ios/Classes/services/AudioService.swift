import AVFoundation

class AudioService {
    private var audioPlayers: [Int: AVAudioPlayer] = [:]
    private var silentAudioPlayer: AVAudioPlayer?

    func playAudio(id: Int, assetAudio: String, volume: Float?, loop: Bool) {}

    func stopAudio(id: Int) {}

    func audioCurrentTime(id: Int) -> TimeInterval? {
        return audioPlayers[id]?.currentTime
    }

    func startSilentSound() {}

    func mixOtherAudios() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin - AudioService: Error setting up audio session with option mixWithOthers: \(error.localizedDescription)")
        }
    }

    func duckOtherAudios() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin - AudioService: Error setting up audio session with option duckOthers: \(error.localizedDescription)")
        }
    }
}
