import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

/// Sets up the logging system.
void setupLogging({required bool showDebugLogs}) {
  if (showDebugLogs) {
    EquatableConfig.stringify = true;
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  } else {
    Logger.root.level = Level.SEVERE;
  }

  final formatter = DateFormat('HH:mm:ss.SSS');

  Logger.root.onRecord.listen((record) {
    debugPrint('\x1B${record.level.colorCode()}'
        '[${record.level.name.substring(0, 1)}] '
        '${formatter.format(record.time)}: '
        '[${record.loggerName}] ${record.message}'
        '\x1B[0m');
    if (record.error != null) {
      debugPrint('Error object: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrintStack(stackTrace: record.stackTrace);
    }
  });
}

extension _LoggerLevelColor on Level {
  String colorCode() {
    switch (this) {
      case Level.FINEST:
      case Level.FINER:
      case Level.FINE:
      case Level.CONFIG:
      case Level.INFO:
        return '[0m';
      case Level.WARNING:
        return '[32m';
      case Level.SEVERE:
      case Level.SHOUT:
        return '[31m';
      default:
        return '[0m';
    }
  }
}
