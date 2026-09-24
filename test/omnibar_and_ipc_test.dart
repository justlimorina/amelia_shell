import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amelia_shell/core/services/ipc_service.dart';
import 'package:amelia_shell/core/services/osd_service.dart';
import 'package:amelia_shell/core/services/session_service.dart';
import 'package:amelia_shell/core/theme/theme.dart';
import 'package:amelia_shell/core/utils/calculator_evaluator.dart';
import 'package:amelia_shell/features/osd/osd_overlay.dart';

void main() {
  group('CalculatorEvaluator (Omnibar)', () {
    test('evaluates basic arithmetic expressions', () {
      expect(CalculatorEvaluator.tryEvaluate('25 * 4')?.formattedResult, '100');
      expect(CalculatorEvaluator.tryEvaluate('1280 / 4')?.formattedResult, '320');
      expect(CalculatorEvaluator.tryEvaluate('15 + 5 * 2')?.formattedResult, '25');
      expect(CalculatorEvaluator.tryEvaluate('(10 + 20) / 2')?.formattedResult, '15');
      expect(CalculatorEvaluator.tryEvaluate('2 ^ 8')?.formattedResult, '256');
      expect(CalculatorEvaluator.tryEvaluate('100 % 3')?.formattedResult, '1');
      expect(CalculatorEvaluator.tryEvaluate('=50 + 50')?.formattedResult, '100');
      expect(CalculatorEvaluator.tryEvaluate('1000 * 1000')?.formattedResult, '1,000,000');
    });

    test('safely rejects non-math queries', () {
      expect(CalculatorEvaluator.tryEvaluate('google-chrome'), isNull);
      expect(CalculatorEvaluator.tryEvaluate('gcc -o output'), isNull);
      expect(CalculatorEvaluator.tryEvaluate('v2.10.4'), isNull);
      expect(CalculatorEvaluator.tryEvaluate('123'), isNull); // single number with no operator
      expect(CalculatorEvaluator.tryEvaluate(''), isNull);
    });

    test('gracefully handles division by zero', () {
      expect(CalculatorEvaluator.tryEvaluate('10 / 0'), isNull);
      expect(CalculatorEvaluator.tryEvaluate('5 % 0'), isNull);
    });
  });

  group('SessionService (Omnibar)', () {
    test('searches session actions by keywords', () {
      final lockResults = SessionService.search('lock');
      expect(lockResults.any((a) => a.type == SessionActionType.lock), isTrue);

      final rebootResults = SessionService.search('reboot');
      expect(rebootResults.any((a) => a.type == SessionActionType.reboot), isTrue);

      final shutdownResults = SessionService.search('shutdown');
      expect(shutdownResults.any((a) => a.type == SessionActionType.powerOff), isTrue);

      final sleepResults = SessionService.search('sleep');
      expect(sleepResults.any((a) => a.type == SessionActionType.suspend), isTrue);

      final logoutResults = SessionService.search('logout');
      expect(logoutResults.any((a) => a.type == SessionActionType.logout), isTrue);
    });
  });

  group('IpcService Command Dispatch', () {
    test('processes commands and emits corresponding actions', () async {
      final ipc = IpcService();
      final actions = <IpcAction>[];
      final sub = ipc.actionStream.listen(actions.add);

      expect(await ipc.processCommand('ping'), equals('pong'));
      expect(await ipc.processCommand('toggle-launcher'), contains('OK: toggle-launcher'));
      expect(await ipc.processCommand('toggle-quick-settings'), contains('OK: toggle-quick-settings'));
      expect(await ipc.processCommand('toggle-calendar'), contains('OK: toggle-calendar'));
      expect(await ipc.processCommand('capture'), contains('OK: capture-toolbar'));
      expect(await ipc.processCommand('volume-up'), contains('OK: volume-up'));
      expect(await ipc.processCommand('brightness-up'), contains('OK: brightness-up'));
      expect(await ipc.processCommand('close-all'), contains('OK: close-all'));

      expect(actions, contains(IpcAction.toggleLauncher));
      expect(actions, contains(IpcAction.toggleQuickSettings));
      expect(actions, contains(IpcAction.toggleCalendar));
      expect(actions, contains(IpcAction.openCapture));
      expect(actions, contains(IpcAction.volumeUp));
      expect(actions, contains(IpcAction.brightnessUp));
      expect(actions, contains(IpcAction.closeAll));

      await sub.cancel();
    });
  });

  group('OsdOverlay Widget', () {
    testWidgets('renders volume OSD correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AmeliaTheme.darkTheme(),
          home: const Scaffold(
            body: Center(
              child: OsdOverlay(
                data: OsdData(
                  type: OsdType.volume,
                  value: 0.75,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders muted volume OSD correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AmeliaTheme.darkTheme(),
          home: const Scaffold(
            body: Center(
              child: OsdOverlay(
                data: OsdData(
                  type: OsdType.volume,
                  value: 0.75,
                  isMuted: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Muted'), findsOneWidget);
    });

    testWidgets('renders brightness OSD correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AmeliaTheme.darkTheme(),
          home: const Scaffold(
            body: Center(
              child: OsdOverlay(
                data: OsdData(
                  type: OsdType.brightness,
                  value: 0.60,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('60%'), findsOneWidget);
    });
  });
}
