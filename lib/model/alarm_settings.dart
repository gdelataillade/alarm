class AlarmSettings {
  final DateTime dateTime;
  final String assetAudioPath;
  final bool loopAudio;
  final String notificationTitle;
  final String notificationBody;

  /// Model that contains all the settings to customize and set an alarm.
  ///
  /// [onRing] will be called when alarm is triggered at [dateTime].
  ///
  /// [assetAudio] is the audio asset you want to use as the alarm ringtone.
  /// For iOS, you need to drag and drop your asset(s) to your `Runner` folder
  /// in Xcode and make sure 'Copy items if needed' is checked.
  /// Can also be an URL.
  ///
  /// If [loopAudio] is set to true, [assetAudio] will repeat indefinitely
  /// until it is stopped. Default value is false.
  ///
  /// If you want to show a notification when alarm is triggered,
  /// [notifTitle] and [notifBody] must not be empty.
  AlarmSettings({
    required this.dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    required this.notificationTitle,
    required this.notificationBody,
  });

  /// Creates a copy of AlarmSettings but with the given fields replaced with the
  /// new values.
  AlarmSettings copyWith({
    required DateTime dateTime,
    required String assetAudioPath,
    required bool loopAudio,
    String notifTitle = 'This is the title',
    String notifBody = 'This is the body',
  }) {
    return AlarmSettings(
      dateTime: dateTime,
      assetAudioPath: assetAudioPath,
      loopAudio: loopAudio,
      notificationTitle: notifTitle,
      notificationBody: notifBody,
    );
  }

  /// Converts json data to an AlarmSettings
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        notificationTitle: json['notifTitle'] as String,
        notificationBody: json['notifBody'] as String,
        loopAudio: json['loopAudio'] as bool,
      );

  /// Converts an AlarmSettings to json data
  Map<String, dynamic> toJson() => {
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'notifTitle': notificationTitle,
        'notifBody': notificationBody,
        'loopAudio': loopAudio,
      };
}
