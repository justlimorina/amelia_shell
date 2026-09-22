import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/input_method_service.dart';

class InputMethodPill extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const InputMethodPill({
    super.key,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<InputMethodPill> createState() => _InputMethodPillState();
}

class _InputMethodPillState extends State<InputMethodPill> {
  bool _isHovered = false;
  final InputMethodService _imeService = InputMethodService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<InputMethodState>(
      valueListenable: _imeService.stateNotifier,
      builder: (context, state, child) {
        if (!state.isAvailable) {
          return const SizedBox.shrink();
        }

        final isActive = state.isActive;
        final label = state.shortLabel;
        final tooltipMessage =
            'Input Method: ${state.currentEngineName.isNotEmpty ? state.currentEngineName : label} (${isActive ? "Active" : "Inactive"})\nClick to open menu, right-click to toggle';

        return Tooltip(
          message: tooltipMessage,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              onSecondaryTap: () => _imeService.toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        : (isActive
                            ? colorScheme.primary.withValues(alpha: 0.3)
                            : colorScheme.outlineVariant.withValues(alpha: 0.35)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.keyboard_rounded,
                      size: 18,
                      fill: 1,
                      weight: 300,
                      grade: 0,
                      color: widget.isOpen
                          ? colorScheme.onPrimaryContainer
                          : (isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isOpen
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.15)
                            : (isActive
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.isOpen
                              ? colorScheme.onPrimaryContainer
                              : (isActive
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
