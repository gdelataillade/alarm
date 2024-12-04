// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volume_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VolumeSettings _$VolumeSettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'VolumeSettings',
      json,
      ($checkedConvert) {
        final val = VolumeSettings._(
          volume: $checkedConvert('volume', (v) => (v as num?)?.toDouble()),
          fadeDuration: $checkedConvert(
              'fadeDuration',
              (v) => v == null
                  ? null
                  : Duration(microseconds: (v as num).toInt())),
          fadeSteps: $checkedConvert(
              'fadeSteps',
              (v) =>
                  (v as List<dynamic>?)
                      ?.map((e) =>
                          VolumeFadeStep.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  const []),
          volumeEnforced:
              $checkedConvert('volumeEnforced', (v) => v as bool? ?? false),
        );
        return val;
      },
    );

Map<String, dynamic> _$VolumeSettingsToJson(VolumeSettings instance) =>
    <String, dynamic>{
      if (instance.volume case final value?) 'volume': value,
      if (instance.fadeDuration?.inMicroseconds case final value?)
        'fadeDuration': value,
      'fadeSteps': instance.fadeSteps.map((e) => e.toJson()).toList(),
      'volumeEnforced': instance.volumeEnforced,
    };

VolumeFadeStep _$VolumeFadeStepFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'VolumeFadeStep',
      json,
      ($checkedConvert) {
        final val = VolumeFadeStep(
          $checkedConvert(
              'time', (v) => Duration(microseconds: (v as num).toInt())),
          $checkedConvert('volume', (v) => (v as num).toDouble()),
        );
        return val;
      },
    );

Map<String, dynamic> _$VolumeFadeStepToJson(VolumeFadeStep instance) =>
    <String, dynamic>{
      'time': instance.time.inMicroseconds,
      'volume': instance.volume,
    };
