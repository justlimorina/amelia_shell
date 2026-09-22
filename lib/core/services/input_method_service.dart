import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Represents an available input method engine (e.g. Lotus, English US, Bamboo, Mozc).
class InputMethodEngine {
  final String id;
  final String name;
  final String shortLabel;
  final String? icon;

  const InputMethodEngine({
    required this.id,
    required this.name,
    required this.shortLabel,
    this.icon,
  });

  @override
  String toString() => 'InputMethodEngine(id: $id, name: $name, shortLabel: $shortLabel)';
}

/// Represents the current state of the active IME system.
class InputMethodState {
  final bool isAvailable;
  final bool isActive;
  final String currentEngineId;
  final String currentEngineName;
  final String shortLabel;
  final List<InputMethodEngine> availableEngines;

  const InputMethodState({
    this.isAvailable = false,
    this.isActive = false,
    this.currentEngineId = '',
    this.currentEngineName = '',
    this.shortLabel = 'EN',
    this.availableEngines = const [],
  });

  InputMethodState copyWith({
    bool? isAvailable,
    bool? isActive,
    String? currentEngineId,
    String? currentEngineName,
    String? shortLabel,
    List<InputMethodEngine>? availableEngines,
  }) {
    return InputMethodState(
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      currentEngineId: currentEngineId ?? this.currentEngineId,
      currentEngineName: currentEngineName ?? this.currentEngineName,
      shortLabel: shortLabel ?? this.shortLabel,
      availableEngines: availableEngines ?? this.availableEngines,
    );
  }

  @override
  String toString() =>
      'InputMethodState(available: $isAvailable, active: $isActive, engine: $currentEngineId ($shortLabel))';
}

/// Abstract contract for IME backends (Fcitx5, IBus, Kimpanel).
abstract class InputMethodBackend {
  Future<bool> isRunning();
  Future<InputMethodState> getState();
  Future<void> toggle();
  Future<void> switchEngine(String engineId);
  Future<void> openSettings();
  void dispose();
}

/// Helper to derive user-friendly 2-3 char short labels from engine IDs and language codes.
String deriveShortLabel({
  required String engineId,
  required bool isActive,
  String languageCode = '',
}) {
  if (!isActive) return 'EN';

  final lang = languageCode.trim().toLowerCase();
  if (lang.isNotEmpty) {
    if (lang == 'vi' || lang.startsWith('vi_')) return 'VI';
    if (lang == 'ja' || lang.startsWith('ja_')) return 'JA';
    if (lang == 'zh' || lang.startsWith('zh_')) return 'ZH';
    if (lang == 'ko' || lang.startsWith('ko_')) return 'KO';
    if (lang == 'fr' || lang.startsWith('fr_')) return 'FR';
    if (lang == 'de' || lang.startsWith('de_')) return 'DE';
    if (lang == 'es' || lang.startsWith('es_')) return 'ES';
    if (lang == 'ru' || lang.startsWith('ru_')) return 'RU';
    if (lang.length <= 3) return lang.toUpperCase();
  }

  final id = engineId.toLowerCase();
  if (id.contains('lotus') ||
      id.contains('bamboo') ||
      id.contains('unikey') ||
      id.contains('telex') ||
      id.contains('vni')) {
    return 'VI';
  }
  if (id.contains('mozc') || id.contains('anthy') || id.contains('kkc')) {
    return 'JA';
  }
  if (id.contains('pinyin') ||
      id.contains('rime') ||
      id.contains('wubi') ||
      id.contains('chewing') ||
      id.contains('bopomofo')) {
    return 'ZH';
  }
  if (id.contains('hangul')) {
    return 'KO';
  }
  if (id.startsWith('keyboard-')) {
    final sub = id.replaceFirst('keyboard-', '');
    if (sub == 'us') return 'EN';
    if (sub.length <= 3) return sub.toUpperCase();
  }

  if (id.length <= 2) return id.toUpperCase();
  return id.substring(0, 2).toUpperCase();
}

/// Fcitx5 Backend communicating via D-Bus `org.fcitx.Fcitx5` at `/controller`
/// with CLI `fcitx5-remote` fallback.
class Fcitx5Backend implements InputMethodBackend {
  DBusClient? _client;
  bool? _cachedIsRunning;

  DBusClient _getClient() {
    _client ??= DBusClient.session();
    return _client!;
  }

