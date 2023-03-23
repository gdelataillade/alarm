# Alarm package for iOS and Android

This Flutter package provides a simple and easy-to-use interface for setting and canceling alarms on iOS and Android devices. It utilizes the `android_alarm_manager_plus` package for Android and the native iOS `AVAudioPlayer` class.

*Please note that this project is still in beta. Feel free to send us your issues, questions and suggestions to help us in the project development.*

## Why this package ?

As a Flutter developer at [Evolum](https://evolum.co), my CTO and I needed to develop an alarm feature for the new version of our app.

An alarm feature is a great way to increase users engagement.

For the Android part, we used `android_alarm_manager_plus` package, but to be honest it was not very intuitive and incomplete.

Then, for the iOS part, we couldn't find any package or tutorial to add this feature.

Another issue we found is that when a user kills the app, all processes are terminated so the alarm may not ring. The workaround we thought about was to show a notification when the user kills the app to warn him that the alarm may not ring. Then, he just has to reopen the app to reschedule the alarm.

Therefore, we decided to write our own package to wrap everything and make it easy for everybody.

## Under the hood

### Android
Uses `oneShotAt` from the `android_alarm_manager_plus` package with a two-way communication isolated callback to start/stop the alarm and call the `onRing` callback.

### iOS
Implements `invokeMethod` to play the alarm audio using `AVAudioPlayer`. Due to the suspension of asynchronous native code when the app is in the background, we listen for app state changes and check if the player is playing when the app returns to the foreground. If it's the case, it means the alarm is ringing, and it's time to trigger the `onRing` callback.

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

After that, add the following to your `AndroidManifest.xml` within the `<manifest></manifest>` tags:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<!-- For apps with targetSDK=31 (Android 12) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

Next, within the `<application></application>` tags, add:

```xml
<service
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="false"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

Finally, add your audio asset(s) to your project like usual.

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
  id: 42,
  dateTime: dateTime,
  assetAudioPath: 'assets/alarm.mp3',
  loopAudio: true,
  vibrate: true,
  fadeDuration: 3.0,
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
id |   `int`     | Unique identifier of the alarm.
alarmDateTime |   `DateTime`     | The date and time you want your alarm to ring.
assetAudio |   `String`     | The path to you audio asset you want to use as ringtone. Can be local asset or network URL.
loopAudio |   `bool`     | If true, audio will repeat indefinitely until alarm is stopped.
vibrate |   `bool`     | If true, device will vibrate indefinitely until alarm is stopped.
fadeDuration |   `double`     | Duration, in seconds, over which to fade the alarm volume. Set to 0 by default, which means no fade.
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

To avoid unexpected behaviors, if you set an alarm for the same time as an existing one, the new alarm will replace the existing one.

**Don't hesitate to check out the example's code, and take a look at the app:**

![alarm example 1](https://user-images.githubusercontent.com/32983806/225351833-5ced7b18-631f-4c2d-b8c8-13198f26900c.png)
![alarm example 2](https://user-images.githubusercontent.com/32983806/225352465-940a41fb-24d4-4abd-b7ba-28fae387abd0.png)

## Alarm behaviour

|                          | Sound | Vibrate | Notification
| ------------------------ | ----- | ------- | -------
| Locked screen            |  ✅   | ✅       | ✅
| Silent / Mute            |  ✅   | ✅       | ✅
| Do not disturb           |  ✅   | ✅       | Silenced
| Sleep mode               |  ✅   | ✅       | Silenced
| While playing other media|  ✅   | ✅       | ✅
| App killed               | ❌    | ❌       | ✅

*Silenced: Means that the notification is not shown directly on the top of the screen. You have to go to your notification center to see it.*

## FAQ

### My alarm is not firing on a specific Android device

Some Android manufacturers prefer battery life over proper functionality of your apps. Check out [dontkillmyapp.com](https://dontkillmyapp.com) to find out about more about optimizations done by different vendors, and potential workarounds. 
*Source: [https://pub.dev/packages/android_alarm_manager_plus#faq](https://pub.dev/packages/android_alarm_manager_plus#faq)*

## Feature request

If you have a feature request, just open an issue explaining clearly what you want and if you convince me I will develop it for you.

## Contributing

We welcome contributions to this package! If you would like to make a change or add a new feature, please follow these steps:

1.  Fork the repository and create a new branch for your changes.
2.  Make your changes
3.  Run `flutter format` and `flutter test` to ensure that your code is correctly formatted and passes all tests.
4.  Submit a pull request with a detailed description of your changes.

These are some features that I have in mind that could be useful:
- Use `ffigen` and `jnigen` binding generators to call native code more efficiently instead of using method channels.
- [Notification actions](https://pub.dev/packages/flutter_local_notifications#notification-actions): stop and snooze
- Add macOS, Windows, Linux and web support

Thank you for considering contributing to this package. Your help is greatly appreciated!

❤️ Let me know if you like the package by liking it on [pub.dev](https://pub.dev/packages/alarm) and starring the repo on [Github](https://github.com/gdelataillade/alarm) 🙂
