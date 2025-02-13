import BackgroundTasks
import Flutter

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
    static let backgroundTaskIdentifier: String = "com.gdelataillade.fetch"

    private static var instance: SwiftAlarmPlugin? = nil

    private var api: AlarmApiImpl? = nil
    private var alarmTriggerApi: AlarmTriggerApi? = nil

    init(registrar: FlutterPluginRegistrar) {
        self.api = AlarmApiImpl(registrar: registrar)
        AlarmApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
        NSLog("[SwiftAlarmPlugin] AlarmApi initialized.")
        self.alarmTriggerApi = AlarmTriggerApi(binaryMessenger: registrar.messenger())
        NSLog("[SwiftAlarmPlugin] AlarmTriggerApi connected.")
    }

    public static func register(with registrar: any FlutterPluginRegistrar) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if instance != nil {
            NSLog("[SwiftAlarmPlugin] Plugin already registered.")
            return
        }

        let plugin = SwiftAlarmPlugin(registrar: registrar)
        registrar.addApplicationDelegate(plugin)
        instance = plugin

        NSLog("[SwiftAlarmPlugin] Plugin registered.")
    }

    public func detachFromEngine(for registrar: any FlutterPluginRegistrar) {
        api = nil
        alarmTriggerApi = nil
        SwiftAlarmPlugin.instance = nil
        NSLog("[SwiftAlarmPlugin] Flutter engine detached.")
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        SwiftAlarmPlugin.instance?.api?.sendWarningNotification()
    }

    /// Runs from AppDelegate when the app is launched
    public static func registerBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.scheduleAppRefresh()
                DispatchQueue.main.async {
                    SwiftAlarmPlugin.instance?.api?.backgroundFetch()
                }
                task.setTaskCompleted(success: true)
            }
        } else {
            NSLog("[SwiftAlarmPlugin] BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }

    static func stopAlarm(id: Int) {
        do {
            try SwiftAlarmPlugin.instance?.api?.stopAlarm(alarmId: Int64(id))
        } catch {
            NSLog("[SwiftAlarmPlugin] Error stopping alarm with ID=\(id).")
        }
    }

    static func getTriggerApi() -> AlarmTriggerApi? {
        return SwiftAlarmPlugin.instance?.alarmTriggerApi
    }

    /// Enables background fetch
    static func scheduleAppRefresh() {
        if #available(iOS 13.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(15 * 60))
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
