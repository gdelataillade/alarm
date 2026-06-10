import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:alarm_example/screens/edit_alarm.dart';
import 'package:alarm_example/screens/ring.dart';
import 'package:alarm_example/screens/shortcut_button.dart';
import 'package:alarm_example/services/notifications.dart';
import 'package:alarm_example/services/permission.dart';
import 'package:alarm_example/widgets/tile.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const version = '5.4.1';

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({super.key});

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  List<AlarmSettings> alarms = [];
  final List<AlarmSettings> alarmHistory = [];
  Notifications? notifications;

  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;

  @override
  void initState() {
    super.initState();
    AlarmPermissions.checkNotificationPermission().then(
      (_) => AlarmPermissions.checkAndroidScheduleExactAlarmPermission(),
    );
    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      unawaited(loadAlarms());
    });
    notifications = Notifications();
  }

  Future<void> loadAlarms() async {
    final scheduled = await Alarm.getAlarms();

    // Merge scheduled alarms into history, keeping stopped ones visible
    for (final alarm in scheduled) {
      final index = alarmHistory.indexWhere((a) => a.id == alarm.id);
      if (index == -1) {
        alarmHistory.add(alarm);
      } else {
        alarmHistory[index] = alarm;
      }
    }

    alarmHistory.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);

    setState(() {
      alarms = scheduled;
    });
  }

  Future<void> ringingAlarmsChanged(AlarmSet alarms) async {
    if (alarms.alarms.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            ExampleAlarmRingScreen(alarmSettings: alarms.alarms.first),
      ),
    );
    unawaited(loadAlarms());
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: ExampleAlarmEditScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) unawaited(loadAlarms());
  }

  Future<void> launchReadmeUrl() async {
    final url = Uri.parse('https://pub.dev/packages/alarm/versions/$version');
    await launchUrl(url);
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('alarm $version'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: launchReadmeUrl,
          ),
          PopupMenuButton<String>(
            onSelected: notifications == null
                ? null
                : (value) async {
                    if (value == 'Show notification') {
                      await notifications?.showNotification();
                    } else if (value == 'Schedule notification') {
                      await notifications?.scheduleNotification();
                    }
                  },
            itemBuilder: (BuildContext context) =>
                {'Show notification', 'Schedule notification'}
                    .map(
                      (String choice) => PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: alarmHistory.isNotEmpty
                  ? ListView.separated(
                      itemCount: alarmHistory.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alarm = alarmHistory[index];
                        final isStopped = !alarms.any((a) => a.id == alarm.id);
                        final soundName = alarm.assetAudioPath
                            ?.split('/')
                            .last
                            .replaceAll('.mp3', '');
                        final flags = <String>[
                          'id:${alarm.id}',
                          if (soundName != null) soundName else 'default',
                          if (alarm.allowSameSecondScheduling) 'same-second',
                          if (alarm.allowAlarmOverlap) 'overlap',
                        ];
                        return ExampleAlarmTile(
                          key: Key(alarm.id.toString()),
                          title: TimeOfDay(
                            hour: alarm.dateTime.hour,
                            minute: alarm.dateTime.minute,
                          ).format(context),
                          subtitle: flags.join(' · '),
                          isStopped: isStopped,
                          onPressed: () => navigateToAlarmScreen(alarm),
                          onDismissed: () {
                            Alarm.stop(alarm.id).then((_) {
                              setState(() {
                                alarmHistory.removeWhere(
                                  (a) => a.id == alarm.id,
                                );
                              });
                            });
                          },
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        'No alarms set',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExampleAlarmHomeShortcutButton(refreshAlarms: loadAlarms),
            const FloatingActionButton(
              onPressed: Alarm.stopAll,
              backgroundColor: Colors.red,
              heroTag: null,
              child: Text(
                'STOP ALL',
                textScaler: TextScaler.linear(0.9),
                textAlign: TextAlign.center,
              ),
            ),
            FloatingActionButton(
              onPressed: () => navigateToAlarmScreen(null),
              child: const Icon(Icons.alarm_add_rounded, size: 33),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
