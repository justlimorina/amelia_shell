import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amelia_shell/core/theme/theme.dart';
import 'package:amelia_shell/features/screen_capture/capture_toolbar.dart';

void main() {
  testWidgets('CaptureToolbar shows the three GNOME modes and cancels',
      (WidgetTester tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(onClose: () => closed = true),
          ),
        ),
      ),
    );

    // GNOME-style mode buttons.
    expect(find.text('Selection'), findsOneWidget);
    expect(find.text('Screen'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.byTooltip('Take screenshot'), findsOneWidget);

    // Cancel button dismisses the toolbar.
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('CaptureToolbar Selection mode closes before capturing',
      (WidgetTester tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(onClose: () => closed = true),
          ),
        ),
      ),
    );

    // Pick Selection, then take. Even with slurp/grim missing the toolbar
    // must close first and must not crash.
    await tester.tap(find.text('Selection'));
    await tester.pump();
    await tester.tap(find.byTooltip('Take screenshot'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(closed, isTrue);
  });
}