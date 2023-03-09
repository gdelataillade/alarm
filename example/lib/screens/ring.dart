import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class ExampleAlarmRingScreen extends StatelessWidget {
  final AlarmSettings alarmSettings;

  const ExampleAlarmRingScreen({Key? key, required this.alarmSettings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            RawMaterialButton(
              onPressed: () {},
              child: Text(
                "You alarm is ringing...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Icon(Icons.alarm_rounded, size: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RawMaterialButton(
                  onPressed: () {
                    // TODO: Need to stop first ?
                    Alarm.set(
                      settings: alarmSettings.copyWith(
                          dateTime: alarmSettings.dateTime
                            ..add(const Duration(minutes: 1))),
                    );
                    Navigator.pop(context, true);
                  },
                  child: const Text("Snooze"),
                ),
                RawMaterialButton(
                  onPressed: () {
                    Alarm.stop(alarmSettings.id);
                    Navigator.pop(context, false);
                  },
                  child: const Text("Stop"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
