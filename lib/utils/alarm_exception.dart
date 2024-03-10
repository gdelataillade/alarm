/// Custom exception for the alarm.
class AlarmException implements Exception {
  /// Creates an [AlarmException] with the given error [message].
  const AlarmException(this.message);

  /// Exception message.
  final String message;

  @override
  String toString() => message;
}
