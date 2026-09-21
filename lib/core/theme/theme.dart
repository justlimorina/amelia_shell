import 'package:flutter/material.dart';

class AmeliaTheme {
  static const double shelfHeight = 56.0;
  static const double shelfPadding = 6.0;
  static const double shelfIconSize = 26.0;

  // ChromeOS style frosted surface background
  static const Color shelfBackgroundDark = Color(0xCC1E1F22);
  static const Color shelfBackgroundLight = Color(0xCCF2F3F5);

  static const Color shelfBorderDark = Color(0x33FFFFFF);
  static const Color shelfBorderLight = Color(0x22000000);

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8), // ChromeOS signature blue
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1F22),
        onSurface: Colors.white,
      ),
      fontFamily: 'Roboto',
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xEE2B2D30),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0x22FFFFFF), width: 1),
          ),
        ),
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: Duration(milliseconds: 300),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8),
        brightness: Brightness.light,
        surface: const Color(0xFFF2F3F5),
        onSurface: Colors.black87,
      ),
      fontFamily: 'Roboto',
    );
  }
}