  @override
  Future<bool> isRunning() async {
    try {
      final client = _getClient();
      final names = await client.listNames();
      final hasFcitx5 = names.contains('org.fcitx.Fcitx5');
      _cachedIsRunning = hasFcitx5;
      return hasFcitx5;
    } catch (_) {
      // Fallback check using CLI
      try {
        final result = await Process.run('fcitx5-remote', ['--check']);
        _cachedIsRunning = result.exitCode == 0;
        return _cachedIsRunning!;
      } catch (_) {
        _cachedIsRunning = false;
        return false;
      }
    }
  }

  @override
  Future<InputMethodState> getState() async {
    final running = _cachedIsRunning ?? await isRunning();
    if (!running) {
      return const InputMethodState(isAvailable: false);
    }

    try {
      final client = _getClient();
      final object = DBusRemoteObject(
        client,
        name: 'org.fcitx.Fcitx5',
        path: DBusObjectPath('/controller'),
      );

      // Query State (1 = inactive, 2 = active)
      final stateResponse = await object.callMethod(
        'org.fcitx.Fcitx.Controller1',
        'State',
        [],
      );
      final stateVal = (stateResponse.values.first as DBusInt32).value;
      final isActive = stateVal == 2;

      // Query CurrentInputMethodInfo
      final infoResponse = await object.callMethod(
        'org.fcitx.Fcitx.Controller1',
        'CurrentInputMethodInfo',
        [],
      );
      final uniqueName = (infoResponse.values[0] as DBusString).value;
      final displayName = (infoResponse.values[1] as DBusString).value;
      final langCode = (infoResponse.values[5] as DBusString).value;

      // Query InputMethodGroupInfo to get list of available engines in group
      List<InputMethodEngine> engines = [];
      try {
        final groupResponse = await object.callMethod(
          'org.fcitx.Fcitx.Controller1',
          'InputMethodGroupInfo',
          [const DBusString('Default')],
        );
        if (groupResponse.values.length > 1 &&
            groupResponse.values[1] is DBusArray) {
          final array = groupResponse.values[1] as DBusArray;
          for (final item in array.children) {
            if (item is DBusStruct && item.children.isNotEmpty) {
              final id = (item.children[0] as DBusString).value;
              final short = deriveShortLabel(
                engineId: id,
                isActive: true,
                languageCode: id.contains('lotus') ? 'vi' : '',
              );
              final name = id == 'lotus'
                  ? 'Lotus (Vietnamese)'
                  : (id == 'keyboard-us' ? 'English (US)' : id);
              engines.add(InputMethodEngine(
                id: id,
                name: name,
                shortLabel: short,
              ));
            }
          }
        }
      } catch (_) {
        // Fallback engine list
        engines = [
          InputMethodEngine(
            id: uniqueName,
            name: displayName.isNotEmpty ? displayName : uniqueName,
            shortLabel: deriveShortLabel(
              engineId: uniqueName,
              isActive: true,
              languageCode: langCode,
            ),
          ),
        ];
      }

      final label = deriveShortLabel(
        engineId: uniqueName,
        isActive: isActive,
        languageCode: langCode,
      );

      return InputMethodState(
        isAvailable: true,
        isActive: isActive,
        currentEngineId: uniqueName,
        currentEngineName: displayName.isNotEmpty ? displayName : uniqueName,
        shortLabel: label,
        availableEngines: engines,
      );
    } catch (e) {
      // Fallback via CLI if DBus call timed out
      return _getStateViaCli();
    }
  }

  Future<InputMethodState> _getStateViaCli() async {
    try {
      final stateRes = await Process.run('fcitx5-remote', []);
      final nameRes = await Process.run('fcitx5-remote', ['-n']);

      final stateInt = int.tryParse(stateRes.stdout.toString().trim()) ?? 0;
      final engine = nameRes.stdout.toString().trim();
      final isActive = stateInt == 2;
      final label = deriveShortLabel(
        engineId: engine,
        isActive: isActive,
      );

      return InputMethodState(
        isAvailable: stateInt > 0,
        isActive: isActive,
        currentEngineId: engine,
        currentEngineName: engine,
        shortLabel: label,
        availableEngines: [
          InputMethodEngine(
            id: engine,
            name: engine,
            shortLabel: label,
          ),
        ],
      );
    } catch (_) {
      return const InputMethodState(isAvailable: false);
    }
  }

  @override
  Future<void> toggle() async {
    try {
      final client = _getClient();
      final object = DBusRemoteObject(
        client,
        name: 'org.fcitx.Fcitx5',
        path: DBusObjectPath('/controller'),
      );
      await object.callMethod(
        'org.fcitx.Fcitx.Controller1',
        'Toggle',
        [],
      );
    } catch (_) {
      // Fallback to CLI
      try {
        await Process.run('fcitx5-remote', ['-t']);
      } catch (_) {}
    }
  }

