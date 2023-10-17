import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/notification_type.dart';
import 'package:alarm/service/notification.dart';
import 'package:alarm/service/storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';

/// For Android support, [AndroidAlarmManager] is used to trigger a callback
/// when the given time is reached. The callback will run in an isolate if app
/// is in background.
class AndroidAlarm {
  static const ringPort = 'alarm-ring';
  static const stopPort = 'alarm-stop';

  static const platform =
      MethodChannel('com.gdelataillade.alarm/notifOnAppKill');

  static final _ringingBehavior = BehaviorSubject<AlarmSettings?>();
  static Stream<AlarmSettings?> get ringingStream => _ringingBehavior.stream;
  static AlarmSettings? get ringing => _ringingBehavior.valueOrNull;
  static set _ringing(AlarmSettings? value) => _ringingBehavior.add(value);

  static bool vibrationsActive = false;
  static double? previousVolume;

  static Future<bool> get hasOtherAlarms async =>
      (await AlarmStorage.getSavedAlarms()).length > 1;

  /// Initializes AndroidAlarmManager dependency.
  static Future<void> init() async {
    for (final settings in await AlarmStorage.getSavedAlarms()) {
      // Re-register ports after the app restarts
      _registerPort(settings);
    }
    await AndroidAlarmManager.initialize();
  }

  static void _registerPort(
    AlarmSettings settings, {
    bool registerIfTaken = false,
  }) {
    try {
      final port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        "$ringPort-${settings.id}",
      );

      if (!success) {
        // Port already registered
        if (!registerIfTaken) {
          return;
        }

        IsolateNameServer.removePortNameMapping("$ringPort-${settings.id}");
        IsolateNameServer.registerPortWithName(
            port.sendPort, "$ringPort-${settings.id}");
      }

      port.listen((message) {
        alarmPrint('$message');
        if (message == 'ring') {
          _ringing = settings;
          if (settings.volumeMax) setMaximumVolume();
          Alarm.ringStream.add(settings);
        } else if (message == 'clear') {
          _ringing = null;
          vibrationsActive = false;
        } else if (settings.vibrate &&
            message is String &&
            message.startsWith('vibrate')) {
          final audioDuration = message.split('-').last;

          if (int.tryParse(audioDuration) != null) {
            final duration = Duration(seconds: int.parse(audioDuration));
            triggerVibrations(duration: settings.loopAudio ? null : duration);
          }
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }
  }

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(AlarmSettings settings) async {
    _registerPort(settings, registerIfTaken: true);
    try {
      final permission = await Permission.ignoreBatteryOptimizations.request();
      if (permission.isDenied) {
        alarmPrint(
          'Permission to ignore battery optimization not granted. Alarm may trigger with up to 15 minute delay due to Android Doze optimization',
        );
      }
    } catch (e) {
      alarmPrint(
        'Failed to request for permissions to ignore battery optimization. $e',
      );
    }

    final res = await AndroidAlarmManager.oneShotAt(
      settings.dateTime,
      settings.id,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      wakeup: true,
      params: settings.toJson(),
    );

    alarmPrint(
      'Alarm with id ${settings.id} scheduled ${res ? 'successfully' : 'failed'} at ${settings.dateTime}',
    );

    if (settings.enableNotificationOnKill && !(await hasOtherAlarms)) {
      try {
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': await AlarmStorage.getNotificationOnAppKillTitle(),
            'description': await AlarmStorage.getNotificationOnAppKillBody(),
          },
        );
        alarmPrint('NotificationOnKillService set with success');
      } catch (e) {
        throw AlarmException('NotificationOnKillService error: $e');
      }
    }

    return res;
  }

  @pragma('vm:entry-point')
  static void watchdogHeartbeat(int id, Map<String, dynamic> data) {
    alarmPrint('[ANDROID_ALARM] watchdog heartbeat');
  }

