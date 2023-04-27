class AlarmSettings {
  /// Model that contains all the settings to customize and set an alarm.
  ///
  ///
  /// Note that if you want to show a notification when alarm is triggered,
  /// both [notificationTitle] and [notificationBody] must not be null nor empty.
  AlarmSettings({
    required this.id,
    required this.dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    this.vibrate = true,
    this.fadeDuration = 0.0,
    this.notificationTimeZoneId = 'UTC',
    this.notificationTitle,
    this.notificationBody,
    this.enableNotificationOnKill = true,
    this.stopOnNotificationOpen = true,
  });

  /// Unique identifier assiocated with the alarm.
  final int id;

  /// Date and time when the alarm will be triggered.
  final DateTime dateTime;

  /// URL or path to audio asset to be used as the alarm ringtone.
  /// For iOS, you need to drag and drop your asset(s) to your `Runner` folder
  /// in Xcode and make sure 'Copy items if needed' is checked.
  /// Check out README.md for more informations.
  final String assetAudioPath;

  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  final bool loopAudio;

  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  final bool vibrate;

  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  final double fadeDuration;

  /// Time zone identifier to be used for the notification.
  /// The default value is `UTC`.
  final String notificationTimeZoneId;

  /// Title of the notification to be shown when alarm is triggered.
  /// Must not be null nor empty to show a notification.
  final String? notificationTitle;

  /// Body of the notification to be shown when alarm is triggered.
  /// Must not be null nor empty to show a notification.
  final String? notificationBody;

  /// Whether to show a notification when application is killed to warn
  /// the user that the alarms won't ring anymore. Enabled by default.
  final bool enableNotificationOnKill;

  /// Stops the alarm on opened notification.
  final bool stopOnNotificationOpen;

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith({
    DateTime? dateTime,
    String? assetAudioPath,
    bool? loopAudio,
    bool? vibrate,
    double? fadeDuration,
    String? notificationTimeZoneId,
    String? notificationTitle,
    String? notificationBody,
    bool? enableNotificationOnKill,
    bool? stopOnNotificationOpen,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      notificationTimeZoneId: notificationTimeZoneId ?? this.notificationTimeZoneId,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      enableNotificationOnKill: enableNotificationOnKill ?? this.enableNotificationOnKill,
      stopOnNotificationOpen: stopOnNotificationOpen ?? this.stopOnNotificationOpen,
    );
  }

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        id: json['id'] as int,
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        vibrate: json['vibrate'] as bool,
        fadeDuration: json['fadeDuration'] as double,
        notificationTimeZoneId: json['notificationTimeZoneId'] as String,
        notificationTitle: json['notificationTitle'] as String?,
        notificationBody: json['notificationBody'] as String?,
        enableNotificationOnKill: json['enableNotificationOnKill'] as bool,
        stopOnNotificationOpen: json['stopOnNotificationOpen'] as bool,
      );

  /// Converts this `AlarmSettings` instance to JSON data.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'fadeDuration': fadeDuration,
        'notificationTimeZoneId': notificationTimeZoneId,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'enableNotificationOnKill': enableNotificationOnKill,
        'stopOnNotificationOpen': stopOnNotificationOpen,
      };

  /// Returns all the properties of `AlarmSettings` for debug purposes.
  @override
  String toString() {
    Map<String, dynamic> json = toJson();
    json['dateTime'] = DateTime.fromMicrosecondsSinceEpoch(json['dateTime']);
    return "AlarmSettings: ${json.toString()}";
  }
}
