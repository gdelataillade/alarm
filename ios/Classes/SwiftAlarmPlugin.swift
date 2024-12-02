import BackgroundTasks
import Flutter

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
    static let backgroundTaskIdentifier: String = "com.gdelataillade.fetch"

    private static var api: AlarmApiImpl? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        self.api = AlarmApiImpl(registrar: registrar)
        AlarmApiSetup.setUp(binaryMessenger: registrar.messenger(), api: self.api)
        NSLog("[SwiftAlarmPlugin] AlarmApi initialized.")
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        SwiftAlarmPlugin.api?.sendWarningNotification()
    }

    /// Runs from AppDelegate when the app is launched
    public static func registerBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.scheduleAppRefresh()
                DispatchQueue.main.async {
                    SwiftAlarmPlugin.api?.backgroundFetch()
                }
                task.setTaskCompleted(success: true)
            }
        } else {
            NSLog("[SwiftAlarmPlugin] BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }

    static func unsaveAlarm(id: Int) {
        SwiftAlarmPlugin.api?.unsaveAlarm(id: id)
    }

    /// Enables background fetch
    static func scheduleAppRefresh() {
        if #available(iOS 13.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                NSLog("[SwiftAlarmPlugin] Could not schedule app refresh: \(error)")
            }
        } else {
            NSLog("[SwiftAlarmPlugin] BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }

    /// Disables background fetch
    static func cancelBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        } else {
            NSLog("[SwiftAlarmPlugin] BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }
}
