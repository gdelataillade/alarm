import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/service/storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

/// For Android support, [AndroidAlarmManager] is used to set an alarm
/// and trigger a callback when the given time is reached.
class AndroidAlarm {
  static String ringPort = 'alarm-ring';
  static String stopPort = 'alarm-stop';

  /// Initializes AndroidAlarmManager dependency.
  static Future<void> init() => AndroidAlarmManager.initialize();

  static const platform =
      MethodChannel('com.gdelataillade.alarm/notifOnAppKill');

  static bool vibrationsActive = false;

  static bool get hasAnotherAlarm => AlarmStorage.getSavedAlarms().length > 1;

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(
    int id,
    DateTime dateTime,
    void Function()? onRing,
    String assetAudioPath,
    bool loopAudio,
    bool vibrate,
    double fadeDuration,
    String? notificationTitle,
    String? notificationBody,
    bool enableNotificationOnKill,
  ) async {
    try {
      final ReceivePort port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        "$ringPort-$id",
      );

      if (!success) {
        IsolateNameServer.removePortNameMapping("$ringPort-$id");
        IsolateNameServer.registerPortWithName(port.sendPort, "$ringPort-$id");
      }
      port.listen((message) {
        debugPrint('$message');
        if (message == 'ring') {
          if (vibrate) triggerVibrations();
          onRing?.call();
        }
      });
    } catch (e) {
      debugPrint('ReceivePort error: $e');
      return false;
    }

    if (enableNotificationOnKill && !hasAnotherAlarm) {
      try {
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': AlarmStorage.getNotificationOnAppKillTitle(),
            'description': AlarmStorage.getNotificationOnAppKillBody(),
          },
        );
        debugPrint('NotificationOnKillService set with success');
      } catch (e) {
        debugPrint('NotificationOnKillService error: $e');
      }
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
    SendPort send = IsolateNameServer.lookupPortByName("$ringPort-$id")!;

    send.send('ring');

    try {
      final assetAudioPath = data['assetAudioPath'] as String;

      if (assetAudioPath.startsWith('http')) {
        await audioPlayer.setUrl(assetAudioPath);
      } else {
        await audioPlayer.setAsset(assetAudioPath);
      }

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
      send.send('AudioPlayer with id $id error: ${e.toString()}');
      await AudioPlayer.clearAssetCache();
      send.send('Asset cache reset. Please try again.');
    }

    try {
      final ReceivePort port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, stopPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(stopPort);
        IsolateNameServer.registerPortWithName(port.sendPort, stopPort);
      }

      port.listen(
        (message) async {
          send.send('(isolate) received: $message');
          if (message == 'stop') {
            await audioPlayer.stop();
            await audioPlayer.dispose();
            port.close();
          }
        },
      );
    } catch (e) {
      send.send('(isolate) ReceivePort error: $e');
    }
  }

  /// Triggers vibrations when alarm is ringing if [vibrationsActive] is true.
  static Future<void> triggerVibrations() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;

    if (!hasVibrator) {
      debugPrint('Vibrations are not available on this device.');
      return;
    }

    vibrationsActive = true;

    while (vibrationsActive) {
      Vibration.vibrate();
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  /// Sends the message `stop` to the isolate so the audio player.
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    vibrationsActive = false;

    try {
      final SendPort? send = IsolateNameServer.lookupPortByName(stopPort);
      send?.send('stop');
    } catch (e) {
      debugPrint('(main) SendPort error: $e');
    }

    if (!hasAnotherAlarm) stopNotificationOnKillService();

    final res = await AndroidAlarmManager.cancel(id);

    return res;
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      debugPrint('NotificationOnKillService stopped with success');
    } catch (e) {
      debugPrint('NotificationOnKillService error: $e');
    }
  }
}
