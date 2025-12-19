import 'dart:io';
import 'package:path/path.dart' as p;

class DataPaths {
  static Directory? _baseDirectory;
  static Future<Directory>? _initFuture;

  static Future<Directory> get baseDirectory async {
    if (_baseDirectory != null) return _baseDirectory!;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _initialize();
    return _initFuture!;
  }

  static Future<Directory> _initialize() async {
    // 1. Calculate new path (Portable)
    final exePath = Platform.resolvedExecutable;
    var dir = File(exePath).parent;

    // If inside a macOS bundle, go up to the folder containing the .app
    if (Platform.isMacOS && dir.path.endsWith(p.join('Contents', 'MacOS'))) {
      dir = dir.parent.parent.parent;
    }

    final newBaseDir = Directory(p.join(dir.path, 'QuickNotesData'));

    if (!await newBaseDir.exists()) {
      await newBaseDir.create(recursive: true);
    }

    _baseDirectory = newBaseDir;
    return newBaseDir;
  }

  static Future<Directory> get notesDirectory async {
    final base = await baseDirectory;
    final dir = Directory(p.join(base.path, 'QuickNotesContent'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> get settingsFile async {
    final base = await baseDirectory;
    final dir = Directory(p.join(base.path, 'Settings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'settings.json'));
  }

  static Future<Directory> get logsDirectory async {
    final base = await baseDirectory;
    final dir = Directory(p.join(base.path, 'Logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File?> get trayIconFile async {
    final base = await baseDirectory;
    final assetsDir = Directory(p.join(base.path, 'Assets'));

    if (await assetsDir.exists()) {
      final trayIcon = File(p.join(assetsDir.path, 'tray-icon.png'));
      if (await trayIcon.exists()) return trayIcon;

      final icon = File(p.join(assetsDir.path, 'icon.png'));
      if (await icon.exists()) return icon;
    }

    return null;
  }
}
