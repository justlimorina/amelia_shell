import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum OsdType { volume, brightness }

class OsdData {
  final OsdType type;
  final double value; // 0.0 to 1.0
  final bool isMuted;

  const OsdData({
    required this.type,
    required this.value,
    this.isMuted = false,
  });
}

/// Service managing on-screen display (OSD) feedback for volume and brightness.
class OsdService {
  static final OsdService _instance = OsdService._internal();
  factory OsdService() => _instance;
  OsdService._internal();

  final ValueNotifier<OsdData?> currentOsd = ValueNotifier(null);
  Timer? _dismissTimer;

  double _volume = 0.75;
  bool _isMuted = false;
  double _brightness = 0.8;

  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get brightness => _brightness;

  void start() {
    _readCurrentVolume();
    _readCurrentBrightness();
  }

  Future<void> _readCurrentVolume() async {
    try {
      final r = await Process.run('wpctl', ['get-volume', '@DEFAULT_AUDIO_SINK@']);
      if (r.exitCode == 0) {
        final out = r.stdout.toString().trim(); // e.g., "Volume: 0.75 [MUTED]"
        final parts = out.split(' ');
        if (parts.length >= 2) {
          final val = double.tryParse(parts[1]);
          if (val != null) _volume = val.clamp(0.0, 1.0);
        }
        _isMuted = out.contains('[MUTED]');
      }
    } catch (_) {}
  }

  Future<void> _readCurrentBrightness() async {
    try {
      final curR = await Process.run('brightnessctl', ['g']);
      final maxR = await Process.run('brightnessctl', ['m']);
      if (curR.exitCode == 0 && maxR.exitCode == 0) {
        final cur = double.tryParse(curR.stdout.toString().trim());
        final max = double.tryParse(maxR.stdout.toString().trim());
        if (cur != null && max != null && max > 0) {
          _brightness = (cur / max).clamp(0.05, 1.0);
        }
      }
    } catch (_) {}
  }

  void _triggerOsd(OsdData data) {
    currentOsd.value = data;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 1800), () {
      currentOsd.value = null;
    });
  }

  Future<void> adjustVolume(double delta) async {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    _isMuted = false;
    _triggerOsd(OsdData(type: OsdType.volume, value: _volume, isMuted: _isMuted));

    try {
      await Process.run('wpctl', [
        'set-volume',
        '@DEFAULT_AUDIO_SINK@',
        '${(_volume * 100).toInt()}%',
      ]);
      await Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', '0']);
    } catch (_) {}
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    _isMuted = _volume == 0.0;
    _triggerOsd(OsdData(type: OsdType.volume, value: _volume, isMuted: _isMuted));

    try {
      await Process.run('wpctl', [
        'set-volume',
        '@DEFAULT_AUDIO_SINK@',
        '${(_volume * 100).toInt()}%',
      ]);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    _triggerOsd(OsdData(type: OsdType.volume, value: _volume, isMuted: _isMuted));

    try {
      await Process.run('wpctl', [
        'set-mute',
        '@DEFAULT_AUDIO_SINK@',
        _isMuted ? '1' : '0',
      ]);
    } catch (_) {}
  }

  void showVolumeOsd() {
    _triggerOsd(OsdData(type: OsdType.volume, value: _volume, isMuted: _isMuted));
  }

  Future<void> adjustBrightness(double delta) async {
    _brightness = (_brightness + delta).clamp(0.05, 1.0);
    _triggerOsd(OsdData(type: OsdType.brightness, value: _brightness));

    try {
      await Process.run('brightnessctl', [
        's',
        '${(_brightness * 100).toInt()}%',
      ]);
    } catch (_) {}
  }

  Future<void> setBrightness(double val) async {
    _brightness = val.clamp(0.05, 1.0);
    _triggerOsd(OsdData(type: OsdType.brightness, value: _brightness));

    try {
      await Process.run('brightnessctl', [
        's',
        '${(_brightness * 100).toInt()}%',
      ]);
    } catch (_) {}
  }

  void showBrightnessOsd() {
    _triggerOsd(OsdData(type: OsdType.brightness, value: _brightness));
  }

  void dismissNow() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    currentOsd.value = null;
  }
}
