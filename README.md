# Alarm package for iOS and Android

This Flutter package provides a simple and easy-to-use interface for setting and canceling alarms on iOS and Android devices. It utilizes the `android_alarm_manager_plus` package for Android and the native iOS `AVAudioPlayer` class.

## Why this package ?

As a Flutter developer at [Evolum](https://evolum.co), my CTO and I needed to develop an alarm feature for the new version of our app.

An alarm feature is a great way to increase users engagement.

For the Android part, we used `android_alarm_manager_plus` package, but to be honest it was not very intuitive and incomplete.

Then, for the iOS part, we couldn't find any package or tutorial to add this feature.

Another issue we found is that when a user kills the app, all processes are terminated so the alarm may not ring. The workaround we thought about was to show a notification when the user kills the app to warn him that the alarm may not ring, He just has to reopen the app to reschedule the alarm.

Therefore, we decided to write our own package to wrap everything and make it easy for everybody.

## Under the hood
### Android
`oneShotAt` from the package `android_alarm_manager_plus`, with an two-way communication isolated callback in order to start/stop the alarm and call `onRing` callback.

### iOS
`invokeMethod` that plays the alarm audio using `AVAudioPlayer`.

The issue is that asynchronous native code is suspended when app goes on background for a while. The workaround found is to listen to the app state (when app goes background/foreground), and every time app goes foreground, we check natively if the player is playing. If so, it means alarm is ringing so it's time to trigger the `onRing` callback.

## Getting Started

### iOS installation steps

To import your alarm audio(s), you will need to drag and drop your asset(s) to your `Runner` folder in Xcode. 
I published a Gist to show you the steps to follow, and also give you a tip to save your app some weight using symbolic links. It's [right here](https://gist.github.com/gdelataillade/68834caacdd6727f1418e46788f70b53).

### Android installation steps

In your `android/app/build.gradle`, make sure you have the following config:
```Gradle
android {
  compileSdkVersion 33
  [...]
  defaultConfig {
    [...]
    multiDexEnabled true
  }
}
```

Then, add your audio asset(s) to your project like usual.

## How to use

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
  dateTime: dateTime,
  assetAudioPath: 'assets/sample.mp3',
  loopAudio: true,
  notificationTitle: 'This is the title',
  notificationBody: 'This is the body',
  enableNotificationOnKill: true,
);
```

And finally set the alarm:
```Dart
await Alarm.set(settings: alarmSettings)
```

Property |   Type     | Description
-------- |------------| ---------------
alarmDateTime |   `DateTime`     | The date and time you want your alarm to ring.
assetAudio |   `String`     | The path to you audio asset you want to use as ringtone. Can be local asset or network URL.
loopMode |   `bool`     | If set to true, audio will repeat indefinitely until it is stopped.
notificationTitle |   `String`     | The title of the notification triggered when alarm rings if app is on background.
notificationBody | `String` | The body of the notification.
enableNotificationOnKill |   `bool`     | Whether to show a notification when application is killed to warn the user that the alarm he set may not ring. Enabled by default.

The notification shown on alarm ring can be disabled simply by ignoring the parameters `notificationTitle` and `notificationBody`. However, if you want a notification to be triggered, you will have to provide **both of them**.

If you enabled `enableNotificationOnKill`, you can chose your own notification title and body by using this method:
```Dart
await Alarm.setNotificationOnAppKillContent(title, body)
```

This is how to stop/cancel your alarm:
```Dart
await Alarm.stop()
```

This is how to run some code when alarm starts ringing. We implemented it as a stream so even if your app was previously killed, your custom callback can still be triggered.
```Dart
Alarm.ringStream.stream.listen((_) => yourOnRingCallback());
```

**Don't hesitate to check out the example's code, here's a screenshot:**

![example_app_screensot](https://user-images.githubusercontent.com/32983806/209820781-bb8d15fa-efc1-4f48-a1d3-bcfcaf9efccf.jpeg)

## Feature request

If you have a feature request, just open an issue explaining clearly what you want and if you convince me I will develop it for you.

## Contributing

We welcome contributions to this package! If you would like to make a change or add a new feature, please follow these steps:

1.  Fork the repository and create a new branch for your changes.
2.  Make your changes
3.  Run `flutter format` and `flutter test` to ensure that your code is correctly formatted and passes all tests.
4.  Submit a pull request with a detailed description of your changes.

These are some features that I have in mind that could be useful:
- Multiple alarms management
- Use `ffigen` and `jnigen` binding generators to call native code more efficiently instead of using method channels.
- Optional vibrations when alarm rings
- [Notification actions](https://pub.dev/packages/flutter_local_notifications#notification-actions): stop and snooze
- Progressive alarm volume option
- Callback when alarm stops ringing
- Add macOS, Windows, Linux and web support

Thank you for considering contributing to this package. Your help is greatly appreciated!

❤️ Let me know if you like the package by liking it on [pub.dev](https://pub.dev/packages/alarm) and starring the repo on [Github](https://github.com/gdelataillade/alarm) 🙂
