import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Alarm.init();

  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TimeOfDay? selectedTime;
  bool showNotifOnRing = true;
  bool showNotifOnKill = true;
  bool isRinging = false;
  bool loopAudio = true;

  StreamSubscription? subscription;

  Future<void> pickTime() async {
    final now = DateTime.now();
    final res = await showTimePicker(
      initialTime: TimeOfDay(
        hour: now.hour,
        minute: now.add(const Duration(minutes: 1)).minute,
      ),
      context: context,
      confirmText: 'SET ALARM',
    );

    if (res == null) return;
    setState(() => selectedTime = res);

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
    final alarmSettings = AlarmSettings(
      dateTime: dateTime,
      assetAudioPath: 'assets/sample.mp3',
      loopAudio: loopAudio,
      notificationTitle:
          showNotifOnRing && enableNotif ? 'Alarm example' : null,
      notificationBody:
          showNotifOnRing && enableNotif ? 'Your alarm is ringing' : null,
      enableNotificationOnKill: true,
    );
    await Alarm.set(settings: alarmSettings);
  }

  @override
  void initState() {
    super.initState();
    subscription = Alarm.ringStream.stream.listen((_) {
      setState(() {
        isRinging = true;
        selectedTime = null;
      });
    });
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Display notification (if backgrounded)'),
                  Switch(
                    value: showNotifOnRing,
                    onChanged: (value) =>
                        setState(() => showNotifOnRing = value),
                  ),
                ],
              ),
              Tooltip(
                message:
                    'Warns the user that alarm may not ring because app was killed.',
                showDuration: const Duration(seconds: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.grey,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    const Text('Show notification on app kill'),
                    Switch(
                      value: showNotifOnKill,
                      onChanged: (value) =>
                          setState(() => showNotifOnKill = value),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Loop alarm audio'),
                  Switch(
                    value: loopAudio,
                    onChanged: (value) => setState(() => loopAudio = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              RawMaterialButton(
                onPressed: pickTime,
                fillColor: Colors.green,
                child: const Text('Pick time'),
              ),
              if (selectedTime != null)
                Text(
                  'Alarm will ring ${ringDay()} at ${selectedTime!.format(context)}',
                ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              if (isRinging) const Text('🔔 Ringing 🔔'),
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
      ),
    );
  }
}
