import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm_example/screens/edit_alarm.dart';
import 'package:alarm_example/screens/quick_tests.dart';
import 'package:alarm_example/screens/ring.dart';
import 'package:alarm_example/widgets/tile.dart';
import 'package:flutter/material.dart';

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({Key? key}) : super(key: key);

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  late List<AlarmSettings> alarms;

  static StreamSubscription? subscription;

  @override
  void initState() {
    super.initState();
    loadAlarms();
    subscription ??= Alarm.ringStream.stream
        .listen((alarmSettings) => navigateToRingScreen(alarmSettings));
  }

  void loadAlarms() => setState(() => alarms = Alarm.getAlarms());

  Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
    final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ExampleAlarmRingScreen(alarmSettings: alarmSettings),
        ));
    print("[DEV] ring screen returned: $res");
    if (res) loadAlarms();
  }

  void navigateToQuickTests() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExampleAlarmQuickTestsScreen(),
      ));

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.6,
            child: ExampleAlarmEditScreen(alarmSettings: settings),
          );
        });

    if (res != null && res == true) loadAlarms();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Package alarm example app')),
      body: SafeArea(
        child: ListView.builder(
          itemCount: alarms.isEmpty ? 1 : alarms.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                if (index == 0)
                  ExampleAlarmTile(
                    key: const Key('quick_tests'),
                    title: 'Quick tests',
                    onPressed: navigateToQuickTests,
                  ),
                Divider(
                  height: index == 0 ? 1 : 0,
                  color: Colors.black,
                ),
                if (alarms.isNotEmpty)
                  ExampleAlarmTile(
                    key: Key(alarms[index].id.toString()),
                    // TODO: Format HH:mm
                    title: TimeOfDay(
                      hour: alarms[index].dateTime.hour,
                      minute: alarms[index].dateTime.minute,
                    ).format(context),
                    onPressed: () => navigateToAlarmScreen(alarms[index]),
                    onDismissed: () {
                      setState(() {
                        Alarm.stop(alarms[index].id);
                        setState(() => alarms.remove(alarms[index]));
                      });
                    },
                  ),
                if (index == alarms.length - 1)
                  Divider(
                    height: index == 0 ? 1 : 0,
                    color: Colors.black,
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => navigateToAlarmScreen(null),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}
