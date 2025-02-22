import BackgroundTasks
import os.log

class BackgroundTaskManager: NSObject {
    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "BackgroundTaskManager")
    private static let backgroundTaskIdentifier: String = "com.gdelataillade.fetch"

    private static var enabled: Bool = false

    static func setup() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            // Schedule the next task:
            self.enable()

            // Run the task:
            Task {
                await SwiftAlarmPlugin.getApi()?.appRefresh()
                task.setTaskCompleted(success: true)
                os_log(.debug, log: BackgroundTaskManager.logger, "App refresh task executed.")
            }
        }
        os_log(.debug, log: BackgroundTaskManager.logger, "App refresh task listener registered.")
    }

    static func enable() {
        if enabled {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(15 * 60))

        do {
            try BGTaskScheduler.shared.submit(request)
            os_log(.debug, log: BackgroundTaskManager.logger, "App refresh task submitted.")
        } catch {
            os_log(.debug, log: BackgroundTaskManager.logger, "Could not schedule app refresh task: %@", error.localizedDescription)
        }

        enabled = true
    }

    static func disable() {
        if !enabled {
            return
        }

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        enabled = false
        os_log(.debug, log: BackgroundTaskManager.logger, "App refresh task cancelled.")
    }
}
