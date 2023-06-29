import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

/// For Android support, [AndroidAlarmManager] is used to set an alarm
/// and trigger a callback when the given time is reached.
class AndroidAlarm {
  static const ringPort = 'alarm-ring';
  static const stopPort = 'alarm-stop';

  static const platform =
      MethodChannel('com.gdelataillade.alarm/notifOnAppKill');

  static bool vibrationsActive = false;

  static bool get hasOtherAlarms => AlarmStorage.getSavedAlarms().length > 1;

  /// Initializes AndroidAlarmManager dependency.
  static Future<void> init() => AndroidAlarmManager.initialize();

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(
    int id,
    DateTime dateTime,
    void Function()? onRing,
    String assetAudioPath,
    bool loopAudio,
    bool vibrate,
    double fadeDuration,
    bool enableNotificationOnKill,
  ) async {
    try {
      final port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        "$ringPort-$id",
      );

      if (!success) {
        IsolateNameServer.removePortNameMapping("$ringPort-$id");
        IsolateNameServer.registerPortWithName(port.sendPort, "$ringPort-$id");
      }
      port.listen((message) {
        alarmPrint('$message');
        if (message == 'ring') {
          onRing?.call();
        } else {
          if (vibrate && message is String && message.startsWith('vibrate')) {
            final audioDuration = message.split('-').last;

            if (int.tryParse(audioDuration) != null) {
              final duration = Duration(seconds: int.parse(audioDuration));
              triggerVibrations(duration: loopAudio ? null : duration);
            }
          }
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }

    final res = await AndroidAlarmManager.oneShotAt(
      dateTime,
      id,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      params: {
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'fadeDuration': fadeDuration,
      },
    );

    alarmPrint(
      'Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at $dateTime',
    );

    if (enableNotificationOnKill && !hasOtherAlarms) {
      try {
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': AlarmStorage.getNotificationOnAppKillTitle(),
            'description': AlarmStorage.getNotificationOnAppKillBody(),
          },
        );
        alarmPrint('NotificationOnKillService set with success');
      } catch (e) {
        throw AlarmException('NotificationOnKillService error: $e');
      }
    }

    return res;
  }

  /// Callback triggered when alarmDateTime is reached.
  /// The message `ring` is sent to the main thread in order to
  /// tell the device that the alarm is starting to ring.
  /// Alarm is played with AudioPlayer and stopped when the message `stop`
  /// is received from the main thread.
  @pragma('vm:entry-point')
  static Future<void> playAlarm(int id, Map<String, dynamic> data) async {
    final audioPlayer = AudioPlayer();

    final res = IsolateNameServer.lookupPortByName("$ringPort-$id");
    if (res == null) throw const AlarmException('Isolate port not found');

    final send = res;
    send.send('ring');

    try {
      final assetAudioPath = data['assetAudioPath'] as String;
      Duration? audioDuration;

      if (assetAudioPath.startsWith('http')) {
        send.send('Network URL not supported. Please provide local asset.');
        return;
      }

      audioDuration = assetAudioPath.startsWith('assets/')
          ? await audioPlayer.setAsset(assetAudioPath)
          : await audioPlayer.setFilePath(assetAudioPath);

      send.send('vibrate-${audioDuration?.inSeconds}');

      final loopAudio = data['loopAudio'];
      if (loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      send.send('Alarm fadeDuration: ${data.toString()}');

      final fadeDuration = (data['fadeDuration'] as int).toDouble();

      if (fadeDuration > 0.0) {
        int counter = 0;

        audioPlayer.setVolume(0.1);
        audioPlayer.play();

        send.send('Alarm playing with fadeDuration ${fadeDuration}s');

        Timer.periodic(
          Duration(milliseconds: fadeDuration * 1000 ~/ 10),
          (timer) {
            counter++;
            audioPlayer.setVolume(counter / 10);
            if (counter >= 10) timer.cancel();
          },
        );
      } else {
        audioPlayer.play();
        send.send('Alarm with id $id starts playing.');
      }
    } catch (e) {
      await AudioPlayer.clearAssetCache();
      send.send('Asset cache reset. Please try again.');
      throw AlarmException(
        "Alarm with id $id and asset path '${data['assetAudioPath']}' error: $e",
      );
    }

    try {
      final port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, stopPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(stopPort);
        IsolateNameServer.registerPortWithName(port.sendPort, stopPort);
      }

      port.listen((message) async {
        send.send('(isolate) received: $message');
        if (message == 'stop') {
          await audioPlayer.stop();
          await audioPlayer.dispose();
          port.close();
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }
  }

  /// Triggers vibrations when alarm is ringing if [vibrationsActive] is true.
  ///
  /// If [loopAudio] is false, vibrations are triggered repeatedly during
  /// [duration] which is the duration of the audio.
  static Future<void> triggerVibrations({Duration? duration}) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;

    if (!hasVibrator) {
      alarmPrint('Vibrations are not available on this device.');
      return;
    }

    vibrationsActive = true;

    if (duration == null) {
      while (vibrationsActive) {
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } else {
      final endTime = DateTime.now().add(duration);
      while (vibrationsActive && DateTime.now().isBefore(endTime)) {
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    vibrationsActive = false;

    final send = IsolateNameServer.lookupPortByName(stopPort);

    if (send != null) {
      send.send('stop');
      alarmPrint('Alarm with id $id stopped');
    }

    if (!hasOtherAlarms) stopNotificationOnKillService();

    return await AndroidAlarmManager.cancel(id);
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      alarmPrint('NotificationOnKillService stopped with success');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
