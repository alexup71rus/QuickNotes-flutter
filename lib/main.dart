import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'services/settings.dart';
import 'services/data_paths.dart';
import 'widgets/popover_view.dart';
import 'widgets/settings_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if this is a subwindow
  if (args.isNotEmpty && args.first == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2];
    final data = jsonDecode(argument) as Map<String, dynamic>;

    // Handle settings window
    if (data['name'] == 'settings') {
      runSettingsWindow(windowId);
      return;
    }
  }

  // Main window setup
  LaunchAtStartup.instance.setup(
    appName: 'Quick Notes',
    appPath: Platform.resolvedExecutable,
  );

  // Load settings first
  await AppSettings().load();

  runApp(const MyApp());
}

// Settings window entry point
void runSettingsWindow(int windowId) async {
  final controller = WindowController.fromWindowId(windowId);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: SettingsWindowWrapper(controller: controller),
    ),
  );
}

// Wrapper for settings window to handle close
class SettingsWindowWrapper extends StatefulWidget {
  final WindowController controller;

  const SettingsWindowWrapper({super.key, required this.controller});

  @override
  State<SettingsWindowWrapper> createState() => _SettingsWindowWrapperState();
}

class _SettingsWindowWrapperState extends State<SettingsWindowWrapper> {
  @override
  void initState() {
    super.initState();
    // Notify main window when this window is disposed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Send message to main window that settings opened
      DesktopMultiWindow.invokeMethod(0, 'settings_opened');
    });
  }

  @override
  void dispose() {
    // Notify main window that settings closed
    DesktopMultiWindow.invokeMethod(0, 'settings_closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await widget.controller.close();
        return false;
      },
      child: const SettingsWindow(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with TrayListener, WidgetsBindingObserver {
  int? _settingsWindowId;
  bool _isMainWindowVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trayManager.addListener(this);

    _setupMessageHandler();
    _init();
  }

  Future<void> _init() async {
    await _initMainWindow();
    await _initTray();
    await _updateContextMenu();
  }

  void _setupMessageHandler() {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'settings_closed') {
        setState(() {
          _settingsWindowId = null;
        });
      } else if (call.method == 'settings_opened') {
        // Settings window opened
      } else if (call.method == 'settings_changed') {
        try {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          AppSettings().updateFromMap(args);
        } catch (e) {
          // Error updating settings
        }
      }
    });

    const MethodChannel('quick_notes/window').setMethodCallHandler((
      call,
    ) async {
      if (call.method == 'window_hidden') {
        setState(() {
          _isMainWindowVisible = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't auto-hide here - let Swift handle window blur
    // This prevents immediate hiding after showing
  }

  Future<void> _initMainWindow() async {
    final mainWindow = WindowController.fromWindowId(0);
    await mainWindow.hide();
    _isMainWindowVisible = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<String> _extractAsset(String assetPath) async {
    final tempDir = await getTemporaryDirectory();
    // Add timestamp to force fresh extraction
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_${assetPath.split('/').last}';
    final file = File('${tempDir.path}/$fileName');

    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    // Try to extract @2x version if it exists (for Retina displays)
    try {
      final nameWithoutExt = p.basenameWithoutExtension(
        assetPath.split('/').last,
      );
      final ext = p.extension(assetPath);
      // Look for the @2x asset in the bundle
      final retinaAssetPath = assetPath.replaceFirst(
        nameWithoutExt,
        '$nameWithoutExt@2x',
      );

      // Target file name should also have the timestamp
      final retinaFileName = '${timestamp}_$nameWithoutExt@2x$ext';
      final retinaFile = File('${tempDir.path}/$retinaFileName');

      try {
        final retinaByteData = await rootBundle.load(retinaAssetPath);
        await retinaFile.writeAsBytes(retinaByteData.buffer.asUint8List());
      } catch (e) {
        if (assetPath.contains('icon.png')) {
          await file.copy(retinaFile.path);
        }
      }
    } catch (e) {
      // Error handling retina icon
    }

    return file.path;
  }

  Future<void> _initTray() async {
    // Use the cropped version to remove padding and make icon look larger
    String iconPath = 'assets/images/tray_icon_cropped.png';

    // Check for custom icon first
    final customIcon = await DataPaths.trayIconFile;
    if (customIcon != null) {
      iconPath = customIcon.path;
    } else if (Platform.isMacOS) {
      try {
        iconPath = await _extractAsset(iconPath);
      } catch (e) {
        // Failed to extract icon
      }
    }

    try {
      await trayManager.setIcon(iconPath, isTemplate: Platform.isMacOS);
    } catch (e) {
      // Failed to load tray icon
    }

    await trayManager.setToolTip('Quick Notes');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PopoverView(),
    );
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    final mainWindow = WindowController.fromWindowId(0);

    if (_isMainWindowVisible) {
      await mainWindow.hide();
      setState(() {
        _isMainWindowVisible = false;
      });
    } else {
      final bounds = await trayManager.getBounds();
      if (bounds != null) {
        final display = await screenRetriever.getPrimaryDisplay();
        final screenHeight = display.size.height;

        final windowWidth = 440.0;
        final windowHeight = 440.0;
        final iconWidth = bounds.width;
        final x = bounds.left + (iconWidth / 2) - (windowWidth / 2);

        final y = screenHeight - bounds.bottom - windowHeight;

        await mainWindow.setFrame(
          Offset(x, y) & Size(windowWidth, windowHeight),
        );
      }
      await mainWindow.show();
      setState(() {
        _isMainWindowVisible = true;
      });
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'quit_app') {
      exit(0);
    }
    if (menuItem.key == 'open_settings') {
      await _openSettingsWindow();
    }
  }

  Future<void> _openSettingsWindow() async {
    if (_settingsWindowId != null) {
      final allWindows = await DesktopMultiWindow.getAllSubWindowIds();
      if (allWindows.contains(_settingsWindowId)) {
        return;
      } else {
        _settingsWindowId = null;
      }
    }

    try {
      final window = await DesktopMultiWindow.createWindow(
        jsonEncode({'name': 'settings'}),
      );

      setState(() {
        _settingsWindowId = window.windowId;
      });

      window
        ..setFrame(const Offset(100, 100) & const Size(440, 480))
        ..center()
        ..setTitle('QuickNotes')
        ..resizable(false)
        ..show();

      _checkSettingsWindowAlive();
    } catch (e) {
      setState(() {
        _settingsWindowId = null;
      });
    }
  }

  Future<void> _checkSettingsWindowAlive() async {
    await Future.delayed(const Duration(seconds: 1));
    if (_settingsWindowId != null) {
      final allWindows = await DesktopMultiWindow.getAllSubWindowIds();
      if (!allWindows.contains(_settingsWindowId)) {
        setState(() {
          _settingsWindowId = null;
        });
      } else {
        _checkSettingsWindowAlive();
      }
    }
  }

  Future<void> _updateContextMenu() async {
    List<MenuItem> items = [
      MenuItem(key: 'open_settings', label: 'Settings'),
      MenuItem.separator(),
      MenuItem(key: 'quit_app', label: 'Close'),
    ];
    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }
}
