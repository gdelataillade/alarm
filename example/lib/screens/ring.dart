import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class ExampleAlarmRingScreen extends StatefulWidget {
  const ExampleAlarmRingScreen({required this.alarmSettings, super.key});

  final AlarmSettings alarmSettings;

  @override
  State<ExampleAlarmRingScreen> createState() => _ExampleAlarmRingScreenState();
}

class _ExampleAlarmRingScreenState extends State<ExampleAlarmRingScreen> {
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final isRinging = await Alarm.isRinging(widget.alarmSettings.id);
      if (isRinging) {
        alarmPrint('Alarm ${widget.alarmSettings.id} is still ringing...');
        return;
      }

      alarmPrint('Alarm ${widget.alarmSettings.id} stopped ringing.');
      timer.cancel();
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              'You alarm (${widget.alarmSettings.id}) is ringing...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('🔔', style: TextStyle(fontSize: 50)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RawMaterialButton(
                  onPressed: () async => Alarm.set(
                    alarmSettings: widget.alarmSettings.copyWith(
                      dateTime: DateTime.now().add(const Duration(minutes: 1)),
                    ),
                  ),
                  child: Text(
                    'Snooze',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RawMaterialButton(
                  onPressed: () async => Alarm.stop(widget.alarmSettings.id),
                  child: Text(
                    'Stop',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
