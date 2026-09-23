import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/network_service.dart';
import '../../core/services/system_service.dart';
import '../../core/theme/theme.dart';
import '../media_player/media_player_card.dart';

enum QuickSettingsView { main, wifi, bluetooth }

class BluetoothDevice {
  final String mac;
  final String name;
  final bool isConnected;

  const BluetoothDevice({
    required this.mac,
    required this.name,
    required this.isConnected,
  });
}

class AudioOutput {
  final String id;
  final String name;
  final bool isDefault;

  const AudioOutput({
    required this.id,
    required this.name,
    required this.isDefault,
  });
}

class QuickSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onOpenCapture;

  const QuickSettingsPanel({
    super.key,
    required this.onClose,
    this.onOpenCapture,
  });

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  QuickSettingsView _currentView = QuickSettingsView.main;

  bool _wifiEnabled = true;
  bool _bluetoothEnabled = false;
  bool _dndEnabled = false;
  bool _nightLightEnabled = false;
  bool _airplaneModeEnabled = false;

  double _volume = 0.75;
  double _brightness = 0.8;

  List<WifiNetwork> _wifiNetworks = [];
  bool _isScanningWifi = false;

  List<BluetoothDevice> _bluetoothDevices = [];
  bool _isLoadingBluetooth = false;

  // Tool availability (detected once; pods are hidden when the tool is missing).
  bool _hasNmcli = true;
  bool _hasBluetoothctl = true;
  bool _hasGrim = true;
  bool _hasGammastep = true;
  bool _hasWlsunset = false;
  String? _dndTool; // 'dunstctl' | 'swaync-client' | null

  Process? _wlsunsetProc;

  @override
  void initState() {
    super.initState();
    _detectTools();
  }

  /// Run a system command and swallow "binary not found" / other errors so the
  /// UI never crashes when a tool is missing.
  Future<ProcessResult?> _run(String cmd, List<String> args) async {
    try {
      return await Process.run(cmd, args);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _toolExists(String tool) async {
    try {
      final r = await Process.run('sh', ['-c', 'command -v $tool']);
      final out = r.stdout?.toString().trim() ?? '';
      return r.exitCode == 0 && out.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _detectTools() async {
    _hasNmcli = await _toolExists('nmcli');
    _hasBluetoothctl = await _toolExists('bluetoothctl');
    _hasGrim = await _toolExists('grim');
    _hasGammastep = await _toolExists('gammastep');
    _hasWlsunset = await _toolExists('wlsunset');

    final hasDunst = await _toolExists('dunstctl');
    final hasSwaync = await _toolExists('swaync-client');
    _dndTool = hasDunst
        ? 'dunstctl'
        : hasSwaync
            ? 'swaync-client'
            : null;

    if (_hasNmcli) {
      await _checkWifiState();
    }
    if (_hasBluetoothctl) {
      await _loadBluetoothState();
    }

    if (mounted) setState(() {});
  }

  Future<void> _checkWifiState() async {
    final enabled = await NetworkService().isWifiEnabled();
    if (mounted) {
      setState(() => _wifiEnabled = enabled);
    }
  }

  Future<void> _loadBluetoothState() async {
    final r = await _run('bluetoothctl', ['show']);
    if (r == null) return;
    final line = r.stdout
        .toString()
        .split('\n')
        .where((l) => l.trim().startsWith('Powered:'))
        .firstOrNull;
    final powered = line != null && line.trim().endsWith(' yes');
    if (mounted) {
      setState(() => _bluetoothEnabled = powered);
    }
  }

  // ---------------------------------------------------------------------------
  // Toggles (all wired to real system tools)
  // ---------------------------------------------------------------------------

  void _toggleWifi() {
    final next = !_wifiEnabled;
    setState(() => _wifiEnabled = next);
    NetworkService().setWifiEnabled(next);
    if (next) _scanWifi();
  }

  Future<void> _toggleBluetooth([bool? value]) async {
    final next = value ?? !_bluetoothEnabled;
    setState(() => _bluetoothEnabled = next);
    await _run('bluetoothctl', ['power', next ? 'on' : 'off']);
    if (next) {
      _loadBluetoothDevices();
    } else if (mounted) {
      setState(() => _bluetoothDevices = []);
    }
  }

  void _toggleDnd() {
    final next = !_dndEnabled;
    setState(() => _dndEnabled = next);
    switch (_dndTool) {
      case 'dunstctl':
        _run('dunstctl', ['set-paused', next ? 'true' : 'false']);
      case 'swaync-client':
        _run('swaync-client', [next ? '-d' : '-D']);
    }
  }

  Future<void> _toggleNightLight() async {
    final next = !_nightLightEnabled;
    setState(() => _nightLightEnabled = next);

    if (_hasGammastep) {
      // gammastep one-shot: applies the gamma immediately then exits.
      if (next) {
        await _run('gammastep', ['-O', '4000']);
      } else {
        await _run('gammastep', ['-x']);
      }
    } else if (_hasWlsunset) {
      if (next) {
        _wlsunsetProc = await Process.start('wlsunset', ['-t', '4000']);
      } else {
        _wlsunsetProc?.kill(ProcessSignal.sigterm);
        _wlsunsetProc = null;
        await _run('pkill', ['wlsunset']);
      }
    }
  }

  void _toggleAirplaneMode() {
    final next = !_airplaneModeEnabled;
    setState(() {
      _airplaneModeEnabled = next;
      _wifiEnabled = !next;
      _bluetoothEnabled = !next;
    });
    _run('nmcli', ['radio', 'all', next ? 'off' : 'on']);
    if (_hasBluetoothctl) {
      _run('bluetoothctl', ['power', next ? 'off' : 'on']);
    }
  }

  // ---------------------------------------------------------------------------
  // Submenu navigation
  // ---------------------------------------------------------------------------

  void _openWifiSubmenu() {
    setState(() {
      _currentView = QuickSettingsView.wifi;
      _isScanningWifi = true;
    });
    _scanWifi();
  }

  void _openBluetoothSubmenu() {
    setState(() {
      _currentView = QuickSettingsView.bluetooth;
    });
    if (_bluetoothEnabled) {
      _loadBluetoothDevices();
    }
  }

  Future<void> _scanWifi() async {
    setState(() => _isScanningWifi = true);
    final networks = await NetworkService().scanWifi();
    if (mounted) {
      setState(() {
        _wifiNetworks = networks;
        _isScanningWifi = false;
      });
    }
  }

  Future<void> _loadBluetoothDevices() async {
    if (mounted) setState(() => _isLoadingBluetooth = true);

    final connectedResult = await _run('bluetoothctl', ['devices', 'Connected']);
    final connectedMacs = <String>{};
    if (connectedResult != null && connectedResult.exitCode == 0) {
      for (final line in connectedResult.stdout.toString().split('\n')) {
        final m = RegExp(r'Device ([0-9A-Fa-f:]+)').firstMatch(line);
        if (m != null) connectedMacs.add(m.group(1)!.toUpperCase());
      }
    }

    final pairedResult = await _run('bluetoothctl', ['devices', 'Paired']);
    final devices = <BluetoothDevice>[];
    if (pairedResult != null && pairedResult.exitCode == 0) {
      for (final line in pairedResult.stdout.toString().split('\n')) {
        final m = RegExp(r'Device ([0-9A-Fa-f:]+)\s+(.+)$').firstMatch(line.trim());
        if (m != null) {
          devices.add(BluetoothDevice(
            mac: m.group(1)!.toUpperCase(),
            name: m.group(2)!.trim(),
            isConnected: connectedMacs.contains(m.group(1)!.toUpperCase()),
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _bluetoothDevices = devices;
        _isLoadingBluetooth = false;
      });
    }
  }

  Future<void> _toggleBluetoothDevice(BluetoothDevice device) async {
    if (device.isConnected) {
      await _run('bluetoothctl', ['disconnect', device.mac]);
    } else {
      await _run('bluetoothctl', ['connect', device.mac]);
    }
    _loadBluetoothDevices();
  }

  Future<List<AudioOutput>> _loadAudioOutputs() async {
    final r = await _run('wpctl', ['status']);
    if (r == null || r.exitCode != 0) return [];

    final outputs = <AudioOutput>[];
    var inSinks = false;
    final sinkRe = RegExp(r'^\s*[│├└]?\s*\*?\s*(\d+)\.\s+(.+?)(?:\s*\[|$)');
    for (final raw in r.stdout.toString().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.contains('Sinks:')) {
        inSinks = true;
        continue;
      }
      if (inSinks) {
        // Next tree section ends the sink list.
        if (RegExp(r'^[├└]').hasMatch(line) ||
            (line.endsWith(':') && !RegExp(r'^\d+\.').hasMatch(line))) {
          inSinks = false;
          continue;
        }
        final m = sinkRe.firstMatch(line);
        if (m != null) {
          final isDefault = line.contains(r'*') || line.startsWith('*');
          outputs.add(AudioOutput(
            id: m.group(1)!,
            name: m.group(2)!.trim(),
            isDefault: isDefault,
          ));
        }
      }
    }
    return outputs;
  }

  Future<void> _showAudioOutputs() async {
    final colorScheme = Theme.of(context).colorScheme;
    final outputs = await _loadAudioOutputs();
    if (!mounted || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? defaultId;
        for (final out in outputs) {
          if (out.isDefault) defaultId = out.id;
        }
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Audio outputs',
            style: TextStyle(fontFamily: 'Roboto'),
          ),
          content: SizedBox(
            width: 320,
            child: outputs.isEmpty
                ? const Text(
                    'No audio outputs found',
                    style: TextStyle(fontFamily: 'Roboto'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final out in outputs)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            out.isDefault
                                ? Symbols.volume_up_rounded
                                : Symbols.speaker_rounded,
                            size: 20,
                            fill: 1,
                            weight: 300,
                            grade: 0,
                            color: out.isDefault
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            out.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          trailing: out.isDefault
                              ? Icon(
                                  Symbols.check_rounded,
                                  size: 18,
                                  fill: 1,
                                  weight: 300,
                                  grade: 0,
                                  color: colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            if (out.id != defaultId) {
                              _run('wpctl', ['set-default', out.id]);
                            }
                          },
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 390,
      constraints: const BoxConstraints(maxHeight: 620),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildCurrentView(context),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context) {
    switch (_currentView) {
      case QuickSettingsView.wifi:
        return _buildWifiSubmenu(context);
      case QuickSettingsView.bluetooth:
        return _buildBluetoothSubmenu(context);
      case QuickSettingsView.main:
        return _buildMainView(context);
    }
  }

  Widget _buildMainView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final systemService = SystemService();
    final dateStr = DateFormat('EEE, MMM d').format(DateTime.now());
    final currentUser = Platform.environment['USER'] ?? 'user';

    return Column(
      key: const ValueKey('main_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ChromeOS Top Bar: User Avatar, Sign Out & System Actions
        Row(
          children: [
            // User Avatar chip
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                currentUser.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // "Sign out" pill button
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Process.run('loginctl', ['terminate-user', currentUser]);
                widget.onClose();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Sign out',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Power button
            _HeaderIconButton(
              icon: Symbols.power_settings_new_rounded,
              tooltip: 'Power off',
              onTap: () {
                Process.run('wlogout', []).catchError((_) {
                  return Process.run('systemctl', ['poweroff']);
                });
                widget.onClose();
              },
            ),
            const SizedBox(width: 6),

            // Lock screen button
            _HeaderIconButton(
              icon: Symbols.lock_rounded,
              tooltip: 'Lock',
              onTap: () {
                Process.run('loginctl', ['lock-session']);
                widget.onClose();
              },
            ),
            const SizedBox(width: 6),

            // Settings gear button
            _HeaderIconButton(
              icon: Symbols.settings_rounded,
              tooltip: 'Settings',
              onTap: () {
                Process.run('gnome-control-center', []);
                widget.onClose();
              },
            ),
            const SizedBox(width: 6),

            // Collapse chevron
            _HeaderIconButton(
              icon: Symbols.keyboard_arrow_up_rounded,
              tooltip: 'Collapse',
              onTap: widget.onClose,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // MPRIS Media Player Card (Auto-hides if no media active)
        const MediaPlayerCard(),

        // 2. Feature Pods Grid (3 columns, ChromeOS style).
        // Only pods whose backing tool is installed are shown - no fake toggles.
        _buildPodGrid(),

        const SizedBox(height: 16),

        // 3. Sliders: Volume with Output Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _HeaderIconButton(
                icon: _volume > 0
                    ? Symbols.volume_up_rounded
                    : Symbols.volume_mute_rounded,
                tooltip: 'Mute / Unmute',
                onTap: () {
                  final newVol = _volume > 0 ? 0.0 : 0.75;
                  setState(() => _volume = newVol);
                  _run('wpctl', [
                    'set-volume',
                    '@DEFAULT_AUDIO_SINK@',
                    '${(newVol * 100).toInt()}%'
                  ]);
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: colorScheme.primary,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _volume,
                    onChanged: (val) {
                      setState(() => _volume = val);
                      _run('wpctl', [
                        'set-volume',
                        '@DEFAULT_AUDIO_SINK@',
                        '${(val * 100).toInt()}%'
                      ]);
                    },
                  ),
                ),
              ),
              _HeaderIconButton(
                icon: Symbols.chevron_right_rounded,
                tooltip: 'Audio outputs',
                onTap: _showAudioOutputs,
              ),
            ],
          ),
        ),

        // 4. Sliders: Display Brightness
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _HeaderIconButton(
                icon: Symbols.brightness_medium_rounded,
                tooltip: 'Brightness',
                onTap: () {},
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: colorScheme.primary,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _brightness,
                    onChanged: (val) {
                      setState(() => _brightness = val);
                      _run(
                        'brightnessctl', ['s', '${(val * 100).toInt()}%']);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 32),
            ],
          ),
        ),

        const SizedBox(height: 10),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 10),

        // 5. Footer: Date & Battery / Time Estimate
        StreamBuilder<BatteryInfo>(
          stream: systemService.batteryStream,
          initialData: systemService.currentBattery,
          builder: (context, snapshot) {
            final battery = snapshot.data ?? systemService.currentBattery;

            return Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  battery.isCharging
                      ? Symbols.battery_charging_full_rounded
                      : (battery.percentage >= 50
                          ? Symbols.battery_5_bar_rounded
                          : Symbols.battery_3_bar_rounded),
                  size: 16,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${battery.percentage}%'
                  '${battery.isCharging ? ' • Charging' : ' left'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPodGrid() {
    final themeService = ThemeService();
    final isDark = themeService.isDarkMode;

    final pods = <Widget>[
      // Wi-Fi (nmcli)
      if (_hasNmcli)
        _FeaturePod(
          icon: _wifiEnabled
              ? Symbols.wifi_rounded
              : Symbols.wifi_off_rounded,
          title: _wifiEnabled ? 'Wi-Fi' : 'Off',
          subtitle: _wifiEnabled ? 'Connected' : null,
          isActive: _wifiEnabled,
          hasSubmenu: true,
          onToggle: _toggleWifi,
          onSubmenu: _openWifiSubmenu,
        ),

      // Bluetooth (bluetoothctl)
      if (_hasBluetoothctl)
        _FeaturePod(
          icon: _bluetoothEnabled
              ? Symbols.bluetooth_rounded
              : Symbols.bluetooth_disabled_rounded,
          title: 'Bluetooth',
          subtitle: _bluetoothEnabled ? 'On' : 'Off',
          isActive: _bluetoothEnabled,
          hasSubmenu: true,
          onToggle: () => _toggleBluetooth(),
          onSubmenu: _openBluetoothSubmenu,
        ),

      // Screen capture (GNOME-style toolbar with Selection/Screen/Window)
      if (_hasGrim)
        _FeaturePod(
          icon: Symbols.screenshot_monitor_rounded,
          title: 'Screen capture',
          isActive: false,
          onToggle: () {
            if (widget.onOpenCapture != null) {
              widget.onClose();
              widget.onOpenCapture!();
            }
          },
        ),

      // Do not disturb (dunst/swaync)
      if (_dndTool != null)
        _FeaturePod(
          icon: _dndEnabled
              ? Symbols.do_not_disturb_on_rounded
              : Symbols.notifications_rounded,
          title: 'Do not disturb',
          subtitle: _dndEnabled ? 'On' : 'Off',
          isActive: _dndEnabled,
          onToggle: _toggleDnd,
        ),

      // Night light (gammastep or wlsunset)
      if (_hasGammastep || _hasWlsunset)
        _FeaturePod(
          icon: _nightLightEnabled
              ? Symbols.nightlight_rounded
              : Symbols.light_mode_rounded,
          title: 'Night Light',
          subtitle: _nightLightEnabled ? 'On' : 'Off',
          isActive: _nightLightEnabled,
          onToggle: () => _toggleNightLight(),
        ),

      // Dark theme (internal theme service)
      _FeaturePod(
        icon: isDark
            ? Symbols.dark_mode_rounded
            : Symbols.light_mode_rounded,
        title: 'Dark theme',
        subtitle: isDark ? 'On' : 'Off',
        isActive: isDark,
        onToggle: () => setState(() => themeService.toggleTheme()),
      ),

      // Airplane mode (nmcli radio all)
      if (_hasNmcli)
        _FeaturePod(
          icon: _airplaneModeEnabled
              ? Symbols.airplanemode_active_rounded
              : Symbols.airplanemode_inactive_rounded,
          title: 'Airplane mode',
          subtitle: _airplaneModeEnabled ? 'On' : 'Off',
          isActive: _airplaneModeEnabled,
          onToggle: _toggleAirplaneMode,
        ),
    ];

    // 3 columns per row, ChromeOS style. The last row pads empty slots so
    // icon widths stay identical across the grid.
    const cols = 3;
    final rows = <List<Widget>>[];
    for (var i = 0; i < pods.length; i += cols) {
      final end = i + cols < pods.length ? i + cols : pods.length;
      rows.add(pods.sublist(i, end));
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 6),
                Expanded(
                  child: c < rows[r].length ? rows[r][c] : const SizedBox(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWifiSubmenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('wifi_submenu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Submenu Header
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Symbols.arrow_back_rounded,
                fill: 1,
                weight: 300,
                grade: 0,
              ),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _currentView = QuickSettingsView.main),
            ),
            const SizedBox(width: 6),
            Text(
              'Wi-Fi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (_isScanningWifi)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(
                  Symbols.refresh_rounded,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                ),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: _scanWifi,
                tooltip: 'Scan for networks',
              ),
            Switch(
              value: _wifiEnabled,
              onChanged: (val) {
                setState(() => _wifiEnabled = val);
                NetworkService().setWifiEnabled(val);
                if (val) _scanWifi();
              },
            ),
          ],
        ),

        const SizedBox(height: 8),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 8),

        // Available Networks List
        if (!_wifiEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Wi-Fi is turned off',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (_wifiNetworks.isEmpty && !_isScanningWifi)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No networks found',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _wifiNetworks.length,
              itemBuilder: (context, index) {
                final net = _wifiNetworks[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    net.isSecured
                        ? Symbols.wifi_lock_rounded
                        : Symbols.wifi_rounded,
                    size: 20,
                    fill: 1,
                    weight: 300,
                    grade: 0,
                    color: net.isConnected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    net.ssid,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: net.isConnected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: net.isConnected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  trailing: net.isConnected
                      ? Icon(
                          Symbols.check_rounded,
                          size: 18,
                          fill: 1,
                          weight: 300,
                          grade: 0,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    if (net.isConnected) return;
                    await NetworkService().connect(net.ssid);
                    _scanWifi();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBluetoothSubmenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('bluetooth_submenu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Symbols.arrow_back_rounded,
                fill: 1,
                weight: 300,
                grade: 0,
              ),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _currentView = QuickSettingsView.main),
            ),
            const SizedBox(width: 6),
            Text(
              'Bluetooth',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Symbols.refresh_rounded,
                fill: 1,
                weight: 300,
                grade: 0,
              ),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: _loadBluetoothDevices,
              tooltip: 'Refresh devices',
            ),
            Switch(
              value: _bluetoothEnabled,
              onChanged: (val) => _toggleBluetooth(val),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 8),

        // Paired devices list
        if (!_bluetoothEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Bluetooth is turned off',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (_isLoadingBluetooth)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_bluetoothDevices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No Bluetooth devices paired',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final device in _bluetoothDevices)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Symbols.bluetooth_audio_rounded,
                    size: 20,
                    fill: 1,
                    weight: 300,
                    grade: 0,
                    color: device.isConnected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: device.isConnected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: device.isConnected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${device.isConnected ? 'Connected' : 'Disconnected'} · ${device.mac}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: device.isConnected
                      ? Icon(
                          Symbols.check_rounded,
                          size: 18,
                          fill: 1,
                          weight: 300,
                          grade: 0,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () => _toggleBluetoothDevice(device),
                ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// ChromeOS Circular Action Button (Top bar)
class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.onSurface.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 18,
              fill: 1,
              weight: 300,
              grade: 0,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// ChromeOS Feature Pod (Circle icon + centered title/subtitle + chevron)
class _FeaturePod extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isActive;
  final bool hasSubmenu;
  final VoidCallback onToggle;
  final VoidCallback? onSubmenu;

  const _FeaturePod({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isActive,
    this.hasSubmenu = false,
    required this.onToggle,
    this.onSubmenu,
  });

  @override
  State<_FeaturePod> createState() => _FeaturePodState();
}

class _FeaturePodState extends State<_FeaturePod> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle Icon Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? colorScheme.primary
                      : (_isHovered
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surfaceContainer),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isActive
                        ? Colors.transparent
                        : colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: 20,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                  color: widget.isActive
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              // Title with Dropdown Chevron
              GestureDetector(
                onTap: widget.hasSubmenu ? widget.onSubmenu : widget.onToggle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (widget.hasSubmenu)
                      Icon(
                        Symbols.arrow_drop_down_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),

              // Subtitle / Status
              if (widget.subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}