  @override
  Future<void> switchEngine(String engineId) async {
    try {
      final client = _getClient();
      final object = DBusRemoteObject(
        client,
        name: 'org.fcitx.Fcitx5',
        path: DBusObjectPath('/controller'),
      );
      await object.callMethod(
        'org.fcitx.Fcitx.Controller1',
        'SetCurrentIM',
        [DBusString(engineId)],
      );
    } catch (_) {
      try {
        await Process.run('fcitx5-remote', ['-s', engineId]);
      } catch (_) {}
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await Process.start('fcitx5-configtool', []);
    } catch (_) {}
  }

  @override
  void dispose() {
    _client?.close();
    _client = null;
  }
}

/// IBus Backend for systems running ibus-daemon.
class IBusBackend implements InputMethodBackend {
  bool? _cachedIsRunning;

  @override
  Future<bool> isRunning() async {
    try {
      final res = await Process.run('ibus', ['engine']);
      _cachedIsRunning = res.exitCode == 0;
      return _cachedIsRunning!;
    } catch (_) {
      _cachedIsRunning = false;
      return false;
    }
  }

  @override
  Future<InputMethodState> getState() async {
    try {
      final res = await Process.run('ibus', ['engine']);
      if (res.exitCode != 0) {
        return const InputMethodState(isAvailable: false);
      }
      final engine = res.stdout.toString().trim();
      final isEnglish = engine.isEmpty || engine.contains('xkb:us') || engine.contains('eng');
      final isActive = !isEnglish;
      final label = deriveShortLabel(
        engineId: engine,
        isActive: isActive,
      );

      return InputMethodState(
        isAvailable: true,
        isActive: isActive,
        currentEngineId: engine,
        currentEngineName: engine,
        shortLabel: label,
        availableEngines: [
          InputMethodEngine(
            id: engine,
            name: engine,
            shortLabel: label,
          ),
        ],
      );
    } catch (_) {
      return const InputMethodState(isAvailable: false);
    }
  }

  @override
  Future<void> toggle() async {
    // For ibus, toggle between current engine and English if possible
    try {
      final res = await Process.run('ibus', ['engine']);
      final current = res.stdout.toString().trim();
      if (current.contains('xkb:us') || current.contains('eng')) {
        // Switch to default Vietnamese / IME engine if configured
        await Process.run('ibus', ['engine', 'Bamboo']);
      } else {
        await Process.run('ibus', ['engine', 'xkb:us::eng']);
      }
    } catch (_) {}
  }

  @override
  Future<void> switchEngine(String engineId) async {
    try {
      await Process.run('ibus', ['engine', engineId]);
    } catch (_) {}
  }

  @override
  Future<void> openSettings() async {
    try {
      await Process.start('ibus-setup', []);
    } catch (_) {}
  }

  @override
  void dispose() {}
}

/// Central Singleton Service managing Input Method states and backends.
class InputMethodService {
  static final InputMethodService _instance = InputMethodService._internal();
  factory InputMethodService() => _instance;
  InputMethodService._internal();

  InputMethodBackend? _backend;
  Timer? _pollTimer;

  final ValueNotifier<InputMethodState> stateNotifier =
      ValueNotifier<InputMethodState>(const InputMethodState());

  InputMethodState get currentState => stateNotifier.value;

  Future<void> start() async {
    // 1. Detect and select backend
    final fcitx5 = Fcitx5Backend();
    if (await fcitx5.isRunning()) {
      _backend = fcitx5;
    } else {
      fcitx5.dispose();
      final ibus = IBusBackend();
      if (await ibus.isRunning()) {
        _backend = ibus;
      } else {
        ibus.dispose();
      }
    }

    if (_backend != null) {
      await updateState();
      // Poll every 1.5 seconds to capture global shortcut toggles (e.g. Ctrl+Space)
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        updateState();
      });
    }
  }

  Future<void> updateState() async {
    if (_backend == null) return;
    try {
      final newState = await _backend!.getState();
      if (stateNotifier.value.toString() != newState.toString()) {
        stateNotifier.value = newState;
      }
    } catch (e) {
      debugPrint('InputMethodService.updateState error: $e');
    }
  }

  Future<void> toggle() async {
    if (_backend == null) return;
    await _backend!.toggle();
    await updateState();
  }

  Future<void> switchEngine(String engineId) async {
    if (_backend == null) return;
    await _backend!.switchEngine(engineId);
    await updateState();
  }

  Future<void> openSettings() async {
    if (_backend == null) return;
    await _backend!.openSettings();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _backend?.dispose();
    _backend = null;
  }
}

