import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/system_service.dart';

class StatusTrayPill extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const StatusTrayPill({
    super.key,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<StatusTrayPill> createState() => _StatusTrayPillState();
}

class _StatusTrayPillState extends State<StatusTrayPill> {
  bool _isHovered = false;
  final _timeFormat = DateFormat('HH:mm');

  IconData _getBatteryIcon(BatteryInfo battery) {
    if (battery.isCharging) return Symbols.battery_charging_full_rounded;
    if (battery.percentage >= 85) return Symbols.battery_full_rounded;
    if (battery.percentage >= 50) return Symbols.battery_5_bar_rounded;
    if (battery.percentage >= 20) return Symbols.battery_3_bar_rounded;
    return Symbols.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final systemService = SystemService();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.isOpen
                ? colorScheme.primaryContainer
                : (_isHovered
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: widget.isOpen
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: StreamBuilder<DateTime>(
            stream: systemService.timeStream,
            initialData: DateTime.now(),
            builder: (context, timeSnapshot) {
              final currentTime = timeSnapshot.data ?? DateTime.now();
              final timeString = _timeFormat.format(currentTime);

              return StreamBuilder<BatteryInfo>(
                stream: systemService.batteryStream,
                initialData: systemService.currentBattery,
                builder: (context, batterySnapshot) {
                  final battery =
                      batterySnapshot.data ?? systemService.currentBattery;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Network Icon
                      Icon(
                        Symbols.wifi_rounded,
                        size: 18,
                        fill: 1,
                        weight: 300,
                        grade: 0,
                        color: widget.isOpen
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),

                      // Audio Icon
                      Icon(
                        Symbols.volume_up_rounded,
                        size: 18,
                        fill: 1,
                        weight: 300,
                        grade: 0,
                        color: widget.isOpen
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),

                      // Battery Icon
                      if (battery.isPresent) ...[
                        Icon(
                          _getBatteryIcon(battery),
                          size: 18,
                          fill: 1,
                          weight: 300,
                          grade: 0,
                          color: widget.isOpen
                              ? colorScheme.onPrimaryContainer
                              : (battery.percentage <= 20 && !battery.isCharging
                                  ? colorScheme.error
                                  : colorScheme.onSurface),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Clock Text
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto',
                          color: widget.isOpen
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
