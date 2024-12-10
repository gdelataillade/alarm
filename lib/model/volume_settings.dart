import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'volume_settings.g.dart';

/// Model for Alarm volume settings.
@JsonSerializable(constructor: '_')
class VolumeSettings extends Equatable {
  /// Internal constructor for [VolumeSettings].
  const VolumeSettings._({
    this.volume,
    this.fadeDuration,
    this.fadeSteps = const [],
    this.volumeEnforced = false,
  })  : assert(
          volume == null || (volume >= 0 && volume <= 1),
          'volume must be NULL or in the range [0, 1]',
        ),
        assert(
          fadeDuration == null || fadeDuration > Duration.zero,
          'fadeDuration must be NULL or stricly positive',
        );

  /// Constructs [VolumeSettings] with fixed volume level.
  const VolumeSettings.fixed({
    double? volume,
    bool volumeEnforced = false,
  }) : this._(
          volume: volume,
          volumeEnforced: volumeEnforced,
        );

  /// Constructs [VolumeSettings] with fading volume level.
  const VolumeSettings.fade({
    required Duration fadeDuration,
    double? volume,
    bool volumeEnforced = false,
  }) : this._(
          volume: volume,
          fadeDuration: fadeDuration,
          volumeEnforced: volumeEnforced,
        );

  /// Constructs [VolumeSettings] with slowly increasing (stepped) volume level.
  factory VolumeSettings.staircaseFade({
    required List<VolumeFadeStep> fadeSteps,
    double? volume,
    bool volumeEnforced = false,
  }) {
    assert(fadeSteps.isNotEmpty, 'fadeSteps must not be empty');
    return VolumeSettings._(
      volume: volume,
      fadeSteps: fadeSteps,
      volumeEnforced: volumeEnforced,
    );
  }

  /// Converts the JSON object to a `VolumeSettings` instance.
  factory VolumeSettings.fromJson(Map<String, dynamic> json) =>
      _$VolumeSettingsFromJson(json);

  /// Converts from wire datatype.
  VolumeSettings.fromWire(VolumeSettingsWire wire)
      : volume = wire.volume,
        fadeDuration = wire.fadeDurationMillis != null
            ? Duration(milliseconds: wire.fadeDurationMillis!)
            : null,
        fadeSteps = wire.fadeSteps.map(VolumeFadeStep.fromWire).toList(),
        volumeEnforced = wire.volumeEnforced;

  /// Specifies the system volume level to be set when the alarm goes off.
  ///
  /// Accepts a value between 0 (mute) and 1 (maximum volume).
  /// When the alarm is triggered,, the system volume adjusts to this specified
  /// specified level. Upon stopping the alarm, the system volume reverts to its
  /// prior setting.
  ///
  /// If left unspecified or set to `null`, the current system volume
  /// at the time of the alarm will be used.
  /// Defaults to `null`.
  final double? volume;

  /// Duration over which to fade the alarm ringtone.
  /// Set to `null` by default, which means no fade.
  final Duration? fadeDuration;

  /// Controls how the alarm volume will fade over time.
  ///
  /// Set to empty list by default, which means no fade.
  ///
  /// Example:
  ///    fadeStopTimes = [0s, 10s, 20s]
  ///    fadeStopVolumes = [0, 0.5, 1.0]
  /// The alarm will begin silent, fade to 50% of max volume by 10 seconds,
  /// and fade to max volume by 20 seconds.
  final List<VolumeFadeStep> fadeSteps;

  /// If true, the alarm volume is enforced, automatically resetting to the
  /// original alarm [volume] if the user attempts to adjust it.
  /// This prevents the user from lowering the alarm volume.
  /// Won't work if app is killed.
  ///
  /// Defaults to false.
  final bool volumeEnforced;

  /// Converts the [VolumeSettings] instance to a JSON object.
  Map<String, dynamic> toJson() => _$VolumeSettingsToJson(this);

  /// Converts to wire datatype which is used for host platform communication.
  VolumeSettingsWire toWire() => VolumeSettingsWire(
        volume: volume,
        fadeDurationMillis: fadeDuration?.inMilliseconds,
        fadeSteps: fadeSteps.map((e) => e.toWire()).toList(),
        volumeEnforced: volumeEnforced,
      );

  @override
  List<Object?> get props => [volume, fadeDuration, fadeSteps, volumeEnforced];
}

/// Represents a step in a volume fade sequence.
@JsonSerializable()
class VolumeFadeStep extends Equatable {
  /// Creates a new volume fade step.
  VolumeFadeStep(this.time, this.volume)
      : assert(
          !time.isNegative,
          'Time must be positive',
        ),
        assert(
          volume >= 0 && volume <= 1,
          'Volume must be in the range [0, 1]',
        );

  /// Converts JSON object to [VolumeFadeStep].
  factory VolumeFadeStep.fromJson(Map<String, dynamic> json) =>
      _$VolumeFadeStepFromJson(json);

  /// Converts from wire datatype.
  VolumeFadeStep.fromWire(VolumeFadeStepWire wire)
      : time = Duration(milliseconds: wire.timeMillis),
        volume = wire.volume;

  /// The time at which the volume should be set to [volume].
  final Duration time;

  /// The volume level to set at [time].
  final double volume;

  /// Converts the [VolumeFadeStep] instance to a JSON object.
  Map<String, dynamic> toJson() => _$VolumeFadeStepToJson(this);

  /// Converts to wire datatype which is used for host platform communication.
  VolumeFadeStepWire toWire() => VolumeFadeStepWire(
        timeMillis: time.inMilliseconds,
        volume: volume,
      );

  @override
  List<Object?> get props => [time, volume];
}
