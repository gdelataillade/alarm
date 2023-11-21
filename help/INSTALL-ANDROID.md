# Android Setup

If you are using a plugin version below `3.0.0`, follow [these installation steps](https://github.com/gdelataillade/alarm/blob/a2b736807e03ae1f3a60f234ad0b4f686ac59520/help/INSTALL-ANDROID.md) instead.

## Step 1
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

## Step 2
Then, add the following permissions to your `AndroidManifest.xml` within the `<manifest></manifest>` tags:

```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.WAKE_LOCK"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  <uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

See more details on Android permissions [here](https://developer.android.com/reference/android/Manifest.permission).

## Step 3
Finally, if you want your notifications to show in full screen even when the device is locked (`androidFullScreenIntent` parameter), add these attributes in `<activity>`:

```xml
<activity
    android:showWhenLocked="true"
    android:turnScreenOn="true">
```

## Step 4
Inside the <application> tag of your AndroidManifest.xml, add the following declarations:
```xml
<application>
  [...]
  <service android:name="com.gdelataillade.alarm.services.NotificationOnKillService" />
  [...]
</application>
```

This setup is essential for managing notifications, especially when the app is terminated or the device is rebooted.

## Additional Resource

For a practical implementation example, you can refer to the example's Android manifest in the plugin repository. This might help you better understand the setup and integration:

[Example AndroidManifest.xml](https://github.com/gdelataillade/alarm/blob/main/example/android/app/src/main/AndroidManifest.xml)
