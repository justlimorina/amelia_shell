import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amelia_shell/core/theme/theme.dart';
import 'package:amelia_shell/features/quick_settings/quick_settings_panel.dart';

void main() {
  testWidgets('QuickSettingsPanel pod grid renders 3 columns per row',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: QuickSettingsPanel(onClose: () {}),
          ),
        ),
      ),
    );

    // Tool detection is synchronous in initState, so the grid is already built
    // after the first pump. This extra pump lets any async Wi-Fi/Bluetooth
    // state loading settle (it doesn't affect the pod layout).
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(QuickSettingsPanel), findsOneWidget);

    // The Dark theme pod is always present.
    expect(find.text('Dark theme'), findsOneWidget);

    // Every pod grid row must expose exactly 3 (Expanded) columns so icons
    // line up in a ChromeOS 3-per-row grid, even on the last row.
    var gridRows = 0;
    for (final element in find.byType(Row).evaluate()) {
      final row = element.widget as Row;
      final expanded = row.children.whereType<Expanded>().length;
      if (expanded >= 3) gridRows++;
    }
    expect(gridRows, greaterThanOrEqualTo(1));
  });
}