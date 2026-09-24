import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/osd_service.dart';

/// Floating Material Design 3 On-Screen Display (OSD) capsule
/// displayed when volume or brightness is adjusted.
class OsdOverlay extends StatelessWidget {
  final OsdData data;

  const OsdOverlay({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final IconData icon = switch (data.type) {
      OsdType.volume => data.isMuted || data.value == 0.0
          ? Symbols.volume_off_rounded
          : data.value < 0.5
              ? Symbols.volume_down_rounded
              : Symbols.volume_up_rounded,
      OsdType.brightness => data.value < 0.5
          ? Symbols.brightness_low_rounded
          : Symbols.brightness_medium_rounded,
    };

    final String percentText = data.isMuted && data.type == OsdType.volume
        ? 'Muted'
        : '${(data.value * 100).round()}%';

    return Container(
      width: 280,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: data.isMuted ? 0.0 : data.value,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              percentText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
