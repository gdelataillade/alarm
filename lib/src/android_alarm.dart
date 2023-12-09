import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:flutter/services.dart';

/// Uses method channel to interact with the native platform.
class AndroidAlarm {
  static const platform = MethodChannel('com.gdelataillade.alarm/alarm');

  static bool get hasOtherAlarms => AlarmStorage.getSavedAlarms().length > 1;

  static Future<void> init() async {
    platform.setMethodCallHandler(handleMethodCall);
  }

  static Future<dynamic> handleMethodCall(MethodCall call) async {
    try {
      if (call.method == 'alarmRinging') {
        int id = call.arguments['id'];
        final settings = Alarm.getAlarm(id);
        if (settings != null) Alarm.ringStream.add(settings);
      }
    } catch (e) {
      alarmPrint('[DEV] Handle method call "${call.method}" error: $e');
    }
  }

  /// Schedules a native alarm with given [alarmSettings] with its notification.
  static Future<bool> set(
    AlarmSettings settings,
    void Function()? onRing,
  ) async {
    try {
      final delay = settings.dateTime.difference(DateTime.now());

      await platform.invokeMethod(
        'setAlarm',
        {
          'id': settings.id,
          'delayInSeconds': delay.inSeconds,
          'assetAudioPath': settings.assetAudioPath,
          'loopAudio': settings.loopAudio,
          'vibrate': settings.vibrate,
          'systemVolume': settings.systemVolume,
          'fadeDuration': settings.fadeDuration,
          'notificationTitle': settings.notificationTitle,
          'notificationBody': settings.notificationBody,
          'fullScreenIntent': settings.androidFullScreenIntent,
        },
      );

      if (!success) {
        IsolateNameServer.removePortNameMapping("$ringPort-$id");
        IsolateNameServer.registerPortWithName(port.sendPort, "$ringPort-$id");
      }
      port.listen((message) {
        alarmPrint('$message');
        if (message == 'ring') {
          ringing = true;
          if (settings.systemVolume != null) {
            setSystemVolume(settings.systemVolume!);
          }
          onRing?.call();
        } else {
          if (settings.vibrate &&
              message is String &&
              message.startsWith('vibrate')) {
            final audioDuration = message.split('-').last;

            if (int.tryParse(audioDuration) != null) {
              final duration = Duration(seconds: int.parse(audioDuration));
              triggerVibrations(duration: settings.loopAudio ? null : duration);
            }
          }
        }
      });
    } catch (e) {
      throw AlarmException('nativeAndroidAlarm error: $e');
    }

    if (settings.dateTime.difference(DateTime.now()).inSeconds <= 1) {
      await playAlarm(id, {
        "assetAudioPath": settings.assetAudioPath,
        "loopAudio": settings.loopAudio,
        "fadeDuration": settings.fadeDuration,
        "audioVolume": settings.audioVolume,
      });
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
      params: {
        'assetAudioPath': settings.assetAudioPath,
        'loopAudio': settings.loopAudio,
        'fadeDuration': settings.fadeDuration,
        'audioVolume': settings.audioVolume,
      },
    );

    alarmPrint(
      'Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at ${settings.dateTime}',
    );

    if (settings.enableNotificationOnKill && !hasOtherAlarms) {
      try {
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': AlarmStorage.getNotificationOnAppKillTitle(),
            'body': AlarmStorage.getNotificationOnAppKillBody(),
          },
        );
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

      final loopAudio = data['loopAudio'] as bool;
      if (loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      send.send('Alarm data received in isolate: $data');

      final fadeDuration = data['fadeDuration'];
      final audioVolume = min((data['audioVolume'] * 1.0) as double, 1.0);

      send.send('Alarm fadeDuration: $fadeDuration seconds');

      if (fadeDuration > 0.0) {
        int counter = 0;

        audioPlayer.setVolume(0.1);
        audioPlayer.play();

        send.send('Alarm playing with fadeDuration ${fadeDuration}s');

        Timer.periodic(
          Duration(milliseconds: fadeDuration * 1000 ~/ 10),
          (timer) {
            counter++;
            final newVolume = min(audioVolume, counter / 10);
            audioPlayer.setVolume(newVolume);
            if (newVolume >= audioVolume || counter >= 10) timer.cancel();
          },
        );
      } else {
        audioPlayer.setVolume(audioVolume);
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
        final op = message['op'] as String;
        if (op == 'stop') {
          await audioPlayer.stop();
          await audioPlayer.dispose();
          port.close();
        } else if (op == 'setAudioVolume') {
          final audioVolume = message['audioVolume'] as double;
          audioPlayer.setVolume(audioVolume);
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

  /// Sets the device systemVolume to [systemVolume].
  static Future<void> setSystemVolume(double systemVolume) async {
    previousVolume = await VolumeController().getVolume();
    VolumeController().setVolume(systemVolume, showSystemUI: true);
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    ringing = false;
    vibrationsActive = false;

    final send = IsolateNameServer.lookupPortByName(stopPort);

    if (send != null) {
      send.send({'op': 'stop'});
      alarmPrint('Alarm with id $id stopped');
    }

    if (previousVolume != null) {
      VolumeController().setVolume(previousVolume!, showSystemUI: true);
      previousVolume = null;
    }

    if (!hasOtherAlarms) stopNotificationOnKillService();
    return res;
  }

  /// Checks if the alarm with given [id] is ringing.
  static Future<bool> isRinging(int id) async {
    final res = await platform.invokeMethod('isRinging', {'id': id});
    return res;
  }

  static bool setVibrate(bool vibrate) {
    if (isRinging && !vibrationsActive && vibrate) {
      triggerVibrations(duration: null);
    }
    vibrationsActive = vibrate;
    alarmPrint('Alarm vibrate set to $vibrate');
    return true;
  }

  static setAudioVolume(int id, double audioVolume) {
    final send = IsolateNameServer.lookupPortByName(stopPort);

    if (send != null) {
      send.send({'op': 'stop', 'audioVolume': audioVolume});
      alarmPrint('Alarm with id $id volume set to $audioVolume');
    }

    return true;
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
