import 'dart:async';
import 'package:flutter/services.dart';

enum FGBGType {
  foreground,
  background,
}

/// Handles foreground/background events.
class FGBGEvents {
  static const _channel = EventChannel("com.gdelataillade.alarm/fgbg_events");
  static Stream<FGBGType>? _stream;

  static Stream<FGBGType> get stream {
    return _stream ??= _channel.receiveBroadcastStream().map(
        (e) => e == "foreground" ? FGBGType.foreground : FGBGType.background);
  }
}
