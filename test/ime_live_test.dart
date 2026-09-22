import 'package:flutter_test/flutter_test.dart';
import 'package:amelia_shell/core/services/input_method_service.dart';

void main() {
  test('Live Fcitx5 detection and toggle test', () async {
    final service = InputMethodService();
    await service.start();

    final initialState = service.currentState;
    expect(initialState.isAvailable, isTrue);

    // Toggle
    await service.toggle();
    final toggledState = service.currentState;
    expect(toggledState.currentEngineId, isNot(equals(initialState.currentEngineId)));

    // Toggle back to restore
    await service.toggle();
    final restoredState = service.currentState;
    expect(restoredState.currentEngineId, equals(initialState.currentEngineId));

    service.stop();
  });
}

