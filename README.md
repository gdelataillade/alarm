# Alarm package for iOS and Android

This Flutter package provides a simple and easy-to-use interface for setting and canceling alarms on iOS and Android devices. It utilizes the `android_alarm_manager_plus` package for Android and the native iOS `AVAudioPlayer` class.

## Why this package ?

As a Flutter developer at Evolum, my CTO and I needed to develop an alarm feature for the new version of our app: [evolum.co](evolum.co)
An alarm feature is a great way to increase users engagement.

For the Android part, we used `android_alarm_manager_plus` package, but to be honest it was not very intuitive.
Then, for the iOS part, we couldn't find any package or tutorial to add this feature.
Therefore, we decided to write our own package to wrap everything and make things easy.

## Under the hood

### Android
`oneShotAt` from the package `android_alarm_manager_plus`, with an isolated callback with two-way communication in order to start and stop the alarm.

### iOS
`invokeMethod` that plays the alarm audio using AVAudioPlayer, including a callback that is triggered once alarm starts to ring

## Getting Started

To use this package, add `alarm` as a dependency in your `pubspec.yaml` file.

First, you have to initialize the Alarm service:
```
Alarm.initialize();
```

Then, you can finally set your alarm:
```
Alarm.set(
  alarmDateTime: dateTime,
  onRing: () => setState(() =>  ring  =  true),
  notifTitle: 'Alarm notification',
  notifBody: 'Your alarm is ringing',
);
```

The parameters `notifTitle` and `notifBody` are optional. If provide both of them, a notification will be triggered once the alarm starts to ring in the case where your app is in background.

## Feature request

If you have a feature request, just open an issue explaining clearly what you want and if you convince me I will develop it for you.

## Contributing

We welcome contributions to this package! If you would like to make a change or add a new feature, please follow these steps:

1.  Fork the repository and create a new branch for your changes.
2.  Make your changes
3.  Run `flutter format` and `flutter test` to ensure that your code is correctly formatted and passes all tests.
4.  Submit a pull request with a detailed description of your changes.

These are some features that could be useful that I have in mind:
- Vibrations when alarm rings
- [Notification actions](https://pub.dev/packages/flutter_local_notifications#notification-actions): stop and snooze

Thank you for considering contributing to this package. Your help is greatly appreciated!
