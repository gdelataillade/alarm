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
    };
