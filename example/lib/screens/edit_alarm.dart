import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class ExampleAlarmEditScreen extends StatefulWidget {
  final AlarmSettings? alarmSettings;

  const ExampleAlarmEditScreen({Key? key, this.alarmSettings})
      : super(key: key);

  @override
  State<ExampleAlarmEditScreen> createState() => _ExampleAlarmEditScreenState();
}

class _ExampleAlarmEditScreenState extends State<ExampleAlarmEditScreen> {
  late bool creating;

  late TimeOfDay selectedTime;
  late bool loopAudio;
  late bool vibrate;
  late bool showNotification;
  late String assetAudio;

  @override
  void initState() {
    super.initState();
    creating = widget.alarmSettings == null;

    if (creating) {
      final dt = DateTime.now().add(const Duration(minutes: 1));
      selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      loopAudio = true;
      vibrate = true;
      showNotification = true;
      assetAudio = 'assets/mozart.mp3';
    } else {
      selectedTime = TimeOfDay(
        hour: widget.alarmSettings!.dateTime.hour,
        minute: widget.alarmSettings!.dateTime.minute,
      );
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      showNotification = widget.alarmSettings!.notificationTitle != null &&
          widget.alarmSettings!.notificationTitle!.isNotEmpty &&
          widget.alarmSettings!.notificationBody != null &&
          widget.alarmSettings!.notificationBody!.isNotEmpty;
      assetAudio = widget.alarmSettings!.assetAudioPath;
    }
  }

  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: selectedTime,
      context: context,
    );
    if (res != null) setState(() => selectedTime = res);
  }

  AlarmSettings buildAlarmSettings() {
    final now = DateTime.now();
    final id = creating
        ? DateTime.now().millisecondsSinceEpoch % 100000
        : widget.alarmSettings!.id;

    DateTime dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
      0,
      0,
    );
    if (dateTime.isBefore(DateTime.now())) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      loopAudio: loopAudio,
      vibrate: vibrate,
      notificationTitle: showNotification ? 'Alarm example' : null,
      notificationBody: showNotification ? 'Your alarm ($id) is ringing' : null,
      assetAudioPath: assetAudio,
      stopOnNotificationOpen: false,
    );
    return alarmSettings;
  }

  void saveAlarm() {
    Alarm.set(alarmSettings: buildAlarmSettings()).then((res) {
      if (res) Navigator.pop(context, true);
    });
  }

  void deleteAlarm() {
    Alarm.stop(widget.alarmSettings!.id).then((res) {
      if (res) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Cancel",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
              TextButton(
                onPressed: saveAlarm,
                child: Text(
                  "Save",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
          RawMaterialButton(
            onPressed: pickTime,
            fillColor: Colors.grey[200],
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Text(
                selectedTime.format(context),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium!
                    .copyWith(color: Colors.blueAccent),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loop alarm audio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: loopAudio,
                onChanged: (value) => setState(() => loopAudio = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vibrate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: vibrate,
                onChanged: (value) => setState(() => vibrate = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Show notification',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: showNotification,
                onChanged: (value) => setState(() => showNotification = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sound',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              DropdownButton(
                value: assetAudio,
                items: const [
                  DropdownMenuItem<String>(
                    value: 'assets/mozart.mp3',
                    child: Text('Mozart'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/nokia.mp3',
                    child: Text('Nokia'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/one_piece.mp3',
                    child: Text('One Piece'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/star_wars.mp3',
                    child: Text('Star Wars'),
                  ),
                ],
                onChanged: (value) => setState(() => assetAudio = value!),
              ),
            ],
          ),
          if (!creating)
            TextButton(
              onPressed: deleteAlarm,
              child: Text(
                'Delete Alarm',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Colors.red),
              ),
            ),
          const SizedBox(),
        ],
      ),
    );
  }
}
