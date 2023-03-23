class AlarmSettings {
  final int id;
  final DateTime dateTime;
  final String assetAudioPath;
  final bool loopAudio;
  final bool vibrate;
  final double fadeDuration;
  final String? notificationTitle;
  final String? notificationBody;
  final bool enableNotificationOnKill;

  /// Model that contains all the settings to customize and set an alarm
  /// with a given [id].
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
    required this.id,
    required this.dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    this.vibrate = true,
    this.fadeDuration = 0.0,
    this.notificationTitle,
    this.notificationBody,
    this.enableNotificationOnKill = true,
  });

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith({
    DateTime? dateTime,
    String? assetAudioPath,
    bool? loopAudio,
    bool? vibrate,
    double? fadeDuration,
    String? notificationTitle,
    String? notificationBody,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
    );
  }

  /// Converts json data to an `AlarmSettings`
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        id: json['id'] as int,
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        vibrate: json['vibrate'] as bool,
        fadeDuration: json['fadeDuration'] as double,
        notificationTitle: json['notificationTitle'] as String?,
        notificationBody: json['notificationBody'] as String?,
      );

  /// Converts an `AlarmSettings` to json data.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'fadeDuration': fadeDuration,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
      };

  /// Returns all the properties of `AlarmSettings` for debug purposes.
  @override
  String toString() {
    Map<String, dynamic> json = toJson();
    json['dateTime'] = DateTime.fromMicrosecondsSinceEpoch(json['dateTime']);
    return "AlarmSettings: ${json.toString()}";
  }
}
