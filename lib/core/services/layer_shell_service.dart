import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to interact with the native Linux GTK Layer Shell embedding.
class LayerShellService {
  static const MethodChannel _channel =
      MethodChannel('com.amelia.shell/layer_shell');

  static bool _isLayerSupported = false;
  static bool get isLayerSupported => _isLayerSupported;

  /// Check if the current compositor supports Wayland Layer Shell protocol.
  static Future<bool> checkLayerSupport() async {
    try {
      final bool? supported =
          await _channel.invokeMethod<bool>('isLayerSupported');
      _isLayerSupported = supported ?? false;
      return _isLayerSupported;
    } catch (e) {
      debugPrint('LayerShellService.checkLayerSupport error: $e');
      _isLayerSupported = false;
      return false;
    }
  }

  /// Dynamically resize the shell window height.
  /// Used to expand the window when Launcher or Quick Settings popup opens,
  /// and collapse it back to shelf height (e.g. 56px) when closed.
  static Future<void> setHeight(int height) async {
    try {
      await _channel.invokeMethod('setHeight', height);
    } catch (e) {
      debugPrint('LayerShellService.setHeight error: $e');
    }
  }

  /// Configure the exclusive zone reserved on the screen edge (in pixels).
  /// This informs labwc not to cover this area when windows are maximized.
  static Future<void> setExclusiveZone(int zone) async {
    try {
      await _channel.invokeMethod('setExclusiveZone', zone);
    } catch (e) {
      debugPrint('LayerShellService.setExclusiveZone error: $e');
    }
  }

  /// Enable or disable keyboard interactivity on demand (for search inputs).
  static Future<void> setKeyboardMode(bool enable) async {
    try {
      await _channel.invokeMethod('setKeyboardMode', enable);
    } catch (e) {
      debugPrint('LayerShellService.setKeyboardMode error: $e');
    }
  }
}

