import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:alarm_example/screens/edit_alarm.dart';
import 'package:alarm_example/screens/ring.dart';
import 'package:alarm_example/screens/shortcut_button.dart';
import 'package:alarm_example/services/permission.dart';
import 'package:alarm_example/widgets/tile.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

const version = '5.0.3';

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({super.key});

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  List<AlarmSettings> alarms = [];

  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;

  @override
  void initState() {
    super.initState();
    AlarmPermissions.checkNotificationPermission()
        .then((_) => AlarmPermissions.checkLocationPermission())
        .then((_) => AlarmPermissions.checkBackgroundLocationPermission());
    if (Alarm.android) {
      AlarmPermissions.checkAndroidScheduleExactAlarmPermission();
    }
    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      unawaited(loadAlarms());
    });
  }

  Future<void> loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _LocationTracker(),
            if (alarms.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: alarms.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ExampleAlarmTile(
                      key: Key(alarms[index].id.toString()),
                      title: TimeOfDay(
                        hour: alarms[index].dateTime.hour,
                        minute: alarms[index].dateTime.minute,
                      ).format(context),
                      onPressed: () => navigateToAlarmScreen(alarms[index]),
                      onDismissed: () {
                        Alarm.stop(alarms[index].id).then((_) => loadAlarms());
                      },
                    );
                  },
                ),
              )
            else
              Center(
                child: Text(
                  'No alarms set',
                  style: Theme.of(context).textTheme.titleMedium,
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

class _LocationTracker extends StatefulWidget {
  const _LocationTracker();

  @override
  State<_LocationTracker> createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<_LocationTracker> {
  static final _log = Logger('_LocationTracker');

  StreamSubscription<Position>? _tracker;
  Position? _position;

  @override
  void initState() {
    super.initState();
    // AlarmPermissions.checkLocationPermission()
    //     .then((_) => AlarmPermissions.checkBackgroundLocationPermission());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Location: ${_position?.latitude}, ${_position?.longitude}'),
        ElevatedButton(
          onPressed: _tracker == null
              ? () {
                  _tracker = Geolocator.getPositionStream(
                    locationSettings: AppleSettings(
                      activityType: ActivityType.otherNavigation,
                      accuracy: LocationAccuracy.bestForNavigation,
                      showBackgroundLocationIndicator: true,
                    ),
                  ).listen(
                    (position) {
                      setState(() {
                        _position = position;
                        _log.info(
                            'Location update received: (${position.latitude}, ${position.longitude})');
                      });
                    },
                    onError: (Object error, StackTrace stackTrace) {
                      _log.severe(
                        'Error tracking location.',
                        error,
                        stackTrace,
                      );
                    },
                    onDone: () {
                      _log.warning('Location tracking ended unexpectedly.');
                      _stopTracking();
                    },
                  );
                }
              : null,
          child: const Text('Start tracking'),
        ),
        ElevatedButton(
          onPressed: _tracker != null ? _stopTracking : null,
          child: const Text('Stop tracking'),
        ),
      ],
    );
  }

  void _stopTracking() {
    _tracker?.cancel();
    _tracker = null;
    setState(() {
      _position = null;
    });
    _log.info('Location tracking stopped.');
  }
}
