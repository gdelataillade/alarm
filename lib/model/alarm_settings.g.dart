// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlarmSettings _$AlarmSettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AlarmSettings',
      json,
      ($checkedConvert) {
        final val = AlarmSettings(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          dateTime: $checkedConvert('dateTime',
              (v) => AlarmSettings._dateTimeFromJson((v as num).toInt())),
          assetAudioPath: $checkedConvert('assetAudioPath', (v) => v as String),
          volumeSettings: $checkedConvert('volumeSettings',
              (v) => VolumeSettings.fromJson(v as Map<String, dynamic>)),
          notificationSettings: $checkedConvert('notificationSettings',
              (v) => NotificationSettings.fromJson(v as Map<String, dynamic>)),
          loopAudio: $checkedConvert('loopAudio', (v) => v as bool? ?? true),
          vibrate: $checkedConvert('vibrate', (v) => v as bool? ?? true),
          warningNotificationOnKill: $checkedConvert(
              'warningNotificationOnKill', (v) => v as bool? ?? true),
          androidFullScreenIntent: $checkedConvert(
              'androidFullScreenIntent', (v) => v as bool? ?? true),
          allowAlarmOverlap:
              $checkedConvert('allowAlarmOverlap', (v) => v as bool? ?? false),
        );
        return val;
      },
    );

Map<String, dynamic> _$AlarmSettingsToJson(AlarmSettings instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dateTime': AlarmSettings._dateTimeToJson(instance.dateTime),
      'assetAudioPath': instance.assetAudioPath,
      'volumeSettings': instance.volumeSettings.toJson(),
      'notificationSettings': instance.notificationSettings.toJson(),
      'loopAudio': instance.loopAudio,
      'vibrate': instance.vibrate,
      'warningNotificationOnKill': instance.warningNotificationOnKill,
      'androidFullScreenIntent': instance.androidFullScreenIntent,
      'allowAlarmOverlap': instance.allowAlarmOverlap,
    };
