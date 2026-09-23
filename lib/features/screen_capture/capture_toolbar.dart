import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/screen_capture_service.dart';

enum CaptureMode { selection, screen, window }

/// GNOME-style floating screenshot toolbar with three capture modes:
/// Selection, Screen and Window.
class CaptureToolbar extends StatefulWidget {
  final VoidCallback onClose;

  const CaptureToolbar({super.key, required this.onClose});

  @override
  State<CaptureToolbar> createState() => _CaptureToolbarState();
}

class _CaptureToolbarState extends State<CaptureToolbar> {
  CaptureMode _mode = CaptureMode.screen;
  final ScreenCaptureService _service = ScreenCaptureService();

  Future<void> _run(String cmd, List<String> args) async {
    try {
      await Process.run(cmd, args);
    } catch (_) {
      // not installed - ignore
    }
  }

  Future<void> _take() async {
    switch (_mode) {
      case CaptureMode.selection:
      case CaptureMode.window:
        // Hide the toolbar (and shrink the layer surface) so slurp/grim can
        // see the real desktop, then capture.
        widget.onClose();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final path = _mode == CaptureMode.selection
            ? await _service.captureRegion()
            : await _service.captureFocusedWindow();
        await _notify(path);
      case CaptureMode.screen:
        final path = await _service.captureFull();
        await _notify(path);
        widget.onClose();
    }
  }

  Future<void> _notify(String? path) async {
    if (path == null) return;
    await _run('notify-send', ['Screenshot saved', path]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Symbols.crop_rounded,
            label: 'Selection',
            selected: _mode == CaptureMode.selection,
            onTap: () => setState(() => _mode = CaptureMode.selection),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            icon: Symbols.monitor_rounded,
            label: 'Screen',
            selected: _mode == CaptureMode.screen,
            onTap: () => setState(() => _mode = CaptureMode.screen),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            icon: Symbols.window_rounded,
            label: 'Window',
            selected: _mode == CaptureMode.window,
            onTap: () => setState(() => _mode = CaptureMode.window),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 32,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          _ToolbarCircleButton(
            icon: Symbols.photo_camera_rounded,
            tooltip: 'Take screenshot',
            color: colorScheme.primary,
            iconColor: colorScheme.onPrimary,
            onTap: _take,
          ),
          const SizedBox(width: 6),
          _ToolbarCircleButton(
            icon: Symbols.close_rounded,
            tooltip: 'Cancel',
            color: Colors.transparent,
            iconColor: colorScheme.onSurface,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = widget.selected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? colorScheme.primary
                : (_isHovered
                    ? colorScheme.surfaceContainerHighest
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                fill: 1,
                weight: 300,
                grade: 0,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarCircleButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ToolbarCircleButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_ToolbarCircleButton> createState() => _ToolbarCircleButtonState();
}

class _ToolbarCircleButtonState extends State<_ToolbarCircleButton> {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: _isHovered && widget.color == Colors.transparent
                  ? Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1))
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 18,
              fill: 1,
              weight: 300,
              grade: 0,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}