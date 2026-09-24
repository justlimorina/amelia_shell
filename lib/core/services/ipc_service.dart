import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum IpcAction {
  toggleLauncher,
  openLauncher,
  closeLauncher,
  toggleQuickSettings,
  openQuickSettings,
  closeQuickSettings,
  toggleCalendar,
  openCalendar,
  closeCalendar,
  toggleIme,
  openIme,
  closeIme,
  openCapture,
  captureFull,
  captureSelection,
  captureWindow,
  closeAll,
  volumeUp,
  volumeDown,
  volumeMute,
  volumeOsd,
  brightnessUp,
  brightnessDown,
  brightnessOsd,
}

/// Service providing a local Unix domain socket IPC server for external control
/// (e.g., from compositor keybindings in hyprland.conf, sway/config, or scripts).
class IpcService {
  static final IpcService _instance = IpcService._internal();
  factory IpcService() => _instance;
  IpcService._internal();

  ServerSocket? _server;
  final _actionController = StreamController<IpcAction>.broadcast();
  Stream<IpcAction> get actionStream => _actionController.stream;

  /// Path to the Unix domain socket.
  static String get socketPath {
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtimeDir != null && runtimeDir.isNotEmpty) {
      return '$runtimeDir/amelia_shell.sock';
    }
    final user = Platform.environment['USER'] ?? 'user';
    return '/tmp/amelia_shell_$user.sock';
  }

  /// Start the IPC server. If a stale socket exists, cleans it up.
  Future<void> start() async {
    final path = socketPath;
    final file = File(path);

    if (file.existsSync()) {
      // Test if an active server is actually listening
      try {
        final testSock = await Socket.connect(
          InternetAddress(path, type: InternetAddressType.unix),
          0,
          timeout: const Duration(milliseconds: 250),
        );
        testSock.destroy();
        debugPrint('IpcService: another amelia_shell instance is already running on $path');
        return;
      } catch (_) {
        // Socket file exists but no one is listening -> clean up stale file
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }

    try {
      _server = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      _server!.listen(_handleConnection, onError: (e) {
        debugPrint('IpcService server error: $e');
      });
      debugPrint('IpcService listening on $path');
    } catch (e) {
      debugPrint('IpcService bind failed: $e');
    }
  }

  void _handleConnection(Socket client) {
    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      final reply = await processCommand(trimmed);
      try {
        client.writeln(reply);
        await client.flush();
        client.close();
      } catch (_) {}
    });
  }

  /// Process an incoming text command and return the response string.
  Future<String> processCommand(String rawCommand) async {
    final parts = rawCommand.split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();

    switch (cmd) {
      case 'ping':
        return 'pong';

      case 'toggle-launcher':
      case 'launcher':
        _actionController.add(IpcAction.toggleLauncher);
        return 'OK: toggle-launcher';

      case 'open-launcher':
        _actionController.add(IpcAction.openLauncher);
        return 'OK: open-launcher';

      case 'close-launcher':
        _actionController.add(IpcAction.closeLauncher);
        return 'OK: close-launcher';

      case 'toggle-quick-settings':
      case 'toggle-qs':
      case 'quick-settings':
      case 'control-center':
        _actionController.add(IpcAction.toggleQuickSettings);
        return 'OK: toggle-quick-settings';

      case 'open-quick-settings':
        _actionController.add(IpcAction.openQuickSettings);
        return 'OK: open-quick-settings';

      case 'close-quick-settings':
        _actionController.add(IpcAction.closeQuickSettings);
        return 'OK: close-quick-settings';

      case 'toggle-calendar':
      case 'calendar':
        _actionController.add(IpcAction.toggleCalendar);
        return 'OK: toggle-calendar';

      case 'open-calendar':
        _actionController.add(IpcAction.openCalendar);
        return 'OK: open-calendar';

      case 'close-calendar':
        _actionController.add(IpcAction.closeCalendar);
        return 'OK: close-calendar';

      case 'toggle-ime':
      case 'ime':
        _actionController.add(IpcAction.toggleIme);
        return 'OK: toggle-ime';

      case 'capture':
      case 'screenshot':
      case 'capture-toolbar':
        _actionController.add(IpcAction.openCapture);
        return 'OK: capture-toolbar';

      case 'capture-full':
      case 'capture-screen':
        _actionController.add(IpcAction.captureFull);
        return 'OK: capture-screen';

      case 'capture-selection':
      case 'capture-region':
        _actionController.add(IpcAction.captureSelection);
        return 'OK: capture-selection';

      case 'capture-window':
        _actionController.add(IpcAction.captureWindow);
        return 'OK: capture-window';

      case 'close-all':
      case 'close':
        _actionController.add(IpcAction.closeAll);
        return 'OK: close-all';

      case 'volume-up':
        _actionController.add(IpcAction.volumeUp);
        return 'OK: volume-up';

      case 'volume-down':
        _actionController.add(IpcAction.volumeDown);
        return 'OK: volume-down';

      case 'volume-mute':
      case 'mute':
        _actionController.add(IpcAction.volumeMute);
        return 'OK: volume-mute';

      case 'volume-osd':
        _actionController.add(IpcAction.volumeOsd);
        return 'OK: volume-osd';

      case 'brightness-up':
        _actionController.add(IpcAction.brightnessUp);
        return 'OK: brightness-up';

      case 'brightness-down':
        _actionController.add(IpcAction.brightnessDown);
        return 'OK: brightness-down';

      case 'brightness-osd':
        _actionController.add(IpcAction.brightnessOsd);
        return 'OK: brightness-osd';

      case 'help':
      case '--help':
      case '-h':
        return '''Available Amelia Shell IPC commands:
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
  ping                    Check if shell is alive''';

      default:
        return 'ERROR: unknown command "$rawCommand" (try "help")';
    }
  }

  /// Client helper to send an IPC command from the command line.
  static Future<int> sendCommand(List<String> args) async {
    final path = socketPath;
    if (!File(path).existsSync()) {
      stderr.writeln('Error: Amelia Shell is not running (socket $path not found).');
      return 1;
    }

    try {
      final socket = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );

      final cmd = args.join(' ');
      socket.writeln(cmd);
      await socket.flush();

      await for (final chunk in socket.cast<List<int>>().transform(utf8.decoder)) {
        stdout.write(chunk);
      }
      socket.destroy();
      return 0;
    } catch (e) {
      stderr.writeln('Error connecting to Amelia Shell IPC: $e');
      return 1;
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    final file = File(socketPath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }
}
