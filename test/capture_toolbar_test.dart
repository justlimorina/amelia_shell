import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amelia_shell/core/services/screen_capture_service.dart';
import 'package:amelia_shell/core/theme/theme.dart';
import 'package:amelia_shell/features/screen_capture/capture_toolbar.dart';

class FakeScreenCaptureService implements ScreenCaptureService {
  final CaptureResult result;
  FakeScreenCaptureService(this.result);

  @override
  Future<CaptureResult> captureFull() async => result;

  @override
  Future<CaptureResult> captureRegion() async => result;

  @override
  Future<CaptureResult> captureFocusedWindow() async => result;

  @override
  Future<bool> copyToClipboard(String path) async => true;
}

void main() {
  testWidgets('CaptureToolbar shows the three GNOME modes and cancels',
      (WidgetTester tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(
              onClose: () => closed = true,
              enableNotifications: false,
            ),
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
    final fakeService = FakeScreenCaptureService(
      const CaptureResult.ok('/fake/path.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(
              onClose: () => closed = true,
              service: fakeService,
              enableNotifications: false,
            ),
          ),
        ),
      ),
    );

    // Pick Selection, then take.
    await tester.tap(find.text('Selection'));
    await tester.pump();
    await tester.tap(find.byTooltip('Take screenshot'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('CaptureToolbar reports the result via onCaptureFinished (success)',
      (WidgetTester tester) async {
    var closed = false;
    String? message;
    bool? isError;
    final fakeService = FakeScreenCaptureService(
      const CaptureResult.ok('/home/user/Pictures/Screenshots/Screenshot from 2026-09-24.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(
              onClose: () => closed = true,
              service: fakeService,
              enableNotifications: false,
              onCaptureFinished: (m, e) {
                message = m;
                isError = e;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Take screenshot'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(message, equals('Saved: Screenshot from 2026-09-24.png'));
    expect(isError, isFalse);
  });

  testWidgets('CaptureToolbar reports the result via onCaptureFinished (failure)',
      (WidgetTester tester) async {
    var closed = false;
    String? message;
    bool? isError;
    final fakeService = FakeScreenCaptureService(
      const CaptureResult.fail('grim failed'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AmeliaTheme.darkTheme(),
        home: Scaffold(
          body: Center(
            child: CaptureToolbar(
              onClose: () => closed = true,
              service: fakeService,
              enableNotifications: false,
              onCaptureFinished: (m, e) {
                message = m;
                isError = e;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Take screenshot'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(message, equals('grim failed'));
    expect(isError, isTrue);
  });
}