import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';
import 'data_paths.dart';
import 'logger.dart';
import 'settings.dart';

class Storage {
  static Future<List<Note>> listNotes({bool? sortByModified}) async {
    try {
      final notesDir = await DataPaths.notesDirectory;
      final sortByMod = sortByModified ?? AppSettings().sortByModified;

      final entities = await notesDir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.txt')
          .toList();

      final notes = <Note>[];
      for (final file in files) {
        final stat = await file.stat();
        final content = await file.readAsString();
        final fileName = p.basename(file.path);

        DateTime creationDate;
        try {
          final nameWithoutExt = p.basenameWithoutExtension(fileName);
          final format = DateFormat('dd-MM-yyyy HH:mm:ss.SSS');
          creationDate = format.parse(nameWithoutExt);
        } catch (e) {
          creationDate = stat.changed;
        }

        notes.add(
          Note(
            file: file,
            fileName: fileName,
            createdAt: creationDate,
            modifiedAt: stat.modified,
            content: content,
          ),
        );
      }

      if (sortByMod) {
        notes.sort((a, b) {
          final comparison = b.modifiedAt.compareTo(a.modifiedAt);
          if (comparison == 0) {
            return b.fileName.compareTo(a.fileName);
          }
          return comparison;
        });
      } else {
        notes.sort((a, b) {
          final comparison = b.createdAt.compareTo(a.createdAt);
          if (comparison == 0) {
            return b.fileName.compareTo(a.fileName);
          }
          return comparison;
        });
      }

      return notes;
    } catch (e) {
      await Logger.error('Failed to list notes: $e');
      return [];
    }
  }

  static Future<String?> read(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      await Logger.error('Failed to read note: $e');
      return null;
    }
  }

  static Future<Note?> createNew(
    String content, {
    String? preferredBaseName,
  }) async {
    try {
      final notesDir = await DataPaths.notesDirectory;
      final baseName = preferredBaseName ?? _dateTimeString();
      final fileName = await _uniqueFileName(baseName);
      final file = File(p.join(notesDir.path, fileName));

      await file.writeAsString(content);
      final stat = await file.stat();

      return Note(
        file: file,
        fileName: fileName,
        createdAt: stat.changed,
        modifiedAt: stat.modified,
        content: content,
      );
    } catch (e) {
      await Logger.error('Failed to create note: $e');
      return null;
    }
  }

  static Future<void> overwrite(File file, String content) async {
    try {
      await file.writeAsString(content);
    } catch (e) {
      await Logger.error('Failed to overwrite note: $e');
    }
  }

  static Future<File?> rename(File file, String newBaseName) async {
    try {
      final notesDir = await DataPaths.notesDirectory;
      final newFileName = await _uniqueFileName(newBaseName);
      final newFile = File(p.join(notesDir.path, newFileName));

      await file.rename(newFile.path);
      return newFile;
    } catch (e) {
      await Logger.error('Failed to rename note: $e');
      return null;
    }
  }

  static String _dateTimeString() {
    return DateFormat('dd-MM-yyyy HH:mm:ss.SSS').format(DateTime.now());
  }

  static String? _sanitize(String base) {
    final invalid = RegExp(r'[/\\?%*|"<>]');
    final cleaned = base.replaceAll(invalid, '');
    final trimmed = cleaned.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.substring(0, trimmed.length > 80 ? 80 : trimmed.length);
  }

  static Future<String> _uniqueFileName(String baseName) async {
    final notesDir = await DataPaths.notesDirectory;
    final safeBase = _sanitize(baseName) ?? _dateTimeString();
    var candidate = '$safeBase.txt';
    var counter = 1;

    while (await File(p.join(notesDir.path, candidate)).exists()) {
      candidate = '$safeBase-$counter.txt';
      counter++;
    }

    return candidate;
  }

  static Future<void> delete(File file) async {
    try {
      await file.delete();
    } catch (e) {
      await Logger.error('Failed to delete note: $e');
    }
  }
}
