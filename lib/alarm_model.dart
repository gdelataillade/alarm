///  This code creates a class called AlarmModel that has fields for an alarm time, an audio asset path, a loop audio boolean,
///  and notification title and body.
///  It also contains functions to copy the model with new values and to convert it to and from JSON.
class AlarmModel {
  final DateTime alarmDateTime;
  final String assetAudioPath;
  final bool loopAudio;
  final String? notifTitle;
  final String? notifBody;

  AlarmModel({
    required this.alarmDateTime,
    required this.assetAudioPath,
    this.loopAudio = false,
    this.notifTitle = 'This is the title',
    this.notifBody = 'This is the body',
  });

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  AlarmModel copyWith({
    required DateTime alarmDateTime,
    required String assetAudioPath,
    required bool loopAudio,
    String? notifTitle,
    String? notifBody,
  }) {
    return AlarmModel(
      alarmDateTime: alarmDateTime,
      assetAudioPath: assetAudioPath,
      loopAudio: loopAudio,
      notifTitle: notifTitle,
      notifBody: notifBody,
    );
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) => AlarmModel(
        alarmDateTime: DateTime.fromMicrosecondsSinceEpoch(
            int.parse(json['alarmDateTime'])),
        assetAudioPath: json['assetAudioPath'] as String,
        notifTitle: json['notifTitle'] as String,
        notifBody: json['notifBody'] as String,
        loopAudio: json['loopAudio'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'alarmDateTime': alarmDateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'notifTitle': notifTitle,
        'notifBody': notifBody,
        'loopAudio': loopAudio,
      };
}
