# Android Setup

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
Then, add the following to your `AndroidManifest.xml` within the `<manifest></manifest>` tags:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

## Step 3
Finally, if you want your notifications to show in full screen even when the device is locked, add these attributes in `<activity>`:

```xml
<activity
    android:showWhenLocked="true"
    android:turnScreenOn="true">
```