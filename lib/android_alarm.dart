// ignore_for_file: avoid_print

import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:just_audio/just_audio.dart';

class AndroidAlarm {
  static const int alarmId = 888;
  static String ringPort = 'alarm-ring';
  static String stopPort = 'alarm-stop';

  static Future<void> init() => AndroidAlarmManager.initialize();

  static Future<bool> set(DateTime alarmDateTime, String assetAudioPath) async {
    try {
      final ReceivePort port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, ringPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(ringPort);
        IsolateNameServer.registerPortWithName(port.sendPort, ringPort);
      }
      port.listen((message) {
        print("[Alarm] (main) received: $message");
        if (message == 'ring') ring();
      });
    } catch (e) {
      print("[Alarm] (main) ReceivePort error: $e");
      return false;
    }

    final res = await AndroidAlarmManager.oneShotAt(
      alarmDateTime,
      alarmId,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      params: {
        "assetAudioPath": assetAudioPath,
      },
    );

    return res;
  }

  static Future<bool> stop() async {
    try {
      final SendPort send = IsolateNameServer.lookupPortByName(stopPort)!;
      print("[AndroidAlarm] (main) send stop to isolate");
      send.send('stop');
    } catch (e) {
      print("[AndroidAlarm] (main) SendPort error: $e");
    }

    final res = await AndroidAlarmManager.cancel(alarmId);
    // Storage.setAppLocalData("androidAlarm", false);

    return res;
  }

  static Future<bool> snooze() async => false;

  static Future<void> ring() async {
    print("[Alarm] ring callback");
  }

  @pragma('vm:entry-point')
  static Future<void> playAlarm(int id, Map<String, dynamic> data) async {
    final isoAlarm = AudioPlayer();
    SendPort send = IsolateNameServer.lookupPortByName(ringPort)!;

    send.send('ring');

    try {
      await isoAlarm.setAudioSource(
        AudioSource.uri(
          Uri.parse("asset:///assets/${data["assetAudio"]}"),
        ),
      );
      isoAlarm.play();
      send.send('[Alarm] Alarm playing...');
    } catch (e) {
      send.send('[Alarm] AudioPlayer error: $e');
    }

    // await notifLct.androidAlarmNotif(alarmId);

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
          send.send("[AndroidAlarm] (isolate) received: $message");
          if (message == 'stop') {
            await isoAlarm.stop();
            await isoAlarm.dispose();
            port.close();
          }
        },
      );
    } catch (e) {
      send.send("[AndroidAlarm] (isolate) ReceivePort error: $e");
    }
  }
}
