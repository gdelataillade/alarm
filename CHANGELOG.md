## 1.1.5
* [Android] Fix null isolate SendPort error on stop.

## 1.1.4
* Add Flutter audio asset import from Swift. It's no longer needed to import your assets in Xcode too.

## 1.1.3
* Remove unecessary exception on init.

## 1.1.2
* Fix notification schedule date.

## 1.1.1
* Update plugin's dependencies.
* Increment Android minimum version to API 19 (4.4).

## 1.1.0
* Add support for downloaded audio local files.
* Remove support for network audio files, which was unstable.

## 1.0.5
* Update plugin's dependencies.

## 1.0.4
* Add a FAQ item in README

## 1.0.3
* Add optional [stopOnNotificationOpen] parameter to stop alarm when notification is opened.

## 1.0.2
* Add `getAlarm(id)` method.
* [Android] Fix isolate unfound port error.

## 1.0.1
* [iOS] Fix alarm sound from background mode.

## 1.0.0
* Alarm plugin is now ready for production. Breaking changes will be released in major version releases from now.
* Add some minor improvements.
* Update README.md

## 0.2.9
* Add custom debug print method.

## 0.2.8
* [iOS] Prevent unnecessary callbacks when alarm is stopped.

## 0.2.7
* If [loopAudio] is set to false, stop vibrations when audio ends.
* [iOS] Avoid crash if provided audio url is wrong.

## 0.2.6
* [Android] Fix vibrations which were triggered even when disabled.

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