import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class CalendarPanel extends StatefulWidget {
  final VoidCallback onClose;

  const CalendarPanel({super.key, required this.onClose});

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_today.year, _today.month, 1);
    _selectedDate = _today;
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _selectedMonth = DateTime(_today.year, _today.month, 1);
      _selectedDate = _today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthFormat = DateFormat('MMMM yyyy');
    final fullDateFormat = DateFormat('EEEE, d MMMM yyyy');

    // Calendar matrix calculation (Monday-first)
    final firstDayOfMonth = _selectedMonth;
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday;
    final prevMonthDays =
        DateTime(_selectedMonth.year, _selectedMonth.month, 0).day;

    final List<Widget> dayWidgets = [];

    // Days of week headers
    const daysOfWeek = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    for (final day in daysOfWeek) {
      dayWidgets.add(
        Center(
          child: Text(
            day,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    // Leading days from previous month
    for (int i = startingWeekday - 2; i >= 0; i--) {
      final day = prevMonthDays - i;
      dayWidgets.add(
        Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Roboto',
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        ),
      );
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate =
          DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final isToday = currentDate.year == _today.year &&
          currentDate.month == _today.month &&
          currentDate.day == _today.day;
      final isSelected = currentDate.year == _selectedDate.year &&
          currentDate.month == _selectedDate.month &&
          currentDate.day == _selectedDate.day;

      dayWidgets.add(
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedDate = currentDate),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isToday
                    ? colorScheme.primary
                    : (isSelected
                        ? colorScheme.primaryContainer
                        : Colors.transparent),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  fontFamily: 'Roboto',
                  color: isToday
                      ? colorScheme.onPrimary
                      : (isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header & Navigation
          Row(
            children: [
              Text(
                monthFormat.format(_selectedMonth),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Today Button
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _goToToday,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Symbols.chevron_left_rounded,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                ),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: _prevMonth,
              ),
              IconButton(
                icon: const Icon(
                  Symbols.chevron_right_rounded,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                ),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: _nextMonth,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Calendar Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 4,
            children: dayWidgets,
          ),

          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),

          // Selected Date Info Card
          Row(
            children: [
              Icon(
                Symbols.event_note_rounded,
                size: 20,
                fill: 1,
                weight: 300,
                grade: 0,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fullDateFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
