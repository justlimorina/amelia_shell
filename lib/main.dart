import 'package:flutter/material.dart';
import 'core/services/layer_shell_service.dart';
import 'core/services/system_service.dart';
import 'core/theme/theme.dart';
import 'features/launcher/launcher_panel.dart';
import 'features/quick_settings/quick_settings_panel.dart';
import 'features/shelf/shelf_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start system services (clock, battery)
  SystemService().start();

  // Check if running under Wayland Layer Shell
  await LayerShellService.checkLayerSupport();
  await LayerShellService.setExclusiveZone(56);

  runApp(const AmeliaShellApp());
}

class AmeliaShellApp extends StatelessWidget {
  const AmeliaShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amelia Shell',
      debugShowCheckedModeBanner: false,
      theme: AmeliaTheme.darkTheme(),
      home: const ShellScreen(),
    );
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  bool _isLauncherOpen = false;
  bool _isQuickSettingsOpen = false;

  void _closeAllOverlays() {
    if (_isLauncherOpen || _isQuickSettingsOpen) {
      setState(() {
        _isLauncherOpen = false;
        _isQuickSettingsOpen = false;
      });
      // Shrink layer surface back to shelf height
      LayerShellService.setHeight(56);
      LayerShellService.setKeyboardMode(false);
    }
  }

  void _toggleLauncher() {
    setState(() {
      _isLauncherOpen = !_isLauncherOpen;
      _isQuickSettingsOpen = false;
    });

    if (_isLauncherOpen) {
      // Expand window height to accommodate Launcher panel
      LayerShellService.setHeight(600);
    } else {
      LayerShellService.setHeight(56);
      LayerShellService.setKeyboardMode(false);
    }
  }

  void _toggleQuickSettings() {
    setState(() {
      _isQuickSettingsOpen = !_isQuickSettingsOpen;
      _isLauncherOpen = false;
    });

    if (_isQuickSettingsOpen) {
      // Expand window height to accommodate Quick Settings panel
      LayerShellService.setHeight(600);
      LayerShellService.setKeyboardMode(false);
    } else {
      LayerShellService.setHeight(56);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay = _isLauncherOpen || _isQuickSettingsOpen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Transparent Backdrop to catch outside clicks and close popups
          if (hasOverlay)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeAllOverlays,
                child: Container(color: Colors.transparent),
              ),
            ),

          // 2. Launcher Popup (Anchored at Bottom-Left above Shelf)
          if (_isLauncherOpen)
            Positioned(
              left: 12,
              bottom: AmeliaTheme.shelfHeight + 8,
              child: LauncherPanel(
                onClose: _closeAllOverlays,
              ),
            ),

          // 3. Quick Settings Popup (Anchored at Bottom-Right above Shelf)
          if (_isQuickSettingsOpen)
            Positioned(
              right: 12,
              bottom: AmeliaTheme.shelfHeight + 8,
              child: QuickSettingsPanel(
                onClose: _closeAllOverlays,
              ),
            ),

          // 4. Main Shelf (Anchored at Bottom Edge)
          Align(
            alignment: Alignment.bottomCenter,
            child: ShelfWidget(
              isLauncherOpen: _isLauncherOpen,
              isQuickSettingsOpen: _isQuickSettingsOpen,
              onToggleLauncher: _toggleLauncher,
              onToggleQuickSettings: _toggleQuickSettings,
            ),
          ),
        ],
      ),
    );
  }
}
