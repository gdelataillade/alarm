![Pub Version](https://img.shields.io/pub/v/alarm)
![Pub Likes](https://img.shields.io/pub/likes/alarm)
![Pub Points](https://img.shields.io/pub/points/alarm)
![Pub Popularity](https://img.shields.io/pub/popularity/alarm)

[![alarm](https://github.com/gdelataillade/alarm/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/gdelataillade/alarm/actions/workflows/main.yml)

🏆 Winner of the [2023 OnePub Community Choice Awards](https://onepub.dev/Competition).

# Alarm plugin for iOS and Android

This plugin offers a straightforward interface to set and cancel alarms on both iOS and Android devices. Using native code, it handles audio playback, vibrations, system volume, and notifications seamlessly.

## 🔧 Installation steps

Please carefully follow these installation steps. They have been updated for plugin version `3.0.0`.

### [iOS Setup](https://github.com/gdelataillade/alarm/blob/main/help/INSTALL-IOS.md)
### [Android Setup](https://github.com/gdelataillade/alarm/blob/main/help/INSTALL-ANDROID.md)

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
  volume: 0.8,
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
volume |   `double`     | Sets system volume level (0.0 to 1.0) at [dateTime]; reverts on alarm stop. Defaults to current volume if null.
fadeDuration |   `double`     | Duration, in seconds, over which to fade the alarm volume. Set to 0.0 by default, which means no fade.
notificationTitle |   `String`     | The title of the notification triggered when alarm rings.
notificationBody | `String` | The body of the notification.
enableNotificationOnKill |   `bool`     | Whether to show a notification when application is killed to warn the user that the alarm he set may not ring. Enabled by default.
androidFullScreenIntent |   `bool`     | Whether to turn screen on when android alarm notification is triggered. Enabled by default.

Note that if `notificationTitle` and `notificationBody` are both empty, iOS will not show the notification and Android will show an empty notification.

If you enabled `enableNotificationOnKill`, you can chose your own notification title and body by using this method before setting your alarms:
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

Don't hesitate to check out the [example's code](https://github.com/gdelataillade/alarm/tree/main/example), and take a look at the app:

![home](https://github.com/gdelataillade/alarm/assets/32983806/695736aa-b55f-4050-8b0d-274b0d46714a)
![edit](https://github.com/gdelataillade/alarm/assets/32983806/05329836-9fbe-462c-aa1e-dce0fa70f455)

## ⏰ Alarm behaviour

|                          | Sound | Vibrate | Volume | Notification
| ------------------------ | ----- | ------- | -------| -------
| Locked screen            |  ✅   | ✅       | ✅     | ✅
| Silent / Mute            |  ✅   | ✅       | ✅     | ✅
| Do not disturb           |  ✅   | ✅       | ✅     | Silenced
| Sleep mode               |  ✅   | ✅       | ✅     | Silenced
| While playing other media|  ✅   | ✅       | ✅     | ✅
| App killed               |  🤖   | 🤖       | 🤖     | ✅

✅ : iOS and Android.\
🤖 : Android only.\
Silenced: Means that the notification is not shown directly on the top of the screen. You have to go in your notification center to see it.

## ❓ FAQ

### Why didn't my alarm fire on iOS?

Several factors could prevent your alarm from ringing:
- Your iPhone was restarted (either from a manual reboot or due to an iOS update).
- The app was either manually terminated or was closed because of memory constraints.

### My alarm is not firing on a specific Android device

Some Android manufacturers prefer battery life over proper functionality of your apps. Check out [dontkillmyapp.com](https://dontkillmyapp.com) to find out about more about optimizations done by different vendors, and potential workarounds.
Most common solution is to educate users to disable **battery optimization** settings.
*Source: [android_alarm_manager_plus FAQ](https://pub.dev/packages/android_alarm_manager_plus#faq)*

### How can I increase the reliability of the alarm ringing?

The more time the app spends in the background, the higher the chance the OS might stop it from running due to memory or battery optimizations. Here's how you can optimize:

- **Battery Optimization**: Educate users to disable battery optimization on Android.
- **Regular App Usage**: Encourage users to open the app at least once a day.
- **Leverage Background Modes**: Engage in activities like weather API calls that keep the app active in the background.
- **User Settings**: Educate users to refrain from using 'Do Not Disturb' and 'Low Power Mode' when they're expecting the alarm to ring.

### How can I make my alarm periodic ?

While periodic alarms can be implemented on Android, this is not feasible for iOS. To maintain consistency between both platforms, I will not be adding this feature to the package (except if a solution is found). As an alternative, you could store the scheduled days for alarms and reset them for the upcoming week each time the app is launched.

Related issue [here](https://github.com/gdelataillade/alarm/issues/47#issuecomment-1820896276).

### Why was my app rejected by the App Store for guideline issues?

The rejection may relate to plugin's background audio functionality, essential for alarm apps. Clarify in your submission that background activity is crucial for your alarm app to notify users effectively. Ensure compliance with Apple's guidelines on background processes.

For more guidance, see: [App Store Rejection Issues](https://github.com/gdelataillade/alarm/discussions/87).

## ⚙️ Under the hood

### Android
Leverages a foreground service with AlarmManager scheduling to ensure alarm reliability, even if the app is terminated. Utilizes AudioManager for robust alarm sound management.

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
- [Android] Reschedule alarms after device reboot.
- Notification actions: stop and snooze.
- Use `ffigen` and `jnigen` binding generators to call native code more efficiently instead of using method channels.
- Stop alarm sound when notification is dismissed.

Thank you for considering contributing to this plugin. Your help is greatly appreciated!

🙏 Special thanks to the main contributors 🇫🇷
- [evolum](https://evolum.co)
- [WayUp](https://wayuphealth.fr)

❤️ Let me know if you like the plugin by liking it on [pub.dev](https://pub.dev/packages/alarm) and starring the repo on [Github](https://github.com/gdelataillade/alarm) 🙂