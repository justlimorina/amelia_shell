import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../status_tray/status_tray_pill.dart';
import 'shelf_app_button.dart';
import 'shelf_app_item.dart';

class ShelfWidget extends StatefulWidget {
  final bool isLauncherOpen;
  final bool isQuickSettingsOpen;
  final VoidCallback onToggleLauncher;
  final VoidCallback onToggleQuickSettings;

  const ShelfWidget({
    super.key,
    required this.isLauncherOpen,
    required this.isQuickSettingsOpen,
    required this.onToggleLauncher,
    required this.onToggleQuickSettings,
  });

  @override
  State<ShelfWidget> createState() => _ShelfWidgetState();
}

class _ShelfWidgetState extends State<ShelfWidget> {
  final List<ShelfAppItem> _pinnedApps = ShelfAppItem.defaultPinnedApps();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AmeliaTheme.shelfHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AmeliaTheme.shelfBackgroundDark,
        border: const Border(
          top: BorderSide(
            color: AmeliaTheme.shelfBorderDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. ChromeOS Circular Launcher Button (Start)
          _LauncherButton(
            isOpen: widget.isLauncherOpen,
            onTap: widget.onToggleLauncher,
          ),

          const SizedBox(width: 12),

          // Vertical divider line (ChromeOS style)
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withValues(alpha: 0.1),
          ),

          const SizedBox(width: 8),

          // 2. Pinned Apps (Center)
          Expanded(
            child: Row(
              children: _pinnedApps
                  .map((app) => ShelfAppButton(item: app))
                  .toList(),
            ),
          ),

          // 3. Status Tray Pill (End)
          StatusTrayPill(
            isOpen: widget.isQuickSettingsOpen,
            onTap: widget.onToggleQuickSettings,
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
                      ? colorScheme.onSurface.withValues(alpha: 0.15)
                      : Colors.transparent),
              shape: BoxShape.circle,
            ),
            child: Center(
              // ChromeOS iconic concentric circle launcher icon
              child: Container(
                width: 18,
                height: 18,
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
