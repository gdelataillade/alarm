![Pub Version](https://img.shields.io/pub/v/alarm)
![Pub Likes](https://img.shields.io/pub/likes/alarm)
![Pub Points](https://img.shields.io/pub/points/alarm)
![Pub Downloads](https://img.shields.io/pub/dm/alarm)

[![alarm](https://github.com/gdelataillade/alarm/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/gdelataillade/alarm/actions/workflows/main.yml)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![GitHub Sponsor](https://img.shields.io/github/sponsors/gdelataillade?label=Sponsor&logo=GitHub)](https://github.com/sponsors/gdelataillade)

# Alarm plugin for iOS and Android

This plugin offers a straightforward interface to set and cancel alarms on both iOS and Android devices. Using native code, it handles audio playback, vibrations, system volume, and notifications seamlessly.

## 📋 Table of contents
- [🔧 Installation steps](#-installation-steps)
- [📖 How to use](#-how-to-use)
  - [AlarmSettings model](#alarmsettings-model)
  - [NotificationSettings model](#notificationsettings-model)
  - [VolumeSettings model](#volumesettings-model)
- [📱 Example app](#-example-app)
- [⏰ Alarm behaviour](#-alarm-behaviour)
- [📋 Logging](#-logging)
- [❓ FAQ](#-faq)
- [⚙️ Under the hood](#️-under-the-hood)
- [✉️ Feature request](#️-feature-request)
- [💙 Contributing](#-contributing)

## 🔧 Installation steps

Please carefully follow these installation steps. They have been updated for plugin version `5.0.0`.

### [iOS Setup](https://github.com/gdelataillade/alarm/blob/main/help/INSTALL-IOS.md)
### [Android Setup](https://github.com/gdelataillade/alarm/blob/main/help/INSTALL-ANDROID.md)

## 📖 How to use

Add to your pubspec.yaml:
```Bash
flutter pub add alarm
```

First, you have to initialize the Alarm service in your `main` function:
```Dart
WidgetsFlutterBinding.ensureInitialized();
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
  warningNotificationOnKill: Platform.isIOS,
  androidFullScreenIntent: true,
  volumeSettings: VolumeSettings.fade(
    volume: 0.8,
    fadeDuration: Duration(seconds: 5),
    volumeEnforced: true,
  ),
  notificationSettings: const NotificationSettings(
    title: 'This is the title',
    body: 'This is the body',
    stopButton: 'Stop the alarm',
    icon: 'notification_icon',
    iconColor: Color(0xff862778),
  ),
);
```

And finally set the alarm:
```Dart
await Alarm.set(alarmSettings: alarmSettings)
```

### AlarmSettings model
| Property                                            | Type                   | Description                                                                                                                                                                                          |
| --------------------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| id                                                  | `int`                  | Unique identifier of the alarm.                                                                                                                                                                      |
| dateTime                                            | `DateTime`             | The date and time you want your alarm to ring.                                                                                                                                                       |
| assetAudioPath                                      | `String?`              | The path to your audio asset you want to use as ringtone. Can be a path in your assets folder or a local file path with Android permission. If `null`, the device's default alarm sound will be used. |
| loopAudio                                           | `bool`                 | If true, audio will repeat indefinitely until alarm is stopped.                                                                                                                                      |
| vibrate                                             | `bool`                 | If true, device will vibrate indefinitely until alarm is stopped. If [loopAudio] is set to false, vibrations will stop when audio ends.                                                              |
| warningNotificationOnKill                           | `bool`                 | Whether to show a notification when application is killed to warn the user that the alarm he set may not ring. Recommended for iOS. Enabled by default.                                              |
| androidFullScreenIntent                             | `bool`                 | Whether to turn screen on when android alarm notification is triggered. Enabled by default.                                                                                                          |
| allowAlarmOverlap                                   | `bool`                 | Whether the alarm should ring if another alarm is already ringing. Disabled by default.                                                                                                              |
| androidStopAlarmOnTermination                       | `bool`                 | Whether to stop the alarm when an Android task is terminated. Enabled by default.                                                                                                                    |
| preferConnectedAudioDevice                          | `bool`                 | If true, routes alarm audio to a connected earphone or Bluetooth device when present, falling back to the built-in speaker if not. Uses the media volume slider instead of the alarm slider. Has no effect on iOS. Disabled by default. |
| payload                                             | `String?`              | Optional data sent with the alarm. Caller handles serialization and parsing.                                                                                                                         |
| androidSnoozeDuration                               | `Duration?`            | How long the snooze action defers the alarm. Android only. With a `NotificationSettings.androidSnoozeButton` label, the notification offers a snooze that stops the ring and re-registers the alarm this far ahead. Minimum one minute. No snooze if null. |
| [notificationSettings](#notificationsettings-model) | `NotificationSettings` | Settings for notification title, body, icon, icon color and action buttons (only stop at the moment).                                                                                                |
| [volumeSettings](#volumesettings-model)             | `VolumeSettings`       | Settings for alarm volume and fade durations.                                                                                                                                                        |


If you enabled `warningNotificationOnKill`, you can choose your own notification title and body by using this method before setting your alarms:
```Dart
await Alarm.setWarningNotificationOnKill(title, body)
```

The property `androidStopAlarmOnTermination` works only on Android as on iOS the alarm is naturally stopped by the system when the app is terminated (as the native code can no longer run).

Since Android 13, a foreground service notification can be swiped away by the user, so the alarm notification is dismissible even though it is marked ongoing. By default that swipe stops the alarm, exactly like the stop button. Set `NotificationSettings.androidStopAlarmOnDismiss` to `false` if a stray swipe must not be able to silence an alarm — be aware that the notification is then gone while the alarm keeps ringing, so your app should offer another way to stop it — for example a dedicated ringing screen, as described in [Presenting the alarm on your own screen](#presenting-the-alarm-on-your-own-screen).

### NotificationSettings model

| Property                       | Type      | Description                                                                        |
| ------------------------------ | --------- | ---------------------------------------------------------------------------------- |
| title                          | `String`  | Title of the alarm notification.                                                   |
| body                           | `String`  | Body of the alarm notification.                                                    |
| stopButton                     | `String?` | Text shown in the stop button of the alarm notification. Button not shown if null. |
| androidSnoozeButton            | `String?` | Text shown in the snooze button of the alarm notification. Android only. Shown only when `AlarmSettings.androidSnoozeDuration` also gives it a usable duration. |
| icon                           | `String?` | Icon to display on the notification. Only customizable on Android.                 |
| iconColor                      | `Color?`  | Color of the notification icon. Only customizable on Android.                      |
| keepNotificationAfterAlarmEnds | `bool`    | Keeps the notification visible after the alarm sound ends. iOS only.               |
| androidStopAlarmOnDismiss      | `bool`    | Whether swiping the notification away also stops the alarm. Android only. Enabled by default. |


### VolumeSettings model

| Property       | Type                   | Description                                                                                                 |
| -------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------- |
| volume         | `double?`              | Sets system volume level (0.0 to 1.0). Reverts on alarm stop. Defaults to current volume if null.           |
| fadeDuration   | `Duration?`            | Duration over which to fade the alarm ringtone. Null means no fade.                                         |
| fadeSteps      | `List<VolumeFadeStep>` | Controls how the alarm volume will fade over time.                                                          |
| volumeEnforced | `bool`                 | Automatically resets to the original alarm [volume] if the user attempts to adjust it. Disabled by default. |

This is how to stop/cancel your alarm:
```Dart
await Alarm.stop(id)
```

This is how to run some code when alarm starts ringing.
```Dart
Alarm.ringing.listen((AlarmSet alarmSet) {
  for (final alarm in alarmSet.alarms) {
    // yourOnRingCallback
  }
});
```
You can also listen to the `Alarm.updateStream` to know when an alarm is added, updated, or stopped.

To avoid unexpected behaviors, if you set an alarm for the same time, down to the second, as an existing one, the new alarm will replace the existing one.

If you need to schedule multiple alarms with different ids for the exact same second, you can set `allowSameSecondScheduling` to `true`:

```dart
AlarmSettings(
  id: 1,
  dateTime: dateTime,
  allowSameSecondScheduling: true,
  // ...
)
```

When `allowSameSecondScheduling` is enabled:
- Alarms with the **same id** still replace each other
- Alarms with **different ids** can be scheduled for the same second
- How they ring depends on `allowAlarmOverlap`:
  - `allowAlarmOverlap = false` (default): Alarms ring **sequentially** one after another — just like the iOS system Clock app. The first alarm rings first; when it stops, the next queued alarm starts ringing automatically.
  - `allowAlarmOverlap = true`: Alarms ring **concurrently** — the later alarm will override the previous one and continue ringing.
- These two options are independent and can be combined as needed

## 📱 Example app

Don't hesitate to check out the [example's code](https://github.com/gdelataillade/alarm/tree/main/example), and take a look at the app:

![home](https://github.com/gdelataillade/alarm/assets/32983806/501f5fc5-02f4-4a8b-b662-4cbf8f1b2b4c)
![edit](https://github.com/gdelataillade/alarm/assets/32983806/0cb3e9e1-0efd-4112-b6b7-d9d474d56d10)


## ⏰ Alarm behaviour

|                           | Sound | Vibrate | Volume | Notification |
| ------------------------- | ----- | ------- | ------ | ------------ |
| Locked screen             | ✅     | ✅       | ✅      | ✅            |
| Silent / Mute             | ✅     | ✅       | ✅      | ✅            |
| Do not disturb            | ✅     | ✅       | ✅      | Silenced     |
| Sleep mode                | ✅     | ✅       | ✅      | Silenced     |
| While playing other media | ✅     | ✅       | ✅      | ✅            |
| App killed                | 🤖     | 🤖       | 🤖      | ✅            |

✅ : iOS and Android.\
🤖 : Android only.\
Silenced: Means that the notification is not shown directly on the top of the screen. You have to go in your notification center to see it.

## 📋 Logging

This plugin uses the [logging package](https://pub.dev/packages/logging) to log information. If you aren't already, (optional) you'll need to install and configure the logging package to see these logs.

An example can be found in `example/lib/utils/logging.dart`. This file defines a `setupLogging` method which is called from `main.dart`.

## ❓ FAQ

### Why didn't my alarm fire on iOS?

Several factors could prevent your alarm from ringing:
- Your iPhone was restarted (either from a manual reboot or due to an iOS update).
- The app was either manually terminated or was closed because of memory constraints.
- See [flutter_alarmkit](https://pub.dev/packages/flutter_alarmkit) for a more robust way to manage alarms on iOS.

### My alarm is not firing on a specific Android device

Some Android manufacturers prefer battery life over proper functionality of your apps. Check out [dontkillmyapp.com](https://dontkillmyapp.com) to find out about more about optimizations done by different vendors, and potential workarounds.
Most common solution is to educate users to disable **battery optimization** settings.
*Source: [android_alarm_manager_plus FAQ](https://pub.dev/packages/android_alarm_manager_plus#faq)*

### Why can’t I dismiss my Android alarm notification?

The alarm plugin uses Android’s Foreground Service to ensure the alarm can trigger even if the app is killed. For Android 12+, notifications from foreground services cannot be dismissed due to new Android rules. This ensures users are always aware of ongoing processes that might affect battery life or device performance.

### How can I increase the reliability of the alarm ringing?

The more time the app spends in the background, the higher the chance the OS might stop it from running due to memory or battery optimizations. Here's how you can optimize:

- **Battery Optimization**: Educate users to disable battery optimization on Android.
- **Regular App Usage**: Encourage users to open the app at least once a day.
- **Leverage Background Modes**: Engage in activities like weather API calls that keep the app active in the background.
- **User Settings**: Educate users to refrain from using 'Do Not Disturb' and 'Low Power Mode' when they're expecting the alarm to ring.

### How can I make my alarm periodic ?

While periodic alarms can be implemented on Android, this is not feasible for iOS. To maintain consistency between both platforms, I will not be adding this feature to the package (except if a solution is found). As an alternative, you could store the scheduled days for alarms and reset them for the upcoming week each time the app is launched.

Related issue [here](https://github.com/gdelataillade/alarm/issues/47#issuecomment-1820896276).

### Why does my app crash on iOS?

Crashes such as `EXC_BAD_ACCESS KERN_INVALID_ADDRESS` occur if `Alarm.set` and `Alarm.stop` methods are called concurrently, as they both modify shared resources. To prevent this, ensure each method call is completed before starting the next by using the `await` keyword in Dart:
```
await Alarm.set
await Alarm.stop
```
This approach ensures safe and exclusive access to shared resources, preventing crashes.


### Why was my app rejected by the **App Store** ?

The rejection may relate to plugin's background audio functionality, essential for alarm apps. Clarify in your submission that background activity is crucial for your alarm app to notify users effectively. Ensure compliance with Apple's guidelines on background processes.

For more guidance, see: [App Store Rejection Issues](https://github.com/gdelataillade/alarm/discussions/87).

### Why was my app rejected by the **Play Store** ?

If your app was rejected by Google due to restrictions on the `USE_FULL_SCREEN_INTENT` permission, it is because Google has implemented strict policies regarding the use of this permission to ensure user safety and prevent misuse. What you can do is either remove the declaration of this permission from your app or provide a strong justification and request users to manually grant the permission through the app settings.

See more here: [#222](https://github.com/gdelataillade/alarm/issues/222)

## ⚙️ Under the hood

### How does `alarm` work?

Check out this interactive walkthrough of the `alarm` codebase on CodeCanvas [here](https://www.code-canvas.com/?session=unauthenticatedGithub&repo=alarm&owner=gdelataillade&branch=main).

<img width="1916" alt="image" src="https://github.com/user-attachments/assets/3f85c1c0-5348-4eed-bfa8-de8852925826" />


### Android
Leverages a foreground service with AlarmManager scheduling to ensure alarm reliability, even if the app is terminated. Utilizes AudioManager for robust alarm sound management.

#### Presenting the alarm on your own screen

By default the full screen intent opens your launcher activity, so your whole
app becomes what the lock screen shows.

If you'd rather present the alarm on a dedicated screen, declare an activity
that handles `com.gdelataillade.alarm.action.RING` and the plugin will open it
instead:

```xml
<activity
    android:name=".AlarmActivity"
    android:exported="false"
    android:launchMode="singleInstance"
    android:taskAffinity="your.package.alarm"
    android:excludeFromRecents="true"
    android:showWhenLocked="true"
    android:turnScreenOn="true">
    <intent-filter>
        <action android:name="com.gdelataillade.alarm.action.RING"/>
        <category android:name="android.intent.category.DEFAULT"/>
    </intent-filter>
</activity>
```

A separate `taskAffinity` puts it in a task of its own, so finishing it returns
the user to whatever the alarm interrupted instead of into your app.

The launching intent carries what the screen needs to render without a Flutter
engine, which is the normal case since a full screen intent starts the process
without starting Flutter:

| Extra | Value |
| --- | --- |
| `alarmId` | The alarm's id, to act on it |
| `alarmTitle`, `alarmBody` | From `NotificationSettings` |
| `alarmStopLabel` | `NotificationSettings.stopButton` |
| `alarmSnoozeLabel` | `NotificationSettings.androidSnoozeButton`, or null when this alarm cannot be snoozed |

Resolve the alarm by broadcasting to `AlarmReceiver`. The receiver declares no
intent filter, so the broadcast has to name it explicitly:

```kotlin
// Dismiss the alarm.
context.sendBroadcast(
    Intent(context, AlarmReceiver::class.java).apply {
        action = "com.gdelataillade.alarm.ACTION_STOP"
        putExtra("id", alarmId)
    }
)

// Or defer it, if alarmSnoozeLabel was non-null.
context.sendBroadcast(
    Intent(context, AlarmReceiver::class.java).apply {
        action = "com.gdelataillade.alarm.ACTION_SNOOZE"
        putExtra("id", alarmId)
    }
)
```

Only offer snooze when `alarmSnoozeLabel` is non-null — it is gated on exactly
the same condition as the notification's own snooze action, so a null label
means the alarm has no usable snooze duration and the broadcast would be
ignored.

Your activity also becomes what tapping the notification opens, not only what
the full screen intent opens — once declared, it is the alarm surface for both.

Nothing tells your activity that the alarm ended for another reason: the audio
finished, `Alarm.stop()` was called from Dart, or a queued alarm was promoted.
Observe `AlarmRingingLiveData.instance` and finish when it turns false — it goes
false once no alarm is ringing at all.

Declaring no such activity keeps the previous behaviour.

#### Snooze

Give an alarm an `androidSnoozeDuration` and its notification an
`androidSnoozeButton` label, and the notification offers a snooze that stops
the current ring and re-registers the alarm that far ahead:

```Dart
AlarmSettings(
  // ...
  androidSnoozeDuration: const Duration(minutes: 9),
  notificationSettings: const NotificationSettings(
    title: 'Wake up',
    body: '',
    stopButton: 'Stop',
    androidSnoozeButton: 'Snooze',
  ),
);
```

Both are required. A label with no duration describes an action the platform
cannot perform, and a duration with no label gives the user no way to invoke
it; either on its own logs a warning and offers no snooze.

The duration must be at least `AlarmSettings.minSnoozeDuration` (one minute).
Below that, Android stops scheduling through `AlarmManager` and falls back to
an in-process timer that survives neither app termination nor cancellation, so
a shorter snooze could be neither guaranteed nor undone.

A snooze is reported as `Alarm.snoozed`, never as a stop, because the alarm is
still owed:

```Dart
Alarm.snoozed.listen((snooze) {
  print('Alarm ${snooze.id} rings again at ${snooze.nextRingAt}');
});
```

The alarm also leaves `Alarm.ringing` and reappears in `Alarm.scheduled` with
its new `dateTime`, so an app that tracks alarm state through those streams
needs no special handling.

The button is normally pressed with **no Flutter engine running**, since the
notification is native and the process may not be up. The deferral is recorded
natively and applied on the next `Alarm.init()`, before any reconciliation, so
your app never sees an alarm whose time moved with nothing explaining why. The
record is kept until Dart confirms it stored the new time, so a crash in
between loses nothing, and applying the same deferral twice does nothing the
second time.

> **Subscribe to `Alarm.snoozed` before calling `Alarm.init()`** if you want
> those replayed deferrals. It is a plain broadcast stream with no buffering, so
> a deferral replayed during `init()` is delivered only to listeners that
> already exist. `Alarm.scheduled` has no such constraint — it replays its
> latest value to new listeners — so an app that only needs the alarm's new time
> can read it there instead.

Snoozing an alarm that is not currently scheduled, or whose snooze time has
already passed, is refused rather than applied — a deferral is never allowed to
rewrite an alarm into the past, where the next reconciliation pass would delete
it.

One caveat, inherited from how overlapping alarms work generally: if a snoozed
alarm comes back round while a different alarm is ringing and
`allowAlarmOverlap` is false, it is discarded rather than queued. Set
`allowAlarmOverlap` or `allowSameSecondScheduling` if your app can have several
alarms due close together.

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

These are some features that have been the most requested by the community:
- Add actions on notification tap or dismiss. ([#30](https://github.com/gdelataillade/alarm/issues/30), [#207](https://github.com/gdelataillade/alarm/issues/207), [#244](https://github.com/gdelataillade/alarm/issues/244))
- Add timezone change support. ([#164](https://github.com/gdelataillade/alarm/issues/164))
- Use `ffigen` and `jnigen` binding generators to call native code more efficiently instead of using method channels.

Thank you for considering contributing to this plugin. Your help is greatly appreciated!

🙏 Special thanks to the main contributors:
- [evolum](https://evolum.co)
- [WayUp](https://wayuphealth.fr)
- [orkun1675](https://github.com/orkun1675)

❤️ Let me know if you like the plugin by liking it on [pub.dev](https://pub.dev/packages/alarm) and starring the repo on [Github](https://github.com/gdelataillade/alarm) 🙂

[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/gdelataillade)
