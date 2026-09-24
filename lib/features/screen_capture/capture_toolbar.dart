import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/screen_capture_service.dart';

enum CaptureMode { selection, screen, window }

/// GNOME-style floating screenshot toolbar with three capture modes:
/// Selection, Screen and Window.
class CaptureToolbar extends StatefulWidget {
  final VoidCallback onClose;

  /// Status text rendered in the toolbar (e.g. "Saved: ..." or an error),
  /// set by the parent when it re-opens the toolbar after a capture attempt.
  final String? initialStatus;
  final bool initialStatusIsError;

  /// Called after a capture attempt with the result, so the parent can
  /// re-open the toolbar to show the outcome (it is closed during capture).
  final void Function(String message, bool isError)? onCaptureFinished;

  /// Optional injected capture service (defaults to [ScreenCaptureService]).
  final ScreenCaptureService? service;

  /// Whether to fire system notifications via notify-send.
  final bool enableNotifications;

  const CaptureToolbar({
    super.key,
    required this.onClose,
    this.initialStatus,
    this.initialStatusIsError = false,
    this.onCaptureFinished,
    this.service,
    this.enableNotifications = true,
  });

  @override
  State<CaptureToolbar> createState() => _CaptureToolbarState();
}

class _CaptureToolbarState extends State<CaptureToolbar> {
  CaptureMode _mode = CaptureMode.screen;
  bool _busy = false;
  ScreenCaptureService get _service => widget.service ?? ScreenCaptureService();

  Future<void> _notifySaved(String path) async {
    if (!widget.enableNotifications) return;
    try {
      final fileName = path.split('/').last;
      await Process.run('notify-send', [
        '-a',
        'Amelia Shell',
        '-i',
        path,
        'Screenshot saved',
        'Saved to $fileName (copied to clipboard)',
      ]).catchError((_) => ProcessResult(0, 0, '', ''));
    } catch (_) {
      // no notification daemon / notify-send - best effort
    }
  }

  Future<void> _notifyFailed(String err) async {
    if (!widget.enableNotifications) return;
    try {
      await Process.run('notify-send', [
        'Screenshot failed',
        err,
      ]).catchError((_) => ProcessResult(0, 0, '', ''));
    } catch (_) {}
  }

  Future<void> _take() async {
    if (_busy) return;
    _busy = true;

    // Hide toolbar so it is not visible in the screenshot and pointer grab is released
    widget.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final CaptureResult result = switch (_mode) {
      CaptureMode.screen => await _service.captureFull(),
      CaptureMode.selection => await _service.captureRegion(),
      CaptureMode.window => await _service.captureFocusedWindow(),
    };

    final path = result.path;
    if (path != null) {
      await _notifySaved(path);
      widget.onCaptureFinished?.call('Saved: ${path.split('/').last}', false);
    } else {
      final err = result.error ?? 'Capture failed';
      if (!err.toLowerCase().contains('cancel')) {
        await _notifyFailed(err);
      }
      widget.onCaptureFinished?.call(err, true);
    }
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
          // Result / error status shown when the parent re-opens the
          // toolbar after a capture attempt.
          if (widget.initialStatus != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                widget.initialStatus!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: widget.initialStatusIsError
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
                      ? FontWeight.w500
                      : FontWeight.w400,
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