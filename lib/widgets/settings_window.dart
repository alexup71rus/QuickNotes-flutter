import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../services/settings.dart';

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final AppSettings _settings = AppSettings();
  late TextEditingController _fontSizeController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fontSizeController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.load();
    if (mounted) {
      setState(() {
        _fontSizeController.text = _settings.fontSize.toString();
        _isLoading = false;
      });
      _settings.addListener(_onSettingsChanged);
    }
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _fontSizeController.text = _settings.fontSize.toString();
      });

      // Send update to main window
      DesktopMultiWindow.invokeMethod(0, 'settings_changed', {
        'fontSize': _settings.fontSize,
        'backgroundColor': _settings.backgroundColor.value,
        'sortByModified': _settings.sortByModified,
        'launchAtLogin': _settings.launchAtLogin,
        'useDebounce': _settings.useDebounce,
        'autoTitleFromFirstSentence': _settings.autoTitleFromFirstSentence,
      });
    }
  }

  Future<void> _toggleLaunchAtLogin(bool? value) async {
    if (value == null) return;

    _settings.launchAtLogin = value;

    if (value) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
  }

  Future<void> _pickColor() async {
    final newColor = await showColorPickerDialog(
      context,
      _settings.backgroundColor,
      title: const Text('Select background color'),
      width: 40,
      height: 40,
      spacing: 4,
      runSpacing: 4,
      borderRadius: 8,
      enableOpacity: false,
      showColorCode: false,
      showMaterialName: false,
      showColorName: false,
      pickersEnabled: const {
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.wheel: false,
        ColorPickerType.custom: false,
        ColorPickerType.bw: false,
      },
    );

    setState(() {
      _settings.backgroundColor = newColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: const Text('Launch at login'),
              value: _settings.launchAtLogin,
              onChanged: _toggleLaunchAtLogin,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const Divider(height: 32),

            CheckboxListTile(
              title: const Text('Use debounce save (0.8s)'),
              value: _settings.useDebounce,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings.useDebounce = value;
                  });
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            CheckboxListTile(
              title: const Text('Auto-title from first sentence'),
              value: _settings.autoTitleFromFirstSentence,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings.autoTitleFromFirstSentence = value;
                  });
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            CheckboxListTile(
              title: const Text('Sort notes by modified date'),
              value: _settings.sortByModified,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings.sortByModified = value;
                  });
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const SizedBox(width: 16),
                const Text('Font size:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 20),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _fontSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (value) {
                      final newSize = double.tryParse(value);
                      if (newSize != null) {
                        setState(() {
                          _settings.fontSize = newSize;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const SizedBox(width: 16),
                const Text('Background color:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _settings.backgroundColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
