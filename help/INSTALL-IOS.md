# iOS Setup

## Step 1
First, open your project in Xcode, select your Runner and then Signing & Capabilities tab. In the Background Modes section, make sure to enable:
- [x] Audio, AirPlay, and Picture in Picture
- [x] Background fetch

![bg-mode](https://github.com/gdelataillade/alarm/assets/32983806/13716845-5fb0-4fef-a762-292c374840bb)

This allows the app to check alarms in the background.

## Step 2
Then, open your Info.plist and add the key `Permitted background task scheduler identifiers`, with the item `com.gdelataillade.fetch` inside.

![info-plist](https://github.com/gdelataillade/alarm/assets/32983806/caa1060e-c046-4eae-b1ea-5f3145b8fed4)


It should add this in your Info.plist code:
```XML
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>com.gdelataillade.fetch</string>
	</array>
```

This authorizes the app to run background tasks using the specified identifier.

## Step 3
Open your AppDelegate and add the following imports:

```Swift
import UserNotifications
import alarm
```

Finally, add the following to your `application(_:didFinishLaunchingWithOptions:)` method:

```Swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
}
SwiftAlarmPlugin.registerBackgroundTasks()
```

![app-delegate](https://github.com/gdelataillade/alarm/assets/32983806/fcc00495-ecf0-4db3-9964-89bbedf577a7)

This configures the app to manage foreground notifications and setup background tasks.

Don't forget to run `pod install --repo-update` to update your pods.