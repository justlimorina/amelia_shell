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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 630,
      height: 480,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ==================== LEFT: Notification Center ====================
          Expanded(
            child: _buildNotificationCenter(context),
          ),

          // ==================== Vertical Divider ====================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),

          // ==================== RIGHT: Calendar & Agenda ====================
          SizedBox(
            width: 290,
            child: _buildCalendarSection(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCenter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Symbols.notifications_rounded,
          size: 56,
          fill: 1,
          weight: 300,
          grade: 0,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'No Notifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final weekdayName = DateFormat('EEEE').format(_today);
    final fullDateName = DateFormat('MMMM d yyyy').format(_today);
    final monthName = DateFormat('MMMM').format(_selectedMonth);

    // Calendar matrix calculation (Sunday-first, matching GNOME layout)
    final firstDayOfMonth = _selectedMonth;
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final prevMonthDays =
        DateTime(_selectedMonth.year, _selectedMonth.month, 0).day;

    // Sunday = 7 in Dart DateTime weekday, convert to Sunday = 0
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final List<Widget> dayWidgets = [];

    // Weekday headers: S, M, T, W, T, F, S
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (final day in weekdays) {
      dayWidgets.add(
        Center(
          child: Text(
            day,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    // Leading days from previous month
    for (int i = startingWeekday - 1; i >= 0; i--) {
      final day = prevMonthDays - i;
      dayWidgets.add(
        Center(
          child: Text(
            day < 10 ? '0$day' : '$day',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Roboto',
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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

      final dayStr = day < 10 ? '0$day' : '$day';

      dayWidgets.add(
        InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => setState(() => _selectedDate = currentDate),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
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
                dayStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w500
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

    // Trailing days from next month
    final totalCells = dayWidgets.length - 7;
    final remainingCells = (7 - (totalCells % 7)) % 7;
    for (int day = 1; day <= remainingCells; day++) {
      final dayStr = day < 10 ? '0$day' : '$day';
      dayWidgets.add(
        Center(
          child: Text(
            dayStr,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Roboto',
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header: Weekday & Full Date
        Text(
          weekdayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            fontFamily: 'Roboto',
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          fullDateName,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        // Month Selector: < Month >
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            GestureDetector(
              onTap: _goToToday,
              child: Text(
                monthName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurface,
                ),
              ),
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

        const SizedBox(height: 6),

        // Calendar Grid
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: dayWidgets,
          ),
        ),

        const SizedBox(height: 6),

        // Today / Agenda Card (GNOME style layout in MD3 container)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'No Events',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // World Clocks Action Button (MD3 tonal style)
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Add World Clocks...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
