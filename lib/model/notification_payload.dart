import 'dart:convert';

import 'package:alarm/model/notification_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_payload.freezed.dart';
part 'notification_payload.g.dart';

@freezed
class NotificationPayload with _$NotificationPayload {
  factory NotificationPayload({
    required NotificationType type,
    int? alarmId,
  }) = _NotificationPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);

  NotificationPayload._();

  String serialize() => jsonEncode(toJson());

  static NotificationPayload deserialize(String serialized) =>
      NotificationPayload.fromJson(jsonDecode(serialized));

  static NotificationPayload? tryDeserialize(String? serialized) {
    if (serialized == null) {
      return null;
    }

    try {
      return NotificationPayload.deserialize(serialized);
    } catch (_) {
      return null;
    }
  }
}
