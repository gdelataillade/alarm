// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_NotificationPayload _$$_NotificationPayloadFromJson(
        Map<String, dynamic> json) =>
    _$_NotificationPayload(
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      alarmId: json['alarmId'] as int?,
    );

Map<String, dynamic> _$$_NotificationPayloadToJson(
        _$_NotificationPayload instance) =>
    <String, dynamic>{
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'alarmId': instance.alarmId,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.alarm: 'alarm',
  NotificationType.bedtime: 'bedtime',
};
