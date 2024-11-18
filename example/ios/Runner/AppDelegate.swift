import UIKit
import Flutter
import UserNotifications
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    SwiftAlarmPlugin.registerBackgroundTasks()

    GeneratedPluginRegistrant.register(with: self)

    LocalLog.shared.log("[AppDelegate] call didFinishLaunchingWithOptions()")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .sound])
  }

  //LOCAL LOG
  override func applicationDidBecomeActive(_ application: UIApplication) {
      LocalLog.shared.log("[AppDelegate] call applicationDidBecomeActive()")
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
      LocalLog.shared.log("[AppDelegate] call applicationWillTerminate()")
  }
    
  override func applicationWillResignActive(_ application: UIApplication) {
      LocalLog.shared.log("[AppDelegate] call applicationWillResignActive()")
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
      LocalLog.shared.log("[AppDelegate] call applicationDidEnterBackground()")
  }
}
