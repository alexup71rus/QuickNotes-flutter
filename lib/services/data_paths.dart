import 'dart:io';
import 'package:path/path.dart' as p;

class DataPaths {
  static Directory? _baseDirectory;

  static Future<Directory> get baseDirectory async {
    if (_baseDirectory != null) return _baseDirectory!;

    // 1. Calculate new path (Portable)
    final exePath = Platform.resolvedExecutable;
    var dir = File(exePath).parent;

    // If inside a macOS bundle, go up to the folder containing the .app
    // Structure: AppName.app/Contents/MacOS/Executable
    if (Platform.isMacOS && dir.path.endsWith(p.join('Contents', 'MacOS'))) {
      dir = dir.parent.parent.parent;
    }

    final newBaseDir = Directory(p.join(dir.path, 'QuickNotesData'));

    // 2. Calculate old path (Legacy)
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;

    // Check multiple possible locations for old data
    // Location A: Deeply nested path (created by previous version running in sandbox)
    final oldNestedDir = Directory(
      p.join(
        homeDir,
        'Library',
        'Containers',
        'com.example.quickNotes',
        'Data',
        'Library',
        'Containers',
        'com.example.quickNotes',
        'Data',
        'QuickNotesData',
      ),
    );

    // Location B: Standard container path
    final oldStandardDir = Directory(
      p.join(
        homeDir,
        'Library',
        'Containers',
        'com.example.quickNotes',
        'Data',
        'QuickNotesData',
      ),
    );

    Directory? migrationSource;
    if (await oldNestedDir.exists()) {
      migrationSource = oldNestedDir;
    } else if (await oldStandardDir.exists()) {
      migrationSource = oldStandardDir;
    }

    // 3. Migration logic
    if (!await newBaseDir.exists() && migrationSource != null) {
      try {
        await _copyDirectory(migrationSource, newBaseDir);
      } catch (e) {
        // Error migrating data
      }
    }

    if (!await newBaseDir.exists()) {
      await newBaseDir.create(recursive: true);
    }

    _baseDirectory = newBaseDir;
    return newBaseDir;
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
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
