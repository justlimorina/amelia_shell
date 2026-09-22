import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/input_method_service.dart';

class InputMethodPanel extends StatelessWidget {
  final VoidCallback onClose;

  const InputMethodPanel({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imeService = InputMethodService();

    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ValueListenableBuilder<InputMethodState>(
        valueListenable: imeService.stateNotifier,
        builder: (context, state, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'Input Methods',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Available Engines
              ...state.availableEngines.map((engine) {
                final isCurrent = engine.id == state.currentEngineId;
                return _EngineTile(
                  engine: engine,
                  isCurrent: isCurrent,
                  onTap: () {
                    imeService.switchEngine(engine.id);
                    onClose();
                  },
                );
              }),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),

              // Other languages
              _ActionTile(
                icon: Symbols.language_rounded,
                label: 'Other input methods / languages',
                onTap: () {
                  imeService.openSettings();
                  onClose();
                },
              ),

              // Settings
              _ActionTile(
                icon: Symbols.settings_rounded,
                label: 'Input method settings',
                onTap: () {
                  imeService.openSettings();
                  onClose();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EngineTile extends StatefulWidget {
  final InputMethodEngine engine;
  final bool isCurrent;
  final VoidCallback onTap;

  const _EngineTile({
    required this.engine,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_EngineTile> createState() => _EngineTileState();
}

class _EngineTileState extends State<_EngineTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isCurrent
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
                : (_isHovered
                    ? colorScheme.onSurface.withValues(alpha: 0.08)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isCurrent
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.engine.shortLabel,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isCurrent
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.engine.name,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight:
                        widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: widget.isCurrent
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isCurrent)
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
        ),
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                weight: 300,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
