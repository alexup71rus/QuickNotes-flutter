import 'dart:io';
import 'package:path/path.dart' as p;
import 'data_paths.dart';

class Logger {
  static Future<void> error(String message) async {
    await _write('ERROR', message);
  }

  static Future<void> info(String message) async {
    await _write('INFO', message);
  }

  static Future<void> _write(String level, String message) async {
    try {
      final logsDir = await DataPaths.logsDirectory;
      final logFile = File(p.join(logsDir.path, 'quicknotes.log'));

      final timestamp = DateTime.now().toIso8601String();
      final line = '[$timestamp] $level: $message\n';

      if (await logFile.exists()) {
        await logFile.writeAsString(line, mode: FileMode.append);
      } else {
        await logFile.writeAsString(line);
      }
    } catch (e) {
      // Silently fail if logging fails
    }
  }
}
