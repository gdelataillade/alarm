import Foundation

struct VolumeSettings: Codable {
    var volume: Double?
    var fadeDuration: TimeInterval?
    var fadeSteps: [VolumeFadeStep]
    var volumeEnforced: Bool

    static func from(wire: VolumeSettingsWire) -> VolumeSettings {
        return VolumeSettings(
            volume: wire.volume,
            fadeDuration: wire.fadeDurationMillis.map { Double($0 / 1000) },
            fadeSteps: wire.fadeSteps.map(VolumeFadeStep.from),
            volumeEnforced: wire.volumeEnforced
        )
    }
}

struct VolumeFadeStep: Codable {
    var time: TimeInterval
    var volume: Double

    static func from(wire: VolumeFadeStepWire) -> VolumeFadeStep {
        return VolumeFadeStep(
            time: Double(wire.timeMillis / 1000),
            volume: wire.volume
        )
    }
}
