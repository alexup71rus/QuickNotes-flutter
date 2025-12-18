import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'data_paths.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  bool _useDebounce = true;
  double _fontSize = 14.0;
  Color _backgroundColor = const Color(0xFFFEF9E7);
  bool _autoTitleFromFirstSentence = false;
  bool _sortByModified = false;
  bool _launchAtLogin = false;

  bool get useDebounce => _useDebounce;
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  bool get autoTitleFromFirstSentence => _autoTitleFromFirstSentence;
  bool get sortByModified => _sortByModified;
  bool get launchAtLogin => _launchAtLogin;

  set useDebounce(bool value) {
    _useDebounce = value;
    _save();
    notifyListeners();
  }

  set fontSize(double value) {
    _fontSize = value.clamp(10.0, 28.0);
    _save();
    notifyListeners();
  }

  set backgroundColor(Color value) {
    _backgroundColor = value;
    _save();
    notifyListeners();
  }

  set autoTitleFromFirstSentence(bool value) {
    _autoTitleFromFirstSentence = value;
    _save();
    notifyListeners();
  }

  set sortByModified(bool value) {
    _sortByModified = value;
    _save();
    notifyListeners();
  }

  set launchAtLogin(bool value) {
    _launchAtLogin = value;
    _save();
    notifyListeners();
  }

  void updateFromMap(Map<String, dynamic> map) {
    if (map.containsKey('fontSize'))
      _fontSize = (map['fontSize'] as num).toDouble();
    if (map.containsKey('backgroundColor'))
      _backgroundColor = Color(map['backgroundColor'] as int);
    if (map.containsKey('sortByModified'))
      _sortByModified = map['sortByModified'] as bool;
    if (map.containsKey('launchAtLogin'))
      _launchAtLogin = map['launchAtLogin'] as bool;
    if (map.containsKey('useDebounce'))
      _useDebounce = map['useDebounce'] as bool;
    if (map.containsKey('autoTitleFromFirstSentence'))
      _autoTitleFromFirstSentence = map['autoTitleFromFirstSentence'] as bool;

    // Save to disk as well, to ensure persistence if updated from another window
    _save();
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final file = await DataPaths.settingsFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;

        _useDebounce = map['useDebounce'] ?? true;
        _fontSize = (map['fontSize'] as num?)?.toDouble() ?? 14.0;
        _autoTitleFromFirstSentence =
            map['autoTitleFromFirstSentence'] ?? false;
        _sortByModified = map['sortByModified'] ?? false;
        _launchAtLogin = map['launchAtLogin'] ?? false;

        if (map.containsKey('backgroundColor')) {
          _backgroundColor = Color(map['backgroundColor'] as int);
        }

        notifyListeners();
      }
    } catch (e) {
      // Error loading settings
    }
  }

  Future<void> _save() async {
    try {
      final file = await DataPaths.settingsFile;
      final map = {
        'useDebounce': _useDebounce,
        'fontSize': _fontSize,
        'backgroundColor': _backgroundColor.value,
        'autoTitleFromFirstSentence': _autoTitleFromFirstSentence,
        'sortByModified': _sortByModified,
        'launchAtLogin': _launchAtLogin,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      // Error saving settings
    }
  }
}
