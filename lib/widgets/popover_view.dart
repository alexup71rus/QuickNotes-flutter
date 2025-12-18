import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/storage.dart';
import '../services/settings.dart';

class PopoverView extends StatefulWidget {
  const PopoverView({super.key});

  @override
  State<PopoverView> createState() => _PopoverViewState();
}

class _PopoverViewState extends State<PopoverView> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final AppSettings _settings = AppSettings();

  List<Note> _notes = [];
  Note? _currentNote;
  Timer? _saveTimer;
  bool _manualTitleEdited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadNotes();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushSave();
    _textController.dispose();
    _titleController.dispose();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      // Reload notes when sort order changes
      _reloadNotes(selectNote: _currentNote);
      // Force rebuild to apply fontSize and backgroundColor changes
      setState(() {});
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    final notes = await Storage.listNotes();

    if (notes.isEmpty) {
      final newNote = await Storage.createNew('');
      if (newNote != null) {
        setState(() {
          _notes = [newNote];
          _currentNote = newNote;
          _textController.text = newNote.content;
          _titleController.text = '';
          _manualTitleEdited = false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      final firstNote = notes.first;
      final isDate = _isDateTitle(firstNote.baseName);
      setState(() {
        _notes = notes;
        _currentNote = firstNote;
        _textController.text = firstNote.content;
        _titleController.text = isDate ? '' : firstNote.baseName;
        _manualTitleEdited = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadNotes({Note? selectNote}) async {
    final notes = await Storage.listNotes();

    if (notes.isEmpty) {
      setState(() {
        _notes = [];
        _currentNote = null;
        _textController.text = '';
        _titleController.text = '';
        _manualTitleEdited = false;
      });
      return;
    }

    Note? noteToSelect = selectNote;
    if (noteToSelect == null && notes.isNotEmpty) {
      noteToSelect = notes.first;
    }

    if (noteToSelect != null) {
      final matchedNote = notes.firstWhere(
        (n) => n.file.path == noteToSelect!.file.path,
        orElse: () => notes.first,
      );

      final isDate = _isDateTitle(matchedNote.baseName);
      setState(() {
        _notes = notes;
        _currentNote = matchedNote;
        _textController.text = matchedNote.content;
        _titleController.text = isDate ? '' : matchedNote.baseName;
        _manualTitleEdited = false;
      });
    }
  }

  Future<void> _onNoteSelected(Note? note) async {
    if (note == null || note == _currentNote) return;

    await _saveNowIfNeeded();

    final isDate = _isDateTitle(note.baseName);
    setState(() {
      _currentNote = note;
      _textController.text = note.content;
      _titleController.text = isDate ? '' : note.baseName;
      _manualTitleEdited = false;
    });
  }

  Future<void> _createNewNote() async {
    // Save current note before creating new one
    await _saveNowIfNeeded();

    final newNote = await Storage.createNew('');
    if (newNote != null) {
      await _reloadNotes(selectNote: newNote);
    }
  }

  Future<void> _deleteCurrentNote() async {
    if (_currentNote == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && _currentNote != null) {
      await Storage.delete(_currentNote!.file);
      _manualTitleEdited = false;

      // Reload and check if we need to create a new note
      final notes = await Storage.listNotes();
      if (notes.isEmpty) {
        final newNote = await Storage.createNew('');
        if (newNote != null) {
          await _reloadNotes(selectNote: newNote);
        }
      } else {
        await _reloadNotes();
      }
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    if (_settings.useDebounce) {
      _saveTimer = Timer(const Duration(milliseconds: 800), () => _flushSave());
    } else {
      _saveNowIfNeeded();
    }
  }

  Future<void> _saveNowIfNeeded() async {
    _saveTimer?.cancel();
    await _flushSave();
  }

  Future<void> _flushSave() async {
    _saveTimer?.cancel();

    final text = _textController.text;
    final textTrimmed = text.trim();
    final titleTrimmed = _titleController.text.trim();

    if (textTrimmed.isEmpty && titleTrimmed.isEmpty) {
      return;
    }

    final baseName = _desiredBaseName(text);

    if (_currentNote != null) {
      final currentBase = _currentNote!.baseName;
      var targetFile = _currentNote!.file;

      if (baseName != null && baseName != currentBase) {
        final oldFilePath = targetFile.path;
        final renamedFile = await Storage.rename(targetFile, baseName);
        if (renamedFile != null) {
          targetFile = renamedFile;
          final renamedNote = Note(
            file: renamedFile,
            fileName: renamedFile.path.split('/').last,
            createdAt: _currentNote!.createdAt,
            modifiedAt: DateTime.now(),
            content: text,
          );

          setState(() {
            _currentNote = renamedNote;
            final index = _notes.indexWhere((n) => n.file.path == oldFilePath);
            if (index != -1) {
              _notes[index] = renamedNote;
            }

            _titleController.text = _currentNote!.baseName;
            _manualTitleEdited =
                _manualTitleEdited && _titleController.text.isNotEmpty;
          });
        }
      }

      if (_currentNote!.content == text && baseName == currentBase) {
        return;
      }

      await Storage.overwrite(targetFile, text);

      if (mounted) {
        final updatedNote = Note(
          file: targetFile,
          fileName: targetFile.path.split('/').last,
          createdAt: _currentNote!.createdAt,
          modifiedAt: DateTime.now(),
          content: text,
        );

        setState(() {
          _currentNote = updatedNote;
          final index = _notes.indexWhere(
            (n) => n.file.path == targetFile.path,
          );
          if (index != -1) {
            _notes[index] = updatedNote;
          }
        });

        if (_settings.sortByModified) {
          await _reloadNotes(selectNote: updatedNote);
        }
      }
    } else {
      final newNote = await Storage.createNew(
        text,
        preferredBaseName: baseName,
      );
      if (newNote != null) {
        await _reloadNotes(selectNote: newNote);
      }
    }
  }

  String? _desiredBaseName(String body) {
    final manualTitle = _titleController.text.trim();
    if (manualTitle.isNotEmpty) {
      return _sanitizeTitle(manualTitle);
    }

    if (_settings.autoTitleFromFirstSentence) {
      final first = _firstSentence(body);
      if (first != null) {
        final sanitized = _sanitizeTitle(first);
        if (sanitized != null) {
          return sanitized;
        }
      }
    }

    return null;
  }

  String? _firstSentence(String body) {
    final separators = ['.', '!', '?', '\n'];
    int firstIndex = body.length;

    // Find the earliest separator
    for (final sep in separators) {
      final index = body.indexOf(sep);
      if (index != -1 && index < firstIndex) {
        firstIndex = index;
      }
    }

    if (firstIndex < body.length) {
      final first = body.substring(0, firstIndex).trim();
      if (first.isNotEmpty) {
        return first;
      }
    }

    // No separator found, return whole body if not empty
    final trimmed = body.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }

  String? _sanitizeTitle(String raw) {
    final invalid = RegExp(r'[/\\?%*|"<>]');
    final cleaned = raw.replaceAll(invalid, '');
    final trimmed = cleaned.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.substring(0, trimmed.length > 80 ? 80 : trimmed.length);
  }

  bool _isDateTitle(String title) {
    try {
      DateFormat('dd-MM-yyyy HH:mm:ss.SSS').parse(title);
      return true;
    } catch (e) {
      return false;
    }
  }

  Color _getContrastingColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final iconColor = _getContrastingColor(_settings.backgroundColor);
    final gridColor = iconColor.withOpacity(0.1);

    return Scaffold(
      backgroundColor: _settings.backgroundColor,
      body: Column(
        children: [
          // Top bar with dropdown and plus button
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Note>(
                        value: _currentNote,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        items: _notes.map((note) {
                          return DropdownMenuItem(
                            value: note,
                            child: Text(
                              note.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _onNoteSelected,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    onPressed: _createNewNote,
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.add, color: iconColor),
                  ),
                ),
              ],
            ),
          ),

          // Title field with delete button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: _currentNote?.baseName ?? 'New Note',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (text) {
                      _manualTitleEdited = text.trim().isNotEmpty;
                      _scheduleSave();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    onPressed: _deleteCurrentNote,
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.delete, color: iconColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Text editor
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: GridPainter(color: gridColor)),
                  ),
                  TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    style: TextStyle(fontSize: _settings.fontSize),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Your note...',
                      contentPadding: EdgeInsets.all(8),
                    ),
                    onChanged: (text) => _scheduleSave(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 24.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      color != oldDelegate.color;
}
