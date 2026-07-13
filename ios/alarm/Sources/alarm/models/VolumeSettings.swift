import Foundation

struct VolumeSettings {
    var volume: Double?
    var fadeDuration: TimeInterval?
    var fadeSteps: [VolumeFadeStep]
    var volumeEnforced: Bool

    static func from(wire: VolumeSettingsWire) -> VolumeSettings {
        return VolumeSettings(
            volume: wire.volume,
            fadeDuration: wire.fadeDurationMillis.map { Double($0) / 1_000.0 },
            fadeSteps: wire.fadeSteps.map(VolumeFadeStep.from),
            volumeEnforced: wire.volumeEnforced
        )
    }
}

struct VolumeFadeStep {
    var time: TimeInterval
    var volume: Double

    static func from(wire: VolumeFadeStepWire) -> VolumeFadeStep {
        return VolumeFadeStep(
            time: Double(wire.timeMillis) / 1_000.0,
            volume: wire.volume
        )
    }
}
