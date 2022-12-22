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
  Future<void> pickTime() async {
    TimeOfDay? selectedTime = await showTimePicker(
      initialTime: TimeOfDay.now(),
      context: context,
    );
    print("[Alarm] selected time: $selectedTime");
  }

  @override
  void initState() {
    super.initState();
    print("Init app");
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
            RawMaterialButton(
              onPressed: () => Alarm.setAlarm(
                DateTime.now().add(const Duration(seconds: 2)),
                'sample.mp3',
              ),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Set alarm'),
            ),
            RawMaterialButton(
              onPressed: () => Alarm.stopAlarm(),
              fillColor: Colors.red,
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}
