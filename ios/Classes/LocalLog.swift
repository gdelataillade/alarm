import Flutter
import Foundation

public class LocalLog: NSObject {
    public static let shared = LocalLog()
    
    private let logFileName = "log.txt"
    private var channel: FlutterMethodChannel?

    public func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "com.gdelataillade/loger", binaryMessenger: registrar.messenger())
        channel?.setMethodCallHandler(handleMethodCall)
    }
    
    public func log(_ message: String) {
        NSLog(">> LOCALLOG : \(message)")
        appendLogToFile(message: message)
    }
    
    private func appendLogToFile(message: String) {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let currentDateTime = Date()
        let formattedDate = dateFormatter.string(from: currentDateTime)
        let logWithDate = "\(formattedDate) : \(message)\n"

        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(logFileName)
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    if let data = logWithDate.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    try logWithDate.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                NSLog("Error write log : \(error)")
            }
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getNativeLogs":
            getNativeLogLines(result: result)
        case "getNativeLogFilePath":
            getNativeLogFilePath(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getNativeLogLines(result: @escaping FlutterResult) {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(logFileName)
            do {
                let logContent = try String(contentsOf: fileURL, encoding: .utf8)
                let logLines = logContent.split(separator: "\n").filter { !$0.isEmpty }
                result(logLines)
            } catch {
                NSLog("Error read log file : \(error)")
                result(FlutterError(code: "UNAVAILABLE", message: "No log file", details: nil))
            }
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "No log file", details: nil))
        }
    }
    
    private func getNativeLogFilePath(result: @escaping FlutterResult) {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(logFileName)
            result(fileURL.path)
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "No log file", details: nil))
        }
    }
}
