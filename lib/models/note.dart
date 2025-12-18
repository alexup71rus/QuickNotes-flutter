import 'dart:io';

class Note {
  final File file;
  final String fileName;
  final DateTime createdAt;
  final DateTime modifiedAt;
  String content;

  Note({
    required this.file,
    required this.fileName,
    required this.createdAt,
    required this.modifiedAt,
    required this.content,
  });

  String get displayName {
    return fileName.replaceAll('.txt', '');
  }

  String get baseName {
    return fileName.replaceAll('.txt', '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          file.path == other.file.path;

  @override
  int get hashCode => file.path.hashCode;
}
