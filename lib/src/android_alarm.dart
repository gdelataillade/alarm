import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';

/// For Android support, [AndroidAlarmManager] is used to trigger a callback
/// when the given time is reached. The callback will run in an isolate if app
/// is in background.
class AndroidAlarm {
  static const ringPort = 'alarm-ring';

  static const platform =
      MethodChannel('com.gdelataillade.alarm/notifOnAppKill');

  static AudioPlayer audioPlayer = AudioPlayer();
  static bool ringing = false;
  static bool vibrationsActive = false;
  static double? previousVolume;

  static bool get isRinging => ringing;
  static bool get hasOtherAlarms => AlarmStorage.getSavedAlarms().length > 1;

  /// Initializes AndroidAlarmManager dependency.
  static Future<void> init() => AndroidAlarmManager.initialize();

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(
    AlarmSettings settings,
    void Function()? onRing,
  ) async {
    final id = settings.id;
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
        if (message == 'ring') {
          ringAlarm(settings);
          onRing?.call();
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }

    if (settings.dateTime.difference(DateTime.now()).inSeconds <= 1) {
      await ringAlarm(settings);
      return true;
    }

    final res = await AndroidAlarmManager.oneShotAt(
      settings.dateTime,
      id,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      wakeup: true,
    );

    alarmPrint(
      'Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at ${settings.dateTime}',
    );

    if (settings.enableNotificationOnKill && !hasOtherAlarms) {
      enableNotificationOnKill();
    }

    return res;
  }

  static Future<void> ringAlarm(AlarmSettings settings) async {
    ringing = true;

    if (settings.volumeMax) setMaximumVolume();

    try {
      Duration? audioDuration;

      if (settings.assetAudioPath.startsWith('http')) {
        throw const AlarmException(
          'Network URLs are not supported. Please provide local asset.',
        );
      }

      audioDuration = settings.assetAudioPath.startsWith('assets/')
          ? await audioPlayer.setAsset(settings.assetAudioPath)
          : await audioPlayer.setFilePath(settings.assetAudioPath);

      triggerVibrations(duration: audioDuration);

      if (settings.loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      if (settings.fadeDuration > 0.0) {
        int counter = 0;

        await audioPlayer.setVolume(0.1);
        audioPlayer.play();

        Timer.periodic(
          Duration(milliseconds: settings.fadeDuration * 1000 ~/ 10),
          (timer) {
            counter++;
            audioPlayer.setVolume(counter / 10);
            if (counter >= 10) timer.cancel();
          },
        );
      } else {
        audioPlayer.play();
      }
    } catch (e) {
      await AudioPlayer.clearAssetCache();
      throw AlarmException(
        "Alarm with id ${settings.id} and asset path '${settings.assetAudioPath}' error: $e",
      );
    }
  }

  /// Callback triggered when [dateTime] is reached.
  /// The message `ring` is sent to the main thread in order to
  /// tell the device that the alarm is starting to ring.
  @pragma('vm:entry-point')
  static Future<void> playAlarm(int id, Map<String, dynamic> data) async {
    final sendPort = IsolateNameServer.lookupPortByName("$ringPort-$id");
    if (sendPort == null) throw const AlarmException('Isolate port not found');
    sendPort.send('ring');
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

  /// Sets the device volume to the maximum.
  static Future<void> setMaximumVolume() async {
    previousVolume = await VolumeController().getVolume();
    VolumeController().setVolume(1.0, showSystemUI: true);
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    ringing = false;
    vibrationsActive = false;

    await audioPlayer.stop();
    await audioPlayer.dispose();

    if (previousVolume != null) {
      VolumeController().setVolume(previousVolume!, showSystemUI: true);
      previousVolume = null;
    }

    if (!hasOtherAlarms) disableNotificationOnKillService();

    return await AndroidAlarmManager.cancel(id);
  }

  /// Enables the notification on kill service.
  static Future<void> enableNotificationOnKill() async {
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

  /// Disables the notification on kill service.
  static Future<void> disableNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      alarmPrint('NotificationOnKillService stopped with success');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
