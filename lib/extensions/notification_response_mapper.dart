import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

extension NotificationResponseExt on NotificationResponse {
  Map<String, dynamic> toJson() => {
        'notificationResponseType': notificationResponseType.name,
        'id': id,
        'actionId': actionId,
        'input': input,
        'payload': payload,
      };

  String serialize() => jsonEncode(toJson());

  static NotificationResponse deserialize(String jsonString) {
    final map = jsonDecode(jsonString);
    final type = NotificationResponseType.values.firstWhere(
        (element) => element.name == map['notificationResponseType']);

    return NotificationResponse(
      notificationResponseType: type,
      id: map['id'],
      actionId: map['actionId'],
      input: map['input'],
      payload: map['payload'],
    );
  }
}
