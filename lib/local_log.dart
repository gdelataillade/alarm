// ignore_for_file: empty_catches

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Static class for show and get native local log
class LocalLog {
  static const MethodChannel _methodChannel = MethodChannel('com.gdelataillade/loger');

  /// return all log lines in native file log
  static Future<List<String>> getNativeLogLines() async {
    final data = await _methodChannel.invokeMethod('getNativeLogs');
    try {
      if (data is List<dynamic>) {
        return data.cast<String>();
      }
    } catch (e) {}
    return [];
  }

  /// return path of native file log
  static Future<String?> getNativeLogFilePath() async {
    final data = await _methodChannel.invokeMethod('getNativeLogFilePath');
    if (data is String) {
      return data;
    } else {
      return null;
    }
  }

  /// Open new screen and show all logs
  static void showLogScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => _LogScreen()),
    );
  }

  /// Share log file
  static Future<void> shareLogFile() async {
    final filepath = await getNativeLogFilePath();
    if (filepath != null) {
      final file = File(filepath);
      if (file.existsSync()) {
        await Share.shareXFiles([XFile(file.path)], text: 'Log file');
      } else {
        throw Exception('No log file');
      }
    }
  }
}

/// Show screen with all log
class _LogScreen extends StatefulWidget {
  @override
  _LogScreenState createState() => _LogScreenState();
}

class _LogScreenState extends State<_LogScreen> {
  List<String> _logs = [];
  bool _isLoading = true;
  bool _isSendLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LocalLog.getNativeLogLines();

    setState(() {
      _logs = logs.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> sendLog() async {
    setState(() {
      _isSendLoading = true;
    });

    await LocalLog.shareLogFile();

    setState(() {
      _isSendLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: _isSendLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            onPressed: _isSendLoading ? null : sendLog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 3,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _logs[index],
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(fontFamily: 'Courier'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
