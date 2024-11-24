import 'package:alarm/src/generated/platform_bindings.g.dart';

/// Custom exception for the alarm.
class AlarmException implements Exception {
  /// Creates an [AlarmException] with the given error [message].
  const AlarmException(this.code, {this.message, this.stacktrace});

  /// The type/category of error.
  final AlarmErrorCode code;

  /// Exception message.
  final String? message;

  /// The Stacktrace when the exception occured.
  final String? stacktrace;

  @override
  String toString() =>
      '${code.name}: $message${stacktrace != null ? '\n$stacktrace' : ''}';
}
