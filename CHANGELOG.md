## 0.1.2
* Add more Android installation steps in the README.
* Add alarm behaviour details in the README.
* Fix Android alarm while screen is locked.

## 0.1.1
* Add `Alarm.hasAlarm` method.
* Fix: cancel on-application-kill notification warning when alarm starts ringing, instead of when user stops alarm. 
* Export `AlarmSettings` model in `Alarm` service so it's not necessary to import it separately anymore.

## 0.1.0
* **Breaking changes**: `Alarm.set` method now takes a `AlarmSettings` as only parameter.
* **Breaking changes**: You will have to create a `StreamSubscription` attached to `Alarm.ringStream.stream` in order to listen to the alarm ringing state now. This way, even if your app was previously killed, your custom callback can still be triggered.
* By default, if an alarm was set and the app is killed, a notification will be shown to warn
the user that the alarm may not ring, with the possibility to reopen the app and automatically reschedule the alarm.
To disable this feature, you can call the method `Alarm.toggleNotificationOnAppKill(false)`.
* Add notification on kill notification switch button in example app.
* Add some minor fixes and improvements.

## 0.0.5

* Add [a Gist](https://gist.github.com/gdelataillade/68834caacdd6727f1418e46788f70b53) in the README.md to explain how to import assets on Xcode without adding weight to your app.

## 0.0.4

* Fix android notification params

## 0.0.3

* Add more documentation
* Add package description in pubspec.yaml
* Refactor some Swift code

## 0.0.2

* Update links in the README.md

## 0.0.1

* Initial development release.