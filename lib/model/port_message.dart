import 'dart:convert';

import 'package:alarm/extensions/notification_response_mapper.dart';
import 'package:alarm/model/message_type.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'port_message.freezed.dart';

@freezed
class PortMessage with _$PortMessage {
  // Private default constructor used by named constructors
  const factory PortMessage._({
    required MessageType type,
    String? message,
    NotificationResponse? notificationResponse,
  }) = _PortMessage;

  factory PortMessage.log(String message) {
    return PortMessage._(type: MessageType.log, message: message);
  }

  factory PortMessage.notification(NotificationResponse response) {
    return PortMessage._(
      type: MessageType.notification,
      notificationResponse: response,
    );
  }

  static PortMessage fromJson(Map<String, dynamic> json) => PortMessage._(
        type: MessageType.values.firstWhere((e) => e.name == json['type']),
        message: json['message'],
        notificationResponse: json['notificationResponse'] != null
            ? NotificationResponseExt.deserialize(json['notificationResponse'])
            : null,
      );

  static PortMessage deserialize(String serialized) =>
      PortMessage.fromJson(jsonDecode(serialized));
}

extension PortMessageExt on PortMessage {
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
        'notificationResponse': notificationResponse?.serialize(),
      };

  String serialize() => jsonEncode(toJson());
}
