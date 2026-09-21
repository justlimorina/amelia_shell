import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/system_service.dart';

class DatePill extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const DatePill({
    super.key,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<DatePill> createState() => _DatePillState();
}

class _DatePillState extends State<DatePill> {
  bool _isHovered = false;
  final _dateFormat = DateFormat('EEE, MMM d');

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
                  : colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: StreamBuilder<DateTime>(
            stream: systemService.timeStream,
            initialData: DateTime.now(),
            builder: (context, snapshot) {
              final currentTime = snapshot.data ?? DateTime.now();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.calendar_today_rounded,
                    size: 16,
                    fill: 1,
                    weight: 300,
                    grade: 0,
                    color: widget.isOpen
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateFormat.format(currentTime),
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
          ),
        ),
      ),
    );
  }
}
