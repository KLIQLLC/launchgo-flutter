import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CallDebugLogger {
  static const String _fileName = 'call_debug.log';
  static File? _logFile;
  static bool _isWriting = false;
  static final List<String> _logQueue = [];

  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/$_fileName');
    if (!await _logFile!.exists()) {
      await _logFile!.create();
    }
    // Clear previous session logs and add new session marker
    await _logFile!.writeAsString(
      '=== NEW SESSION ${DateTime.now().toIso8601String()} ===\n',
    );
  }

  static Future<void> log(String message) async {
    if (_logFile == null) {
      await init();
    }

    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';

    // Also print to console for immediate visibility
    debugPrint(logMessage);

    _logQueue.add(logMessage);
    _processQueue();
  }

  static Future<void> _processQueue() async {
    if (_isWriting || _logQueue.isEmpty) {
      return;
    }

    _isWriting = true;
    while (_logQueue.isNotEmpty) {
      final message = _logQueue.removeAt(0);
      try {
        await _logFile!.writeAsString(
          '$message\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (e) {
        // Fallback to debugPrint if file writing fails
        debugPrint('Error writing to log file: $e - Message: $message');
      }
    }
    _isWriting = false;
  }

  static Future<String> readLogs() async {
    if (_logFile == null) {
      return 'Log file not initialized.';
    }
    if (!await _logFile!.exists()) {
      return 'Log file does not exist.';
    }
    return _logFile!.readAsString();
  }

  static Future<void> clearLogs() async {
    if (_logFile == null) {
      return;
    }
    if (await _logFile!.exists()) {
      await _logFile!.writeAsString(
        '=== LOGS CLEARED ${DateTime.now().toIso8601String()} ===\n',
      );
    }
  }

  static Future<File?> getLogFile() async {
    if (_logFile == null) {
      await init();
    }
    return _logFile;
  }
}
