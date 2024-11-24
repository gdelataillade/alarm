import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter/services.dart';

/// Handlers for parsing runtime exceptions as an AlarmException.
extension AlarmExceptionHandlers on AlarmException {
  /// Wraps a PlatformException within an AlarmException.
  static AlarmException fromPlatformException(PlatformException ex) {
    return AlarmException(
      ex.code == 'channel-error'
          ? AlarmErrorCode.channelError
          : AlarmErrorCode.values.firstWhere(
              (e) => e.index == (int.tryParse(ex.code) ?? 0),
              orElse: () => AlarmErrorCode.unknown,
            ),
      message: ex.message,
      stacktrace: ex.stacktrace,
    );
  }

  /// Wraps a Exception within an AlarmException.
  static AlarmException fromException(
    Exception ex, [
    StackTrace? stacktrace,
  ]) {
    return AlarmException(
      AlarmErrorCode.unknown,
      message: ex.toString(),
      stacktrace: stacktrace?.toString() ?? StackTrace.current.toString(),
    );
  }

  /// Wraps a dynamic error within an AlarmException.
  static AlarmException fromError(
    dynamic error, [
    StackTrace? stacktrace,
  ]) {
    if (error is AlarmException) {
      return error;
    }
    if (error is PlatformException) {
      return fromPlatformException(error);
    }
    if (error is Exception) {
      return fromException(error, stacktrace);
    }
    return AlarmException(
      AlarmErrorCode.unknown,
      message: error.toString(),
      stacktrace: stacktrace?.toString() ?? StackTrace.current.toString(),
    );
  }

  /// Utility method that can be used for wrapping errors thrown by Futures
  /// in an AlarmException.
  static T catchError<T>(dynamic error, StackTrace stacktrace) {
    throw fromError(error, stacktrace);
  }
}
