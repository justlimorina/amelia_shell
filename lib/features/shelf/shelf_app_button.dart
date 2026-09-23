import 'package:flutter/material.dart';
import 'app_icon_widget.dart';
import 'shelf_app_item.dart';

class ShelfAppButton extends StatefulWidget {
  final ShelfAppItem item;
  final VoidCallback? onTap;

  const ShelfAppButton({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<ShelfAppButton> createState() => _ShelfAppButtonState();
}

class _ShelfAppButtonState extends State<ShelfAppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: widget.item.name,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap!();
            } else {
              widget.item.launch();
            }
          },
          child: AnimatedScale(
            scale: _isHovered ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: _isHovered
                    ? colorScheme.onSurface.withValues(alpha: 0.08)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Authentic desktop icon (Papirus / hicolor / pixmaps)
                  AppIconWidget(
                    iconName: widget.item.iconName,
                    appName: widget.item.name,
                    size: 28,
                  ),

                  // Running indicator dot (ChromeOS style)
                  if (widget.item.isRunning)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
