import 'package:alarm/alarm_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TimeOfDay? selectedTime;
  bool showNotif = true;
  bool isRinging = false;
  bool loopAudio = false;

  StreamSubscription? subscription;

  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: TimeOfDay(
        hour: TimeOfDay.now().hour,
        minute: TimeOfDay.now().minute + 1,
      ),
      context: context,
      confirmText: 'SET ALARM',
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

  Future<void> setAlarm(DateTime dateTime, [bool enableNotif = true]) async {
    await Alarm.set(
      alarmModel: AlarmModel(
        alarmDateTime: dateTime,
        assetAudioPath: 'assets/sample.mp3',
        notifTitle: showNotif && enableNotif ? 'This is the title' : "",
        notifBody: showNotif && enableNotif ? 'This is the body' : "",
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Alarm.init();

    subscription = Alarm.ringStream.stream.listen((_) {
      setState(() {
        isRinging = true;
        selectedTime = null;
      });
    });
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
                const Text("Display notification (if backgrounded)"),
                Switch(
                  value: showNotif,
                  onChanged: (value) => setState(() => showNotif = value),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Loop alarm audio"),
                Switch(
                  value: loopAudio,
                  onChanged: (value) => setState(() => loopAudio = value),
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
              onPressed: () => setAlarm(DateTime.now(), false),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm now'),
            ),
            RawMaterialButton(
              onPressed: () => setAlarm(
                DateTime.now().add(const Duration(seconds: 3)),
                false,
              ),
              fillColor: Colors.lightBlueAccent,
              child: const Text('Ring alarm in 3 seconds (no notif)'),
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
            if (isRinging) const Text("Ringing..."),
            const SizedBox(height: 50),
            RawMaterialButton(
              onPressed: () async {
                final stop = await Alarm.stop();
                setState(() {
                  selectedTime = null;
                  if (stop && isRinging) isRinging = false;
                });
              },
              fillColor: Colors.red,
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
}
