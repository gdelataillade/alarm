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
  bool showNotif = true;
  bool ring = false;

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

    setAlarm(dt);
  }

  String ringDay() {
    final now = TimeOfDay.now();

    if (selectedTime!.hour > now.hour) return 'today';
    if (selectedTime!.hour < now.hour) return 'tomorrow';

    if (selectedTime!.minute > now.minute) return 'today';
    if (selectedTime!.minute < now.minute) return 'tomorrow';

    return 'tomorrow';
  }

  Future<void> setAlarm(DateTime dateTime) async {
    await Alarm.set(
      alarmDateTime: dateTime,
      onRing: () => setState(() => ring = true),
      notifTitle: showNotif ? 'This is the title' : null,
      notifBody: showNotif ? 'This is the body' : null,
    );
  }

  @override
  void initState() {
    super.initState();
    Alarm.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Package alarm example app')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Show notification if background"),
                Switch(
                  value: showNotif,
                  onChanged: (value) => setState(() => showNotif = value),
                ),
              ],
            ),
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
              onPressed: () => setAlarm(DateTime.now()),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm now'),
            ),
            RawMaterialButton(
              onPressed: () {
                DateTime now = DateTime.now();
                setAlarm(
                  DateTime(
                    now.year,
                    now.month,
                    now.day,
                    now.hour,
                    now.minute,
                    0,
                  ).add(const Duration(minutes: 1)),
                );
              },
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm on next minute'),
            ),
            const SizedBox(height: 50),
            if (ring) const Text("Ringing..."),
            const SizedBox(height: 50),
            RawMaterialButton(
              onPressed: () async {
                final stop = await Alarm.stop();
                if (stop && ring) setState(() => ring = false);
              },
              fillColor: Colors.red,
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}
