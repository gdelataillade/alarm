/// Extensions on [DateTime].
extension DateTimeExtension on DateTime {
  /// Whether two [DateTime] fall within the same second.
  ///
  /// Compared on the absolute timeline (epoch seconds) so that UTC and
  /// local instances representing different instants are never considered
  /// equal, regardless of their wall-clock components.
  bool isSameSecond(DateTime other) =>
      millisecondsSinceEpoch ~/ 1000 == other.millisecondsSinceEpoch ~/ 1000;
}