  /// Callback triggered when alarmDateTime is reached.
  /// The message `ring` is sent to the main thread in order to
  /// tell the device that the alarm is starting to ring.
  /// Alarm is played with AudioPlayer and stopped when the message `stop`
  /// is received from the main thread.
  @pragma('vm:entry-point')
  static Future<void> playAlarm(
    int id,
    Map<String, dynamic> data, [
    int retryCount = 20,
  ]) async {
    alarmPrint('[ANDROID_ALARM] callback: playAlarm');
    final alarmSettings = AlarmSettings.fromJson(data);
    // Hack: periodically wake up the app to make sure the activity manager
    // doesn't freezes our app.
    final watchdogId = '$id-watchdog'.hashCode;
    await AndroidAlarmManager.periodic(
      const Duration(seconds: 1),
      watchdogId,
      AndroidAlarm.watchdogHeartbeat,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      wakeup: true,
    );

    final audioPlayer = AudioPlayer();
    final callerPort = IsolateNameServer.lookupPortByName("$ringPort-$id");
    if (callerPort == null) {
      await AndroidAlarmManager.cancel(watchdogId);
      alarmPrint(
          '[ANDROID_ALARM] Isolate port not found. $retryCount retries left');
      if (retryCount == 0) {
        throw const AlarmException('Isolate port not found');
      }

      return Future.delayed(const Duration(seconds: 1),
          () => playAlarm(id, data, retryCount - 1));
    }

    callerPort.send('ring');

    try {
      final assetAudioPath = alarmSettings.assetAudioPath;
      Duration? audioDuration;

      if (assetAudioPath.startsWith('http')) {
        await AndroidAlarmManager.cancel(watchdogId);
        callerPort
            .send('Network URL not supported. Please provide local asset.');
        return;
      }

      audioDuration = assetAudioPath.startsWith('assets/')
          ? await audioPlayer.setAsset(assetAudioPath)
          : await audioPlayer.setFilePath(assetAudioPath);

      callerPort.send('vibrate-${audioDuration?.inSeconds}');

      final loopAudio = alarmSettings.loopAudio;
      if (loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      callerPort.send('Alarm data received in isolate: $data');

      final fadeDuration = alarmSettings.fadeDuration;
      callerPort.send('Alarm fadeDuration: $fadeDuration seconds');

      if (fadeDuration > Duration.zero) {
        int counter = 0;

        audioPlayer.setVolume(0.1);
        audioPlayer.play();

        callerPort.send('Alarm playing with fadeDuration ${fadeDuration}s');

        Timer.periodic(
          Duration(milliseconds: fadeDuration.inMilliseconds ~/ 10),
          (timer) {
            counter++;
            audioPlayer.setVolume(counter / 10);
            if (counter >= 10) timer.cancel();
          },
        );
      } else {
        audioPlayer.play();
        callerPort.send('Alarm with id $id starts playing.');
      }
    } catch (e) {
      await AudioPlayer.clearAssetCache();
      await AndroidAlarmManager.cancel(watchdogId);
      callerPort.send('Asset cache reset. Please try again.');
      throw AlarmException(
        "Alarm with id $id and asset path '${alarmSettings.assetAudioPath}' error: $e",
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

      String? processingMessage;
      port.listen((message) async {
        if (processingMessage == message) {
          callerPort.send(
            '(isolate) ignoring request for "$message" since in the middle of processing the same request.',
          );
          return;
        }

        processingMessage = message;
        callerPort.send('[${DateTime.now()}] (isolate) received: $message');
        callerPort.send('clear');
        await audioPlayer.stop();
        await audioPlayer.dispose();

        switch (message) {
          case 'stop':
            if (alarmSettings.recurring) {
              await _rescheduleAlarm(
                port: callerPort,
                alarmSettings: alarmSettings.copyWith(
                  dateTime: alarmSettings.nextDateTime(),
                  bedtime: alarmSettings.nextBedtime(),
                ),
                withBedtime: true,
              );
            }
            break;

          case 'snooze':
            await _rescheduleAlarm(
              port: callerPort,
              alarmSettings: alarmSettings.copyWith(
                dateTime: alarmSettings.nextSnoozeDateTime(),
              ),
            );
            break;

          default:
            callerPort.send('(isolate) Unknown message: $message');
        }

        await AndroidAlarmManager.cancel(watchdogId);
        port.close();
        IsolateNameServer.removePortNameMapping(stopPort);
        processingMessage = null;
      });
    } catch (e) {
      await AndroidAlarmManager.cancel(watchdogId);
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

  /// Sets the device volume to the maximum.
  static Future<void> setMaximumVolume() async {
    previousVolume = await VolumeController().getVolume();
    VolumeController().setVolume(1.0, showSystemUI: true);
  }

  /// Sends the message `snooze` to the isolate so the audio player can stop
  /// playing, dispose and then reschedule the alarm.
  static Future<bool> snooze(int id) async {
    alarmPrint('[ANDROID_ALARM] snooze alarm');
    _ringing = null;
    vibrationsActive = false;

    final send = IsolateNameServer.lookupPortByName(stopPort);
    bool snoozed = false;
    if (send != null) {
      alarmPrint('[ANDROID_ALARM] + requesting isolate to snooze alarm $id');
      send.send('snooze');
      snoozed = true;
    }

    if (previousVolume != null) {
      VolumeController().setVolume(previousVolume!, showSystemUI: true);
      previousVolume = null;
    }

    if (!await hasOtherAlarms) stopNotificationOnKillService();

    return snoozed;
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing, dispose, and reschedule the alarm if it's recurring.
  static Future<bool> stop(int id) async {
    alarmPrint('[ANDROID_ALARM] stop alarm');
    _ringing = null;
    vibrationsActive = false;

    final send = IsolateNameServer.lookupPortByName(stopPort);
    bool stopped = true;
    if (send != null) {
      alarmPrint('[ANDROID_ALARM] + requesting isolate to stop alarm $id');
      send.send('stop');
    } else {
      alarmPrint('[ANDROID_ALARM] + Cancelling future alarm $id');
      stopped = await AndroidAlarmManager.cancel(id);
    }

    if (previousVolume != null) {
      VolumeController().setVolume(previousVolume!, showSystemUI: true);
      previousVolume = null;
    }

    if (!await hasOtherAlarms) stopNotificationOnKillService();

    return stopped;
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      alarmPrint('NotificationOnKillService stopped with success');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }

  /// Reschedule the alarm and its associated notifications.
  static Future<void> _rescheduleAlarm({
    required SendPort port,
    required AlarmSettings alarmSettings,
    bool withBedtime = false,
  }) async {
    await AlarmStorage.saveAlarm(alarmSettings);

    port.send(
      '[${DateTime.now()}] [ANDROID_ALARM] Trying to reschedule alarm: $alarmSettings',
    );
    final success = await AndroidAlarmManager.oneShotAt(
      alarmSettings.dateTime,
      alarmSettings.id,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      wakeup: true,
      params: alarmSettings.toJson(),
    );
    if (success) {
      port.send(
        '[${DateTime.now()}] [ANDROID_ALARM] + alarm ${alarmSettings.id} rescheduled at ${alarmSettings.dateTime}',
      );
    } else {
      port.send(
        '[${DateTime.now()}] [ANDROID_ALARM] + FAILED to reschedule alarm ${alarmSettings.id}',
      );
    }

    // Avoid registering a port for the isolate inside the notification if one
    // is already registered to ensure the UI will receive callbacks.
    await AlarmNotification.instance.init(forceRegisterPort: false);

    // Alarm notification
    if (alarmSettings.notificationTitle?.isNotEmpty == true &&
        alarmSettings.notificationBody?.isNotEmpty == true) {
      await AlarmNotification.scheduleNotification(
        id: alarmSettings.id,
        dateTime: alarmSettings.dateTime,
        title: alarmSettings.notificationTitle!,
        body: alarmSettings.notificationBody!,
        snooze: alarmSettings.snooze ?? false,
        snoozeLabel: alarmSettings.notificationActionSnoozeLabel ?? 'Snooze',
        dismissLabel: alarmSettings.notificationActionDismissLabel ?? 'Dismiss',
        type: NotificationType.alarm,
      );
    }

    // Bedtime notification
    if (withBedtime &&
        alarmSettings.bedtime != null &&
        alarmSettings.bedtimeNotificationTitle?.isNotEmpty == true &&
        alarmSettings.bedtimeNotificationBody?.isNotEmpty == true) {
      await AlarmNotification.scheduleNotification(
        alarmId: alarmSettings.id,
        id: Alarm.toBedtimeNotificationId(alarmSettings.id),
        dateTime: alarmSettings.bedtime!,
        title: alarmSettings.bedtimeNotificationTitle!,
        body: alarmSettings.bedtimeNotificationBody!,
        playSound: true,
        enableLights: true,
        type: NotificationType.bedtime,
        autoDismiss: alarmSettings.bedtimeAutoDissmiss,
      );
    }
  }
}
