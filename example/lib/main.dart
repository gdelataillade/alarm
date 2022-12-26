import 'package:flutter/material.dart';
import 'dart:async';

import 'package:alarm/alarm.dart';

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TimeOfDay? selectedTime;

  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: TimeOfDay(
        hour: TimeOfDay.now().hour,
        minute: TimeOfDay.now().minute + 1,
      ),
      context: context,
    );

    if (res == null) return;
    setState(() => selectedTime = res);

    final now = DateTime.now();
    DateTime dt = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (ringDay() == 'tomorrow') dt = dt.add(const Duration(days: 1));

    Alarm.set(alarmDateTime: dt);
  }

  String ringDay() {
    final now = TimeOfDay.now();

    if (selectedTime!.hour > now.hour) return 'today';
    if (selectedTime!.hour < now.hour) return 'tomorrow';

    if (selectedTime!.minute > now.minute) return 'today';
    if (selectedTime!.minute < now.minute) return 'tomorrow';

    return 'tomorrow';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Package alarm example app')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RawMaterialButton(
              onPressed: pickTime,
              fillColor: Colors.red,
              child: const Text('Pick time'),
            ),
            if (selectedTime != null)
              Text(
                'Alarm will ring ${ringDay()} at ${selectedTime!.format(context)}',
              ),
            const SizedBox(height: 50),
            RawMaterialButton(
              onPressed: () => Alarm.set(alarmDateTime: DateTime.now()),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm now'),
            ),
            RawMaterialButton(
              onPressed: () => Alarm.set(
                alarmDateTime: DateTime.now().add(const Duration(seconds: 3)),
              ),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm in 3 seconds'),
            ),
            const SizedBox(height: 50),
            RawMaterialButton(
              onPressed: () => Alarm.stop(),
              fillColor: Colors.red,
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}
