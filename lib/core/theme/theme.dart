import 'package:flutter/material.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  ThemeMode get themeMode => themeModeNotifier.value;
  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  void toggleTheme() {
    themeModeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }
}

class AmeliaTheme {
  static const double shelfHeight = 56.0;
  static const double shelfPadding = 6.0;
  static const double shelfIconSize = 26.0;

  // Signature ChromeOS / Material You Google Blue seeds
  static const Color seedColor = Color(0xFF8AB4F8);

  static ThemeData darkTheme() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      primary: const Color(0xFF8AB4F8),
      onPrimary: const Color(0xFF041E49),
      primaryContainer: const Color(0xFF1E3A5F),
      onPrimaryContainer: const Color(0xFFD3E3FD),
      surface: const Color(0xFF1B1B1F),
      surfaceContainer: const Color(0xFF222428),
      surfaceContainerHigh: const Color(0xFF2A2B30),
      surfaceContainerHighest: const Color(0xFF35373D),
      outlineVariant: const Color(0xFF44474E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      iconTheme: const IconThemeData(
        fill: 1.0,
        weight: 300.0,
        grade: 0.0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'Roboto',
        ),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  static ThemeData lightTheme() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      iconTheme: const IconThemeData(
        fill: 1.0,
        weight: 300.0,
        grade: 0.0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: baseScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: baseScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        textStyle: TextStyle(
          color: baseScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'Roboto',
        ),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
