# Alarm package for iOS and Android

This Flutter package provides a simple and easy-to-use interface for setting and canceling alarms on iOS and Android devices. It utilizes the `android_alarm_manager_plus` package for Android and the native iOS `AVAudioPlayer` class.

## Why this package ?

As a Flutter developer at [Evolum](evolum.co), my CTO and I needed to develop an alarm feature for the new version of our app.

An alarm feature is a great way to increase users engagement.

For the Android part, we used `android_alarm_manager_plus` package, but to be honest it was not very intuitive.

Then, for the iOS part, we couldn't find any package or tutorial to add this feature.

Therefore, we decided to write our own package to wrap everything and make it easy for everybody.

## Under the hood
### Android
`oneShotAt` from the package `android_alarm_manager_plus`, with an two-way communication isolated callback in order to start/stop the alarm and call `onRing` callback.

### iOS
`invokeMethod` that plays the alarm audio using `AVAudioPlayer`.

The issue is that asynchronous native code is suspended when app goes on background for a while. The workaround found is to listen to the app state (when app goes background/foreground), and every time app goes foreground, we check natively if the player is playing. If so, it means alarm is ringing so it's time to trigger the `onRing` callback.

## Getting Started

Add to your pubspec.yaml:
```
flutter pub add flutter_fgbg
```

In order to use custom alarm audios, you will need to drag and drop your asset(s) to your `Runner` folder in Xcode, like [explained here](https://stackoverflow.com/a/49377095/10160176).

After that, you can start using the package initializing the Alarm service:
```Dart
Alarm.initialize();
```

Then, you can finally set your alarm:
```Dart
Alarm.set(
  alarmDateTime: dateTime,
  assetAudio: "alarm.mp3",
  onRing: () => setState(() => isRinging = true),
  notifTitle: 'Alarm notification',
  notifBody: 'Your alarm is ringing',
);
```

Property |   Type     | Description
-------- |------------| ---------------
alarmDateTime |   `DateTime`     | The date and time you want your alarm to ring
assetAudio |   `String`     | The path to you audio asset you want to use as ringtone.
loopMode |   `bool`     | If set to true, audio will repeat indefinitely until it is stopped.
onRing | `void Function()` | A callback that will be called at the moment the alarm starts ringing.
notifTitle |   `String`     | (optional) The title of the notification triggered when alarm rings if app is on background.
notifBody | `String` | (optional) The body of the notification.

The parameters `notifTitle` and `notifBody` are optional, but if you want a notification to be triggered, you will have to provide **both of them**.

This is how to stop/cancel your alarm:
```Dart
Alarm.stop()
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
- Optional vibrations when alarm rings
- [Notification actions](https://pub.dev/packages/flutter_local_notifications#notification-actions): stop and snooze
- Progressive alarm volume option
- Callback when alarm stops ringing
- Add macOS, Windows, Linux and web support

Thank you for considering contributing to this package. Your help is greatly appreciated!

❤️ Let me know if you like the package by liking it on pub.dev and starring the repo on Github 🙂
