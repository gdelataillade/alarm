class AlarmSettings {
  final DateTime dateTime;
  final String assetAudioPath;
  final bool loopAudio;
  final double fadeDuration;
  final String? notificationTitle;
  final String? notificationBody;
  final bool enableNotificationOnKill;

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
  /// [fadeDuration] is the duration, in seconds, over which to fade the volume.
  /// Set to 0 by default, which means no fade.
  ///
  /// If you want to show a notification when alarm is triggered,
  /// [notificationTitle] and [notificationBody] must not be null nor empty.
  AlarmSettings({
    required this.dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    this.fadeDuration = 0.0,
    this.notificationTitle,
    this.notificationBody,
    this.enableNotificationOnKill = true,
  });

  /// Creates a copy of AlarmSettings but with the given fields replaced with the
  /// new values.
  AlarmSettings copyWith({
    required DateTime dateTime,
    required String assetAudioPath,
    required bool loopAudio,
    required double fadeDuration,
    String? notificationTitle,
    String? notificationBody,
  }) {
    return AlarmSettings(
      dateTime: dateTime,
      assetAudioPath: assetAudioPath,
      loopAudio: loopAudio,
      fadeDuration: fadeDuration,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
    );
  }

  /// Converts json data to an AlarmSettings
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        fadeDuration: json['fadeDuration'] as double,
        notificationTitle: json['notificationTitle'] as String?,
        notificationBody: json['notificationBody'] as String?,
      );

  /// Converts an AlarmSettings to json data
  Map<String, dynamic> toJson() => {
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'fadeDuration': fadeDuration,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
      };
}
