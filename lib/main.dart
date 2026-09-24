import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'core/services/input_method_service.dart';
import 'core/services/ipc_service.dart';
import 'core/services/layer_shell_service.dart';
import 'core/services/mpris_service.dart';
import 'core/services/osd_service.dart';
import 'core/services/screen_capture_service.dart';
import 'core/services/system_service.dart';
import 'core/theme/theme.dart';
import 'features/calendar/calendar_panel.dart';
import 'features/launcher/launcher_panel.dart';
import 'features/osd/osd_overlay.dart';
import 'features/quick_settings/quick_settings_panel.dart';
import 'features/screen_capture/capture_toolbar.dart';
import 'features/shelf/shelf_widget.dart';
import 'features/status_tray/input_method_panel.dart';

void main(List<String> args) async {
  if (args.isNotEmpty && (args[0] == '--help' || args[0] == '-h')) {
    stdout.writeln('''Amelia Shell - ChromeOS Material 3 Desktop Shell for Wayland

Usage:
  amelia_shell                  Start the shell GUI
  amelia_shell msg <command>    Send IPC command to running instance

Available IPC commands:
  toggle-launcher         Toggle application launcher
  open-launcher           Open application launcher
  close-launcher          Close application launcher
  toggle-quick-settings   Toggle Quick Settings / Control Center
  toggle-calendar         Toggle Calendar & Notifications
  toggle-ime              Toggle Input Method menu
  capture                 Open Screen Capture toolbar
  capture-screen          Capture entire screen immediately
  capture-selection       Capture region selection immediately
  capture-window          Capture window immediately
  close-all               Dismiss all open popups
  volume-up               Increase volume +5%
  volume-down             Decrease volume -5%
  volume-mute             Toggle audio mute
  volume-osd              Show volume OSD
  brightness-up           Increase brightness +5%
  brightness-down         Decrease brightness -5%
  brightness-osd          Show brightness OSD
  ping                    Check if shell is running''');
    exit(0);
  }

  if (args.isNotEmpty && args[0] == 'msg') {
    final code = await IpcService.sendCommand(args.skip(1).toList());
    exit(code);
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Start system services (clock, battery, MPRIS media, IME, IPC, OSD)
  SystemService().start();
  MprisService().start();
  InputMethodService().start();
  OsdService().start();
  await IpcService().start();

  // Check if running under Wayland Layer Shell
  await LayerShellService.checkLayerSupport();
  await LayerShellService.setExclusiveZone(56);

  runApp(const AmeliaShellApp());
}

class AmeliaShellApp extends StatelessWidget {
  const AmeliaShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Amelia Shell',
          debugShowCheckedModeBanner: false,
          theme: AmeliaTheme.lightTheme(),
          darkTheme: AmeliaTheme.darkTheme(),
          themeMode: currentThemeMode,
          home: const ShellScreen(),
        );
      },
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
  bool _isCalendarOpen = false;
  bool _isQuickSettingsOpen = false;
  bool _isImeMenuOpen = false;
  bool _isCaptureToolbarOpen = false;

  StreamSubscription<IpcAction>? _ipcSub;

  @override
  void initState() {
    super.initState();
    _ipcSub = IpcService().actionStream.listen(_handleIpcAction);
    OsdService().currentOsd.addListener(_onOsdChanged);
  }

  @override
  void dispose() {
    _ipcSub?.cancel();
    OsdService().currentOsd.removeListener(_onOsdChanged);
    super.dispose();
  }

  bool get _hasAnyOverlayOpen =>
      _isLauncherOpen ||
      _isCalendarOpen ||
      _isQuickSettingsOpen ||
      _isImeMenuOpen ||
      _isCaptureToolbarOpen;

  void _onOsdChanged() {
    final osd = OsdService().currentOsd.value;
    if (mounted) {
      setState(() {});
    }
    if (osd != null) {
      if (!_hasAnyOverlayOpen) {
        LayerShellService.setHeight(140);
      }
    } else {
      if (!_hasAnyOverlayOpen) {
        LayerShellService.setHeight(56);
      }
    }
  }

  void _handleIpcAction(IpcAction action) {
    switch (action) {
      case IpcAction.toggleLauncher:
        _toggleLauncher();
      case IpcAction.openLauncher:
        if (!_isLauncherOpen) _toggleLauncher();
      case IpcAction.closeLauncher:
        if (_isLauncherOpen) _toggleLauncher();

      case IpcAction.toggleQuickSettings:
        _toggleQuickSettings();
      case IpcAction.openQuickSettings:
        if (!_isQuickSettingsOpen) _toggleQuickSettings();
      case IpcAction.closeQuickSettings:
        if (_isQuickSettingsOpen) _toggleQuickSettings();

      case IpcAction.toggleCalendar:
        _toggleCalendar();
      case IpcAction.openCalendar:
        if (!_isCalendarOpen) _toggleCalendar();
      case IpcAction.closeCalendar:
        if (_isCalendarOpen) _toggleCalendar();

      case IpcAction.toggleIme:
        _toggleImeMenu();
      case IpcAction.openIme:
        if (!_isImeMenuOpen) _toggleImeMenu();
      case IpcAction.closeIme:
        if (_isImeMenuOpen) _toggleImeMenu();

      case IpcAction.openCapture:
        _openCaptureToolbar();
      case IpcAction.captureFull:
        _closeAllOverlays();
        ScreenCaptureService().captureFull();
      case IpcAction.captureSelection:
        _closeAllOverlays();
        ScreenCaptureService().captureRegion();
      case IpcAction.captureWindow:
        _closeAllOverlays();
        ScreenCaptureService().captureFocusedWindow();

      case IpcAction.closeAll:
        _closeAllOverlays();

      case IpcAction.volumeUp:
        OsdService().adjustVolume(0.05);
      case IpcAction.volumeDown:
        OsdService().adjustVolume(-0.05);
      case IpcAction.volumeMute:
        OsdService().toggleMute();
      case IpcAction.volumeOsd:
        OsdService().showVolumeOsd();

      case IpcAction.brightnessUp:
        OsdService().adjustBrightness(0.05);
      case IpcAction.brightnessDown:
        OsdService().adjustBrightness(-0.05);
      case IpcAction.brightnessOsd:
        OsdService().showBrightnessOsd();
    }
  }

  void _closeAllOverlays() {
    if (_hasAnyOverlayOpen) {
      setState(() {
        _isLauncherOpen = false;
        _isCalendarOpen = false;
        _isQuickSettingsOpen = false;
        _isImeMenuOpen = false;
        _isCaptureToolbarOpen = false;
      });
      // Shrink layer surface back to shelf height
      LayerShellService.setHeight(56);
      LayerShellService.setKeyboardMode(false);
    }
  }

  void _openCaptureToolbar() {
    setState(() {
      _isCaptureToolbarOpen = true;
      _isLauncherOpen = false;
      _isCalendarOpen = false;
      _isQuickSettingsOpen = false;
      _isImeMenuOpen = false;
    });
    // Floats right above shelf at bottom-center (GNOME style)
    LayerShellService.setHeight(140);
    LayerShellService.setKeyboardMode(false);
  }

  void _closeCaptureToolbar() {
    setState(() {
      _isCaptureToolbarOpen = false;
    });
    LayerShellService.setHeight(56);
  }

  void _toggleLauncher() {
    setState(() {
      _isLauncherOpen = !_isLauncherOpen;
      _isCalendarOpen = false;
      _isQuickSettingsOpen = false;
      _isImeMenuOpen = false;
      _isCaptureToolbarOpen = false;
    });

    if (_isLauncherOpen) {
      LayerShellService.setHeight(600);
    } else {
      LayerShellService.setHeight(56);
      LayerShellService.setKeyboardMode(false);
    }
  }

  void _toggleCalendar() {
    setState(() {
      _isCalendarOpen = !_isCalendarOpen;
      _isLauncherOpen = false;
      _isQuickSettingsOpen = false;
      _isImeMenuOpen = false;
      _isCaptureToolbarOpen = false;
    });

    if (_isCalendarOpen) {
      LayerShellService.setHeight(600);
      LayerShellService.setKeyboardMode(false);
    } else {
      LayerShellService.setHeight(56);
    }
  }

  void _toggleQuickSettings() {
    setState(() {
      _isQuickSettingsOpen = !_isQuickSettingsOpen;
      _isLauncherOpen = false;
      _isCalendarOpen = false;
      _isImeMenuOpen = false;
      _isCaptureToolbarOpen = false;
    });

    if (_isQuickSettingsOpen) {
      LayerShellService.setHeight(640);
      LayerShellService.setKeyboardMode(false);
    } else {
      LayerShellService.setHeight(56);
    }
  }

  void _toggleImeMenu() {
    setState(() {
      _isImeMenuOpen = !_isImeMenuOpen;
      _isLauncherOpen = false;
      _isCalendarOpen = false;
      _isQuickSettingsOpen = false;
      _isCaptureToolbarOpen = false;
    });

    if (_isImeMenuOpen) {
      LayerShellService.setHeight(360);
      LayerShellService.setKeyboardMode(false);
    } else {
      LayerShellService.setHeight(56);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay = _hasAnyOverlayOpen;

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

          // 3. Calendar Popup (Anchored right above Date Pill & Tray)
          if (_isCalendarOpen)
            Positioned(
              right: 12,
              bottom: AmeliaTheme.shelfHeight + 8,
              child: CalendarPanel(
                onClose: _closeAllOverlays,
              ),
            ),

          // 4. Quick Settings Popup (Anchored at Bottom-Right above Shelf)
          if (_isQuickSettingsOpen)
            Positioned(
              right: 12,
              bottom: AmeliaTheme.shelfHeight + 8,
              child: QuickSettingsPanel(
                onClose: _closeAllOverlays,
                onOpenCapture: _openCaptureToolbar,
              ),
            ),

          // 5. Input Method Popup (Anchored directly above InputMethodPill)
          if (_isImeMenuOpen)
            Positioned(
              right: 180,
              bottom: AmeliaTheme.shelfHeight + 8,
              child: InputMethodPanel(
                onClose: _closeAllOverlays,
              ),
            ),

          // 6. GNOME-style Screen Capture Toolbar (floats bottom-center right above shelf)
          if (_isCaptureToolbarOpen)
            Positioned(
              bottom: AmeliaTheme.shelfHeight + 14,
              left: 0,
              right: 0,
              child: Center(
                child: CaptureToolbar(
                  onClose: _closeCaptureToolbar,
                ),
              ),
            ),

          // 6b. OSD Overlay (floats bottom-center when volume/brightness adjusts)
          ValueListenableBuilder<OsdData?>(
            valueListenable: OsdService().currentOsd,
            builder: (context, osd, _) {
              if (osd == null || _isCaptureToolbarOpen) return const SizedBox.shrink();
              return Positioned(
                bottom: AmeliaTheme.shelfHeight + 14,
                left: 0,
                right: 0,
                child: Center(
                  child: OsdOverlay(data: osd),
                ),
              );
            },
          ),

          // 7. Main Shelf (Anchored at Bottom Edge)
          Align(
            alignment: Alignment.bottomCenter,
            child: ShelfWidget(
              isLauncherOpen: _isLauncherOpen,
              isCalendarOpen: _isCalendarOpen,
              isQuickSettingsOpen: _isQuickSettingsOpen,
              isImeMenuOpen: _isImeMenuOpen,
              onToggleLauncher: _toggleLauncher,
              onToggleCalendar: _toggleCalendar,
              onToggleQuickSettings: _toggleQuickSettings,
              onToggleImeMenu: _toggleImeMenu,
            ),
          ),
        ],
      ),
    );
  }
}
