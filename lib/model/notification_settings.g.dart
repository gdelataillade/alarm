// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationSettings _$NotificationSettingsFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'NotificationSettings',
      json,
      ($checkedConvert) {
        final val = NotificationSettings(
          title: $checkedConvert('title', (v) => v as String),
          body: $checkedConvert('body', (v) => v as String),
          stopButton: $checkedConvert('stopButton', (v) => v as String?),
          androidSnoozeButton:
              $checkedConvert('androidSnoozeButton', (v) => v as String?),
          icon: $checkedConvert('icon', (v) => v as String?),
          iconColor: $checkedConvert(
              'iconColor',
              (v) =>
                  const _ColorJsonConverter().fromJson((v as num?)?.toInt())),
          keepNotificationAfterAlarmEnds: $checkedConvert(
              'keepNotificationAfterAlarmEnds', (v) => v as bool? ?? false),
          androidStopAlarmOnDismiss: $checkedConvert(
              'androidStopAlarmOnDismiss', (v) => v as bool? ?? true),
        );
        return val;
      },
    );

Map<String, dynamic> _$NotificationSettingsToJson(
        NotificationSettings instance) =>
    <String, dynamic>{
      'title': instance.title,
      'body': instance.body,
      if (instance.stopButton case final value?) 'stopButton': value,
      if (instance.androidSnoozeButton case final value?)
        'androidSnoozeButton': value,
      if (instance.icon case final value?) 'icon': value,
      if (const _ColorJsonConverter().toJson(instance.iconColor)
          case final value?)
        'iconColor': value,
      'keepNotificationAfterAlarmEnds': instance.keepNotificationAfterAlarmEnds,
      'androidStopAlarmOnDismiss': instance.androidStopAlarmOnDismiss,
    };
