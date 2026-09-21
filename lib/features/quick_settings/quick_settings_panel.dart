import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/network_service.dart';
import '../../core/services/system_service.dart';
import '../media_player/media_player_card.dart';

enum QuickSettingsView { main, wifi, bluetooth }

class QuickSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const QuickSettingsPanel({super.key, required this.onClose});

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  QuickSettingsView _currentView = QuickSettingsView.main;

  bool _wifiEnabled = true;
  bool _bluetoothEnabled = true;
  bool _dndEnabled = false;
  bool _nightLightEnabled = false;
  bool _darkMode = true;

  double _volume = 0.75;
  double _brightness = 0.8;

  List<WifiNetwork> _wifiNetworks = [];
  bool _isScanningWifi = false;

  @override
  void initState() {
    super.initState();
    _checkWifiState();
  }

  Future<void> _checkWifiState() async {
    final enabled = await NetworkService().isWifiEnabled();
    if (mounted) {
      setState(() => _wifiEnabled = enabled);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 540),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
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
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Column(
      key: const ValueKey('main_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: Date & Control Buttons
        Row(
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            _HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: () {
                Process.run('gnome-control-center', []);
                widget.onClose();
              },
            ),
            const SizedBox(width: 6),
            _HeaderIconButton(
              icon: Icons.lock_outline_rounded,
              tooltip: 'Lock Screen',
              onTap: () {
                Process.run('loginctl', ['lock-session']);
                widget.onClose();
              },
            ),
            const SizedBox(width: 6),
            _HeaderIconButton(
              icon: Icons.power_settings_new_rounded,
              tooltip: 'Power Menu',
              color: colorScheme.error,
              onTap: () {
                Process.run('wlogout', []).catchError((_) {
                  return Process.run('systemctl', ['poweroff']);
                });
                widget.onClose();
              },
            ),
          ],
        ),

        const SizedBox(height: 14),

        // MPRIS Media Player Card (Auto-hides if no media)
        const MediaPlayerCard(),

        // Quick Settings Pill Grid (2 columns)
        Row(
          children: [
            Expanded(
              child: _QuickTogglePill(
                icon: _wifiEnabled
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                label: _wifiEnabled ? 'Wi-Fi' : 'Off',
                isActive: _wifiEnabled,
                onToggle: () {
                  final next = !_wifiEnabled;
                  setState(() => _wifiEnabled = next);
                  NetworkService().setWifiEnabled(next);
                },
                onExpand: _openWifiSubmenu,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTogglePill(
                icon: _bluetoothEnabled
                    ? Icons.bluetooth_rounded
                    : Icons.bluetooth_disabled_rounded,
                label: _bluetoothEnabled ? 'Bluetooth' : 'Off',
                isActive: _bluetoothEnabled,
                onToggle: () =>
                    setState(() => _bluetoothEnabled = !_bluetoothEnabled),
                onExpand: _openBluetoothSubmenu,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTogglePill(
                icon: _dndEnabled
                    ? Icons.do_not_disturb_on_rounded
                    : Icons.do_not_disturb_off_rounded,
                label: 'Do not disturb',
                isActive: _dndEnabled,
                onToggle: () => setState(() => _dndEnabled = !_dndEnabled),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTogglePill(
                icon: Icons.nightlight_round,
                label: 'Night Light',
                isActive: _nightLightEnabled,
                onToggle: () =>
                    setState(() => _nightLightEnabled = !_nightLightEnabled),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTogglePill(
                icon: _darkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                label: _darkMode ? 'Dark theme' : 'Light theme',
                isActive: _darkMode,
                onToggle: () => setState(() => _darkMode = !_darkMode),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTogglePill(
                icon: Icons.cast_rounded,
                label: 'Cast',
                isActive: false,
                onToggle: () {},
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Sliders: Volume
        Row(
          children: [
            Icon(
              _volume > 0
                  ? Icons.volume_up_rounded
                  : Icons.volume_mute_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _volume,
                  onChanged: (val) {
                    setState(() => _volume = val);
                    Process.run('wpctl', [
                      'set-volume',
                      '@DEFAULT_AUDIO_SINK@',
                      '${(val * 100).toInt()}%'
                    ]);
                  },
                ),
              ),
            ),
          ],
        ),

        // Sliders: Brightness
        Row(
          children: [
            Icon(
              Icons.brightness_medium_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _brightness,
                  onChanged: (val) {
                    setState(() => _brightness = val);
                    Process.run(
                        'brightnessctl', ['s', '${(val * 100).toInt()}%']);
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0x22FFFFFF)),
        const SizedBox(height: 10),

        // Battery Info Footer
        StreamBuilder<BatteryInfo>(
          stream: systemService.batteryStream,
          initialData: systemService.currentBattery,
          builder: (context, snapshot) {
            final battery = snapshot.data ?? systemService.currentBattery;
            return Row(
              children: [
                Icon(
                  battery.isCharging
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_std_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${battery.percentage}%'
                  '${battery.isCharging ? ' • Charging' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
              icon: const Icon(Icons.arrow_back_rounded),
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
                icon: const Icon(Icons.refresh_rounded),
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
        const Divider(height: 1, color: Color(0x22FFFFFF)),
        const SizedBox(height: 8),

        // Available Networks List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _wifiNetworks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _isScanningWifi
                          ? 'Searching for networks...'
                          : 'No Wi-Fi networks found',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _wifiNetworks.length,
                  itemBuilder: (context, index) {
                    final net = _wifiNetworks[index];
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        net.isConnected
                            ? Icons.wifi_rounded
                            : (net.signal > 60
                                ? Icons.wifi_rounded
                                : (net.signal > 30
                                    ? Icons.network_wifi_2_bar_rounded
                                    : Icons.network_wifi_1_bar_rounded)),
                        color: net.isConnected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        size: 20,
                      ),
                      title: Text(
                        net.ssid,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: net.isConnected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: net.isConnected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      subtitle: net.isConnected
                          ? Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (net.isSecured)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            '${net.signal}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!net.isConnected) {
                          NetworkService().connect(net.ssid);
                          _scanWifi();
                        }
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
              icon: const Icon(Icons.arrow_back_rounded),
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
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Switch(
              value: _bluetoothEnabled,
              onChanged: (val) {
                setState(() => _bluetoothEnabled = val);
                Process.run('bluetoothctl', ['power', val ? 'on' : 'off']);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0x22FFFFFF)),
        const SizedBox(height: 16),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _bluetoothEnabled
                  ? 'Manage devices in Settings'
                  : 'Bluetooth is turned off',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 17,
              color: color ?? colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTogglePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onToggle;
  final VoidCallback? onExpand;

  const _QuickTogglePill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onToggle,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Main toggle clickable area
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: onExpand != null
                    ? const BorderRadius.horizontal(left: Radius.circular(18))
                    : BorderRadius.circular(18),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 19,
                        color: isActive
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Submenu Expand arrow button
          if (onExpand != null) ...[
            Container(
              width: 1,
              height: 24,
              color: isActive
                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(18)),
                onTap: onExpand,
                child: Container(
                  width: 34,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
