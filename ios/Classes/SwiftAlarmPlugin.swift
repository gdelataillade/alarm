import Flutter
import os.log

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "SwiftAlarmPlugin")

    private static var instance: SwiftAlarmPlugin? = nil

    private var api: AlarmApiImpl? = nil
    private var alarmTriggerApi: AlarmTriggerApi? = nil

    init(registrar: FlutterPluginRegistrar) {
        self.api = AlarmApiImpl(registrar: registrar)
        AlarmApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
        os_log(.info, log: SwiftAlarmPlugin.logger, "AlarmApi initialized.")
        self.alarmTriggerApi = AlarmTriggerApi(binaryMessenger: registrar.messenger())
        os_log(.info, log: SwiftAlarmPlugin.logger, "AlarmTriggerApi connected.")
    }

    public static func register(with registrar: any FlutterPluginRegistrar) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if instance != nil {
            os_log(.info, log: SwiftAlarmPlugin.logger, "Plugin already registered.")
            return
        }

        let plugin = SwiftAlarmPlugin(registrar: registrar)
        registrar.addApplicationDelegate(plugin)
        instance = plugin

        os_log(.info, log: SwiftAlarmPlugin.logger, "Plugin registered.")
    }

    /// Called from AppDelegate when the app is launched.
    public static func registerBackgroundTasks() {
        BackgroundTaskManager.setup()
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Redirect UNUserNotificationCenter delegate calls to NotificationManager.
        NotificationManager.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Redirect UNUserNotificationCenter delegate calls to NotificationManager.
        NotificationManager.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }

    static func getApi() -> AlarmApiImpl? {
        return SwiftAlarmPlugin.instance?.api
    }

    static func getTriggerApi() -> AlarmTriggerApi? {
        return SwiftAlarmPlugin.instance?.alarmTriggerApi
    }
}
