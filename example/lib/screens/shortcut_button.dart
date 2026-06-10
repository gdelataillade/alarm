import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class ExampleAlarmHomeShortcutButton extends StatefulWidget {
  const ExampleAlarmHomeShortcutButton({
    required this.refreshAlarms,
    super.key,
  });

  final void Function() refreshAlarms;

  @override
  State<ExampleAlarmHomeShortcutButton> createState() =>
      _ExampleAlarmHomeShortcutButtonState();
}

class _ExampleAlarmHomeShortcutButtonState
    extends State<ExampleAlarmHomeShortcutButton> {
  bool showMenu = false;

  Future<void> onPressButton(int delayInHours) async {
    var dateTime = DateTime.now().add(Duration(hours: delayInHours));
    double? volume;

    if (delayInHours != 0) {
      dateTime = dateTime.copyWith(second: 0, millisecond: 0);
      volume = 0.5;
    }

    setState(() => showMenu = false);

    final alarmSettings = AlarmSettings(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      dateTime: dateTime,
      volumeSettings: VolumeSettings.fixed(volume: volume),
      notificationSettings: NotificationSettings(
        title: 'Alarm example',
        body: 'Shortcut button alarm with delay of $delayInHours hours',
        icon: 'notification_icon',
      ),
      warningNotificationOnKill: Platform.isIOS,
    );

    await Alarm.set(alarmSettings: alarmSettings);

    widget.refreshAlarms();
  }

  Future<void> scheduleMultipleAlarms({required bool allowOverlap}) async {
    setState(() => showMenu = false);

    final now = DateTime.now();
    final baseId = now.millisecondsSinceEpoch % 10000;
    final dateTime = now.add(const Duration(seconds: 5));

    final sounds = [
      'assets/marimba.mp3',
      'assets/nokia.mp3',
      'assets/mozart.mp3',
    ];

    for (var i = 0; i < 3; i++) {
      final alarmSettings = AlarmSettings(
        id: baseId + i,
        dateTime: dateTime,
        loopAudio: false,
        vibrate: true,
        assetAudioPath: sounds[i],
        volumeSettings: VolumeSettings.fixed(volume: 0.8),
        allowSameSecondScheduling: true,
        allowAlarmOverlap: allowOverlap,
        notificationSettings: NotificationSettings(
          title: 'Alarm ${i + 1} of 3',
          body: allowOverlap
              ? 'Concurrent mode: overlapping alarms'
              : 'Sequential mode: queued alarms',
          stopButton: 'Stop',
          icon: 'notification_icon',
        ),
        warningNotificationOnKill: Platform.isIOS,
      );

      await Alarm.set(alarmSettings: alarmSettings);
    }

    widget.refreshAlarms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowOverlap
                ? '3 concurrent alarms scheduled for ${dateTime.toLocal()}'
                : '3 sequential alarms scheduled for ${dateTime.toLocal()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onLongPress: () {
            setState(() => showMenu = true);
          },
          child: FloatingActionButton(
            onPressed: () => onPressButton(0),
            backgroundColor: Colors.green[700],
            heroTag: null,
            child: const Text(
              'RING NOW',
              textScaler: TextScaler.linear(0.9),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (showMenu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => onPressButton(24),
                child: const Text('+24h'),
              ),
              TextButton(
                onPressed: () => onPressButton(36),
                child: const Text('+36h'),
              ),
              TextButton(
                onPressed: () => onPressButton(48),
                child: const Text('+48h'),
              ),
              TextButton(
                onPressed: () => scheduleMultipleAlarms(allowOverlap: false),
                child: const Text('3 seq'),
              ),
              TextButton(
                onPressed: () => scheduleMultipleAlarms(allowOverlap: true),
                child: const Text('3 overlap'),
              ),
            ],
          ),
      ],
    );
  }
}
