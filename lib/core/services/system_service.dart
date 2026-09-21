import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BatteryInfo {
  final int percentage;
  final bool isCharging;
  final bool isPresent;

  const BatteryInfo({
    required this.percentage,
    required this.isCharging,
    required this.isPresent,
  });
}

class SystemService {
  static final SystemService _instance = SystemService._internal();
  factory SystemService() => _instance;
  SystemService._internal();

  final _timeController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get timeStream => _timeController.stream;

  final _batteryController = StreamController<BatteryInfo>.broadcast();
  Stream<BatteryInfo> get batteryStream => _batteryController.stream;

  Timer? _timer;
  BatteryInfo _currentBattery = const BatteryInfo(
    percentage: 100,
    isCharging: false,
    isPresent: true,
  );
  BatteryInfo get currentBattery => _currentBattery;

  void start() {
    _updateTime();
    _updateBattery();

    // Periodic ticker every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateTime();
      _updateBattery();
    });
  }

  void _updateTime() {
    _timeController.add(DateTime.now());
  }

  void _updateBattery() {
    try {
      final capFile = File('/sys/class/power_supply/BAT0/capacity');
      final statFile = File('/sys/class/power_supply/BAT0/status');

      if (capFile.existsSync()) {
        final capacityStr = capFile.readAsStringSync().trim();
        final statusStr = statFile.existsSync() ? statFile.readAsStringSync().trim() : '';

        final percentage = int.tryParse(capacityStr) ?? 100;
        final isCharging = statusStr.toLowerCase().contains('charging') ||
            statusStr.toLowerCase().contains('full');

        _currentBattery = BatteryInfo(
          percentage: percentage,
          isCharging: isCharging,
          isPresent: true,
        );
        _batteryController.add(_currentBattery);
      } else {
        _currentBattery = const BatteryInfo(
          percentage: 100,
          isCharging: true,
          isPresent: false,
        );
        _batteryController.add(_currentBattery);
      }
    } catch (e) {
      debugPrint('Error reading battery: $e');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

