import 'package:flutter_test/flutter_test.dart';
import 'package:amelia_shell/core/services/input_method_service.dart';

void main() {
  group('InputMethodService - deriveShortLabel', () {
    test('returns EN when inactive regardless of engine', () {
      expect(
        deriveShortLabel(engineId: 'lotus', isActive: false, languageCode: 'vi'),
        'EN',
      );
      expect(
        deriveShortLabel(engineId: 'mozc', isActive: false, languageCode: 'ja'),
        'EN',
      );
      expect(
        deriveShortLabel(engineId: 'keyboard-us', isActive: false),
        'EN',
      );
    });

    test('derives VI for Vietnamese engines when active', () {
      expect(
        deriveShortLabel(engineId: 'lotus', isActive: true, languageCode: 'vi'),
        'VI',
      );
      expect(
        deriveShortLabel(engineId: 'fcitx-bamboo', isActive: true),
        'VI',
      );
      expect(
        deriveShortLabel(engineId: 'unikey', isActive: true),
        'VI',
      );
    });

    test('derives JA, ZH, KO for East Asian engines when active', () {
      expect(
        deriveShortLabel(engineId: 'mozc', isActive: true, languageCode: 'ja'),
        'JA',
      );
      expect(
        deriveShortLabel(engineId: 'pinyin', isActive: true, languageCode: 'zh_CN'),
        'ZH',
      );
      expect(
        deriveShortLabel(engineId: 'hangul', isActive: true, languageCode: 'ko'),
        'KO',
      );
    });

    test('derives country/lang code for keyboard layouts', () {
      expect(
        deriveShortLabel(engineId: 'keyboard-us', isActive: true),
        'EN',
      );
      expect(
        deriveShortLabel(engineId: 'keyboard-fr', isActive: true),
        'FR',
      );
      expect(
        deriveShortLabel(engineId: 'keyboard-de', isActive: true),
        'DE',
      );
    });
  });

  group('InputMethodState', () {
    test('default state is unavailable and inactive', () {
      const state = InputMethodState();
      expect(state.isAvailable, false);
      expect(state.isActive, false);
      expect(state.shortLabel, 'EN');
      expect(state.availableEngines, isEmpty);
    });

    test('copyWith updates fields correctly', () {
      const state = InputMethodState();
      final updated = state.copyWith(
        isAvailable: true,
        isActive: true,
        currentEngineId: 'lotus',
        currentEngineName: 'Lotus',
        shortLabel: 'VI',
        availableEngines: const [
          InputMethodEngine(id: 'lotus', name: 'Lotus', shortLabel: 'VI'),
          InputMethodEngine(id: 'keyboard-us', name: 'English (US)', shortLabel: 'EN'),
        ],
      );

      expect(updated.isAvailable, true);
      expect(updated.isActive, true);
      expect(updated.currentEngineId, 'lotus');
      expect(updated.currentEngineName, 'Lotus');
      expect(updated.shortLabel, 'VI');
      expect(updated.availableEngines.length, 2);
    });
  });
}

