import 'package:flutter/foundation.dart';

class AlarmSettings {
  /// Unique identifier assiocated with the alarm.
  final int id;

  /// Date and time when the alarm will be triggered.
  final DateTime dateTime;

  /// Path to audio asset to be used as the alarm ringtone. Accepted formats:
  ///
  /// * Project asset: `assets/your_audio.mp3`.
  ///
  /// * Local asset: `/path/to/your/audio.mp3`, which is your `File.path`.
  ///
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

  /// If true, set system volume to maximum when [dateTime] is reached
  /// and set it back to its previous value when alarm is stopped.
  /// Else, use current system volume. Enabled by default.
  final bool volumeMax;

  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  final double fadeDuration;

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

  /// Date and time when a notification will be triggered to notify the user
  /// that it's time to go to bed.
  final DateTime? bedtime;

  /// Title of the notification to be shown when it's time for [bedtime].
  final String? bedtimeNotificationTitle;

  /// Body of the notification to be shown when it's time for [bedtime].
  final String? bedtimeNotificationBody;

  /// Whether to present an action button in the notification for `snooze'.
  final bool? snooze;

  /// The amount of time to wait before retrigging another alarm when snoozed.
  final Duration snoozeDuration;

  /// The label for the action button in the notification for `snooze`.
  final String? notificationActionSnoozeLabel;

  /// Additional data to pass around.
  final Map<String, dynamic>? extra;

  /// Returns a hash code for this `AlarmSettings` instance using Jenkins hash function.
  @override
  int get hashCode {
    var hash = 0;

    hash = hash ^ id.hashCode;
    hash = hash ^ dateTime.hashCode;
    hash = hash ^ assetAudioPath.hashCode;
    hash = hash ^ loopAudio.hashCode;
    hash = hash ^ vibrate.hashCode;
    hash = hash ^ volumeMax.hashCode;
    hash = hash ^ fadeDuration.hashCode;
    hash = hash ^ (notificationTitle?.hashCode ?? 0);
    hash = hash ^ (notificationBody?.hashCode ?? 0);
    hash = hash ^ enableNotificationOnKill.hashCode;
    hash = hash ^ stopOnNotificationOpen.hashCode;
    hash = hash ^ (bedtime?.hashCode ?? 0);
    hash = hash ^ (bedtimeNotificationTitle?.hashCode ?? 0);
    hash = hash ^ (bedtimeNotificationBody?.hashCode ?? 0);
    hash = hash ^ (snooze?.hashCode ?? 0);
    hash = hash ^ snoozeDuration.hashCode;
    hash = hash ^ (notificationActionSnoozeLabel?.hashCode ?? 0);
    hash = hash ^ (extra?.hashCode ?? 0);
    hash = hash & 0x3fffffff;

    return hash;
  }

