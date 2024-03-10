/// Extensions on [DateTime].
extension DateTimeExtension on DateTime {
  /// Whether two [DateTime] are the same second.
  bool isSameSecond(DateTime other) =>
      year == other.year &&
      month == other.month &&
      day == other.day &&
      hour == other.hour &&
      minute == other.minute &&
      second == other.second;
}
