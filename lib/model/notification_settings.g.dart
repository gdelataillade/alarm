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
          icon: $checkedConvert('icon', (v) => v as String?),
          iconColor: $checkedConvert(
              'iconColor',
              (v) => v == null
                  ? null
                  : Color(
                      v as int,
                    )),
          keepNotificationAfterAlarmEnds: $checkedConvert(
              'keepNotificationAfterAlarmEnds', (v) => v as bool? ?? false),
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
      if (instance.icon case final value?) 'icon': value,
      if (instance.iconColor case final value?) 'iconColor': value.value,
      'keepNotificationAfterAlarmEnds': instance.keepNotificationAfterAlarmEnds,
    };