  /// Model that contains all the settings to customize and set an alarm.
  ///
  ///
  /// Note that if you want to show a notification when alarm is triggered,
  /// both [notificationTitle] and [notificationBody] must not be null nor empty.
  const AlarmSettings({
    required this.id,
    required this.dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    this.vibrate = true,
    this.volumeMax = true,
    this.fadeDuration = 0.0,
    this.snoozeDuration = const Duration(minutes: 5),
    this.notificationTitle,
    this.notificationBody,
    this.enableNotificationOnKill = true,
    this.stopOnNotificationOpen = true,
    this.bedtime,
    this.bedtimeNotificationTitle,
    this.bedtimeNotificationBody,
    this.snooze,
    this.notificationActionSnoozeLabel,
    this.extra,
  });

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        id: json['id'] as int,
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        vibrate: json['vibrate'] != null ? json['vibrate'] as bool : true,
        volumeMax: json['volumeMax'] != null ? json['volumeMax'] as bool : true,
        fadeDuration: json['fadeDuration'] as double,
        notificationTitle: json['notificationTitle'] as String?,
        notificationBody: json['notificationBody'] as String?,
        enableNotificationOnKill: json['enableNotificationOnKill'] as bool,
        stopOnNotificationOpen: json['stopOnNotificationOpen'] as bool,
        bedtime: json['bedtime'] != null
            ? DateTime.fromMicrosecondsSinceEpoch(json['bedtime'] as int)
            : null,
        bedtimeNotificationTitle: json['bedtimeNotificationTitle'] as String?,
        bedtimeNotificationBody: json['bedtimeNotificationBody'] as String?,
        snooze: json['snooze'] as bool?,
        snoozeDuration: Duration(seconds: json['snoozeDuration']),
        notificationActionSnoozeLabel:
            json['notificationActionSnoozeLabel'] as String?,
        extra: json['extra'] as Map<String, dynamic>?,
      );

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith({
    int? id,
    DateTime? dateTime,
    String? assetAudioPath,
    bool? loopAudio,
    bool? vibrate,
    bool? volumeMax,
    double? fadeDuration,
    String? notificationTitle,
    String? notificationBody,
    bool? enableNotificationOnKill,
    bool? stopOnNotificationOpen,
    DateTime? bedtime,
    String? bedtimeNotificationTitle,
    String? bedtimeNotificationBody,
    bool? snooze,
    Duration? snoozeDuration,
    String? notificationActionSnoozeLabel,
    Map<String, dynamic>? extra,
  }) {
    return AlarmSettings(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      volumeMax: volumeMax ?? this.volumeMax,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      enableNotificationOnKill:
          enableNotificationOnKill ?? this.enableNotificationOnKill,
      stopOnNotificationOpen:
          stopOnNotificationOpen ?? this.stopOnNotificationOpen,
      bedtime: bedtime ?? this.bedtime,
      bedtimeNotificationTitle:
          bedtimeNotificationTitle ?? this.bedtimeNotificationTitle,
      bedtimeNotificationBody:
          bedtimeNotificationBody ?? this.bedtimeNotificationBody,
      snooze: snooze ?? this.snooze,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      notificationActionSnoozeLabel:
          notificationActionSnoozeLabel ?? this.notificationActionSnoozeLabel,
      extra: extra ?? this.extra,
    );
  }

  /// Converts this `AlarmSettings` instance to JSON data.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'volumeMax': volumeMax,
        'fadeDuration': fadeDuration,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'enableNotificationOnKill': enableNotificationOnKill,
        'stopOnNotificationOpen': stopOnNotificationOpen,
        'bedtime': bedtime?.microsecondsSinceEpoch,
        'bedtimeNotificationTitle': bedtimeNotificationTitle,
        'bedtimeNotificationBody': bedtimeNotificationBody,
        'snooze': snooze,
        'snoozeDuration': snoozeDuration.inSeconds,
        'notificationActionSnoozeLabel': notificationActionSnoozeLabel,
        'extra': extra,
      };

  /// Returns all the properties of `AlarmSettings` for debug purposes.
  @override
  String toString() {
    Map<String, dynamic> json = toJson();
    json['dateTime'] = DateTime.fromMicrosecondsSinceEpoch(json['dateTime']);
    json['bedtime'] = json['bedtime'] != null
        ? DateTime.fromMicrosecondsSinceEpoch(json['bedtime'])
        : null;
    json['snoozeDuration'] = Duration(seconds: json['snoozeDuration']);

    return "AlarmSettings: ${json.toString()}";
  }

  /// Compares two AlarmSettings.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dateTime == other.dateTime &&
          assetAudioPath == other.assetAudioPath &&
          loopAudio == other.loopAudio &&
          vibrate == other.vibrate &&
          volumeMax == other.volumeMax &&
          fadeDuration == other.fadeDuration &&
          notificationTitle == other.notificationTitle &&
          notificationBody == other.notificationBody &&
          enableNotificationOnKill == other.enableNotificationOnKill &&
          stopOnNotificationOpen == other.stopOnNotificationOpen &&
          bedtime == other.bedtime &&
          bedtimeNotificationTitle == other.bedtimeNotificationTitle &&
          bedtimeNotificationBody == other.bedtimeNotificationBody &&
          snooze == other.snooze &&
          snoozeDuration == other.snoozeDuration &&
          notificationActionSnoozeLabel ==
              other.notificationActionSnoozeLabel &&
          mapEquals(extra, other.extra);
}
