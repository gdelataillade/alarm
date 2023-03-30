## 0.2.5
* [iOS] Fix vibrations: cancel callback if alarm is stopped.

## 0.2.4
* Fix zoned notification schedule date shift

## 0.2.3
* [Android] Fix [NotificationOnKillService] for API 31+

## 0.2.2
* Improve documentation.
* Add [showDebugLogs] optional parameter to [Alarm.init] method.

## 0.2.1
* Add optional [vibrate] parameter, to toggle vibrations when alarm rings.

## 0.2.0
* **Breaking changes**: Add multiple alarm management. Now, you have to provide a unique [id] to [AlarmSettings].
* Update example application.
* [Android] Fix potential delay between notification and alarm sound.

## 0.1.5
* Schedule notification with precision to the given second.

## 0.1.4
* [Android] Fix notification permission for Android 13.

## 0.1.3
* Add optional [fadeDuration] parameter, which is the duration, in seconds, over which to fade the alarm volume.

## 0.1.2
* Add more Android installation steps in the README.
* Add alarm behaviour details in the README.
* [Android] Fix alarm while screen is locked.

## 0.1.1
* Add [Alarm.hasAlarm] method.
* Fix: cancel on-application-kill notification warning when alarm starts ringing, instead of when user stops alarm. 
* Export [AlarmSettings] model in [Alarm] service so it's not necessary to import it separately anymore.

## 0.1.0
* **Breaking changes**: [Alarm.set] method now takes a [AlarmSettings] as only parameter.
* **Breaking changes**: You will have to create a `StreamSubscription` attached to [Alarm.ringStream.stream] in order to listen to the alarm ringing state now. This way, even if your app was previously killed, your custom callback can still be triggered.
* By default, if an alarm was set and the app is killed, a notification will be shown to warn
the user that the alarm may not ring, with the possibility to reopen the app and automatically reschedule the alarm.
To disable this feature, you can call the method [Alarm.toggleNotificationOnAppKill(false)].
* Add notification on kill notification switch button in example app.
* Add some minor fixes and improvements.

## 0.0.5
* Add [a Gist](https://gist.github.com/gdelataillade/68834caacdd6727f1418e46788f70b53) in the README.md to explain how to import assets on Xcode without adding weight to your app.

## 0.0.4
* [Android] Fix notification parameters.

## 0.0.3
* Add more documentation.
* Add plugin description in pubspec.yaml.
* Refactor some Swift code.

## 0.0.2
* Update links in the README.md.

## 0.0.1
* Initial development release.