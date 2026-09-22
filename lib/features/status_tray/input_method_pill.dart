import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/input_method_service.dart';

class InputMethodPill extends StatefulWidget {
  const InputMethodPill({super.key});

  @override
  State<InputMethodPill> createState() => _InputMethodPillState();
}

class _InputMethodPillState extends State<InputMethodPill> {
  bool _isHovered = false;
  final InputMethodService _imeService = InputMethodService();

  void _showEngineMenu(BuildContext context, InputMethodState state, Offset position) {
    if (state.availableEngines.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final List<PopupMenuEntry<String>> items = state.availableEngines.map<PopupMenuEntry<String>>((engine) {
      final isCurrent = engine.id == state.currentEngineId;
      return PopupMenuItem<String>(
        value: engine.id,
        height: 40,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCurrent
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                engine.shortLabel,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                engine.name,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
            if (isCurrent)
              Icon(
                Symbols.check_rounded,
                size: 18,
                fill: 1,
                weight: 300,
                grade: 0,
                color: colorScheme.primary,
              ),
          ],
        ),
      );
    }).toList();

    items.add(const PopupMenuDivider());

    items.add(
      PopupMenuItem<String>(
        value: 'other_languages',
        height: 40,
        child: Row(
          children: [
            Icon(
              Symbols.language_rounded,
              size: 18,
              fill: 1,
              weight: 300,
              grade: 0,
              color: colorScheme.onSurface,
            ),
            const SizedBox(width: 10),
            Text(
              'Other input methods/languages',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    items.add(
      PopupMenuItem<String>(
        value: 'settings',
        height: 40,
        child: Row(
          children: [
            Icon(
              Symbols.settings_rounded,
              size: 18,
              fill: 1,
              weight: 300,
              grade: 0,
              color: colorScheme.onSurface,
            ),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          position,
          position,
        ),
        Offset.zero & overlay.size,
      ),
      items: items,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      color: colorScheme.surfaceContainerHigh,
      elevation: 6,
    ).then((selectedId) {
      if (selectedId != null) {
        if (selectedId == 'settings' || selectedId == 'other_languages') {
          _imeService.openSettings();
        } else {
          _imeService.switchEngine(selectedId);
        }
      }
    });
  }

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
            'Input Method: ${state.currentEngineName.isNotEmpty ? state.currentEngineName : label} (${isActive ? "Active" : "Inactive"})\nClick to toggle, right-click to switch engine';

        return Tooltip(
          message: tooltipMessage,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _imeService.toggle(),
              onSecondaryTapDown: (details) =>
                  _showEngineMenu(context, state, details.globalPosition),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: isActive
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.keyboard_rounded,
                      size: 16,
                      fill: 1,
                      weight: 300,
                      grade: 0,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
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

