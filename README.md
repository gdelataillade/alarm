![Pub Version](https://img.shields.io/pub/v/alarm)
![Pub Likes](https://img.shields.io/pub/likes/alarm)
![Pub Points](https://img.shields.io/pub/points/alarm)
![Pub Popularity](https://img.shields.io/pub/popularity/alarm)

[![alarm](https://github.com/gdelataillade/alarm/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/gdelataillade/alarm/actions/workflows/main.yml)

🏆 Winner of the [2023 OnePub Community Choice Awards](https://onepub.dev/Competition).

# Alarm plugin for iOS and Android

This Flutter plugin provides a simple and easy-to-use interface for setting and canceling alarms on iOS and Android devices. It utilizes the `android_alarm_manager_plus` plugin for Android and the native iOS `AVAudioPlayer` class.

## 🔧 Installation steps

### [iOS Setup](https://github.com/gdelataillade/alarm/blob/feat/ios-background-fetch/help/INSTALL-IOS.md)
### [Android Setup](https://github.com/gdelataillade/alarm/blob/feat/ios-background-fetch/help/INSTALL-ANDROID.md)

## 📖 How to use

Add to your pubspec.yaml:
```Bash
flutter pub add alarm
```

First, you have to initialize the Alarm service in your `main` function:
```Dart
await Alarm.init()
```

Then, you have to define your alarm settings:
```Dart
final alarmSettings = AlarmSettings(
  id: 42,
  dateTime: dateTime,
  assetAudioPath: 'assets/alarm.mp3',
  loopAudio: true,
  vibrate: true,
  volumeMax: true,
  fadeDuration: 3.0,
  notificationTitle: 'This is the title',
  notificationBody: 'This is the body',
  enableNotificationOnKill: true,
);
```

And finally set the alarm:
```Dart
await Alarm.set(alarmSettings: alarmSettings)
```

Property |   Type     | Description
-------- |------------| ---------------
id |   `int`     | Unique identifier of the alarm.
alarmDateTime |   `DateTime`     | The date and time you want your alarm to ring.
assetAudio |   `String`     | The path to you audio asset you want to use as ringtone. Can be a path in your assets folder or a downloaded local file path.
loopAudio |   `bool`     | If true, audio will repeat indefinitely until alarm is stopped.
vibrate |   `bool`     | If true, device will vibrate indefinitely until alarm is stopped. If [loopAudio] is set to false, vibrations will stop when audio ends.
volumeMax |   `bool`     | If true, set system volume to maximum when [dateTime] is reached. Set back to previous volume when alarm is stopped.
fadeDuration |   `double`     | Duration, in seconds, over which to fade the alarm volume. Set to 0 by default, which means no fade.
notificationTitle |   `String`     | The title of the notification triggered when alarm rings if app is on background.
notificationBody | `String` | The body of the notification.
enableNotificationOnKill |   `bool`     | Whether to show a notification when application is killed to warn the user that the alarm he set may not ring. Enabled by default.
stopOnNotificationOpen |   `bool`     | Whether to stop the alarm when opening the received notification. Enabled by default.

The notification shown on alarm ring can be disabled simply by ignoring the parameters `notificationTitle` and `notificationBody`. However, if you want a notification to be triggered, you will have to provide **both of them**.

If you enabled `enableNotificationOnKill`, you can chose your own notification title and body by using this method:
```Dart
await Alarm.setNotificationOnAppKillContent(title, body)
```

This is how to stop/cancel your alarm:
```Dart
await Alarm.stop(id)
```

This is how to run some code when alarm starts ringing. We implemented it as a stream so even if your app was previously killed, your custom callback can still be triggered.
```Dart
Alarm.ringStream.stream.listen((_) => yourOnRingCallback());
```

To avoid unexpected behaviors, if you set an alarm for the same time as an existing one, the new alarm will replace the existing one.

## 📱 Example app

Don't hesitate to check out the example's code, and take a look at the app:

![home](https://github.com/gdelataillade/alarm/assets/32983806/695736aa-b55f-4050-8b0d-274b0d46714a)
![edit](https://github.com/gdelataillade/alarm/assets/32983806/05329836-9fbe-462c-aa1e-dce0fa70f455)

## ⏰ Alarm behaviour

|                          | Sound | Vibrate | Volume max | Notification
| ------------------------ | ----- | ------- | ---------- | -------
| Locked screen            |  ✅   | ✅       | ✅          | ✅
| Silent / Mute            |  ✅   | ✅       | ✅          | ✅
| Do not disturb           |  ✅   | ✅       | ✅          | Silenced
| Sleep mode               |  ✅   | ✅       | ✅          | Silenced
| While playing other media|  ✅   | ✅       | ✅          | ✅
| App killed               |  ❌   | ❌       | ❌          | ✅

*Silenced: Means that the notification is not shown directly on the top of the screen. You have to go in your notification center to see it.*

## ❓ FAQ

### Why didn't my alarm fire on iOS?

Several factors could prevent your alarm from ringing:
- Your iPhone was restarted (either from a manual reboot or due to an iOS update).
- The app was either manually terminated or was closed because of memory constraints.

### My alarm is not firing on a specific Android device

Some Android manufacturers prefer battery life over proper functionality of your apps. Check out [dontkillmyapp.com](https://dontkillmyapp.com) to find out about more about optimizations done by different vendors, and potential workarounds.
Most common workaround is to ask the user to disable battery optimization settings.
*Source: [https://pub.dev/packages/android_alarm_manager_plus#faq](https://pub.dev/packages/android_alarm_manager_plus#faq)*

### How can I increase the reliability of the alarm ringing?

The more time the app spends in the background, the higher the chance the OS might stop it from running due to memory or battery optimizations. Here's how you can optimize:

- **Regular App Usage**: Encourage users to open the app at least once a day.
- **Leverage Background Modes**: Engage in activities like weather API calls that keep the app active in the background.
- **User Settings**: Educate users to refrain from using 'Do Not Disturb' (DnD) and 'Low Power Mode' when they're expecting the alarm to ring.

## ⚙️ Under the hood

### Android
Uses `oneShotAt` from the `android_alarm_manager_plus` plugin with a two-way communication isolated callback to start/stop the alarm.

### iOS
Keeps the app awake using a silent `AVAudioPlayer` until alarm rings. When in the background, it also uses `Background App Refresh` to periodically ensure the app is still active.

## ✉️ Feature request

If you have a feature request, just open an issue explaining clearly what you want and if you convince me I will develop it for you.

## 💙 Contributing

We welcome contributions to this plugin! If you would like to make a change or add a new feature, please follow these steps:

1.  Fork the repository and create a new branch for your changes.
2.  Make your changes
3.  Run `flutter format` to ensure that your code is correctly formatted.
4.  Submit a pull request with a detailed description of your changes.

These are some features that I have in mind that could be useful:
- Use `ffigen` and `jnigen` binding generators to call native code more efficiently instead of using method channels.
- [Notification actions](https://pub.dev/packages/flutter_local_notifications#notification-actions): stop and snooze.
- Stop alarm sound when notification is dismissed.
- Make alarm ring even if app was terminated.

Thank you for considering contributing to this plugin. Your help is greatly appreciated!

❤️ Let me know if you like the plugin by liking it on [pub.dev](https://pub.dev/packages/alarm) and starring the repo on [Github](https://github.com/gdelataillade/alarm) 🙂
