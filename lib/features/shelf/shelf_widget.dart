import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../status_tray/date_pill.dart';
import '../status_tray/status_tray_pill.dart';
import 'shelf_app_button.dart';
import 'shelf_app_item.dart';

class ShelfWidget extends StatefulWidget {
  final bool isLauncherOpen;
  final bool isCalendarOpen;
  final bool isQuickSettingsOpen;
  final VoidCallback onToggleLauncher;
  final VoidCallback onToggleCalendar;
  final VoidCallback onToggleQuickSettings;

  const ShelfWidget({
    super.key,
    required this.isLauncherOpen,
    required this.isCalendarOpen,
    required this.isQuickSettingsOpen,
    required this.onToggleLauncher,
    required this.onToggleCalendar,
    required this.onToggleQuickSettings,
  });

  @override
  State<ShelfWidget> createState() => _ShelfWidgetState();
}

class _ShelfWidgetState extends State<ShelfWidget> {
  final List<ShelfAppItem> _pinnedApps = ShelfAppItem.defaultPinnedApps();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: AmeliaTheme.shelfHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Left (Start Edge): ChromeOS Launcher Button
          Positioned(
            left: 12,
            child: _LauncherButton(
              isOpen: widget.isLauncherOpen,
              onTap: widget.onToggleLauncher,
            ),
          ),

          // 2. Center (True Monitor Center): Pinned & Running Apps
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _pinnedApps
                  .map((app) => ShelfAppButton(item: app))
                  .toList(),
            ),
          ),

          // 3. Right (End Edge): Date Pill & Status Tray Pill
          Positioned(
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DatePill(
                  isOpen: widget.isCalendarOpen,
                  onTap: widget.onToggleCalendar,
                ),
                const SizedBox(width: 8),
                StatusTrayPill(
                  isOpen: widget.isQuickSettingsOpen,
                  onTap: widget.onToggleQuickSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _LauncherButton({
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<_LauncherButton> createState() => _LauncherButtonState();
}

class _LauncherButtonState extends State<_LauncherButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Launcher',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isOpen
                  ? colorScheme.primaryContainer
                  : (_isHovered
                      ? colorScheme.onSurface.withValues(alpha: 0.1)
                      : Colors.transparent),
              shape: BoxShape.circle,
            ),
            child: Center(
              // ChromeOS iconic concentric circle launcher icon
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isOpen
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    width: 2.2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isOpen
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
