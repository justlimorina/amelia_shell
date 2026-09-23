import 'dart:convert';
import 'dart:io';

/// Backend-agnostic screen capture backed by grim/slurp.
///
/// Mode mapping (GNOME-like):
///  - Screen:   `grim` (whole compositor)
///  - Selection:`slurp` for geometry, then `grim -g <geometry>`
///  - Window:   resolves the focused window geometry via hyprctl/swaymsg,
///              then `grim -g <geometry>`. If no compositor IPC is available
///              (e.g. labwc), gracefully falls back to region selection.
class ScreenCaptureService {
  static final ScreenCaptureService _instance = ScreenCaptureService._internal();
  factory ScreenCaptureService() => _instance;
  ScreenCaptureService._internal();

  Future<ProcessResult?> _run(String cmd, List<String> args) async {
    try {
      return await Process.run(cmd, args);
    } catch (_) {
      return null;
    }
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}_${two(now.month)}_${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _newPath() {
    final home = Platform.environment['HOME'] ?? '.';
    final xdgPictures = Platform.environment['XDG_PICTURES_DIR'];
    final dir = Directory(
        (xdgPictures != null && xdgPictures.isNotEmpty)
            ? xdgPictures
            : '$home/Pictures');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return '${dir.path}/Screenshot_${_stamp()}.png';
  }

  /// Capture the whole compositor. Returns the saved path, or null on failure.
  Future<String?> captureFull() async {
    final path = _newPath();
    final r = await _run('grim', [path]);
    return (r != null && r.exitCode == 0) ? path : null;
  }

  /// Let the user drag a region; capture it. Returns the saved path or null.
  Future<String?> captureRegion() async {
    final geo = await _run('slurp', []);
    if (geo == null || geo.exitCode != 0) return null; // cancelled
    final geometry = geo.stdout.toString().trim();
    if (geometry.isEmpty) return null;

    final path = _newPath();
    final r = await _run('grim', ['-g', geometry, path]);
    return (r != null && r.exitCode == 0) ? path : null;
  }

  /// Capture the focused window. Falls back to region selection when the
  /// compositor exposes no window geometry (labwc/sway-family limitation).
  Future<String?> captureFocusedWindow() async {
    final geometry = await _focusedWindowGeometry();
    if (geometry == null) return captureRegion();

    final path = _newPath();
    final r = await _run('grim', ['-g', geometry, path]);
    return (r != null && r.exitCode == 0) ? path : null;
  }

  /// Resolve "x,y WxH" for the focused window, or null when unsupported.
  Future<String?> _focusedWindowGeometry() async {
    // Hyprland
    final hypr = await _run('hyprctl', ['-j', 'activewindow']);
    if (hypr != null && hypr.exitCode == 0) {
      try {
        final json = jsonDecode(hypr.stdout.toString());
        if (json is Map && json['at'] is List && json['size'] is List) {
          final at = json['at'] as List;
          final size = json['size'] as List;
          if (at.length >= 2 && size.length >= 2) {
            return '${at[0]},${at[1]} ${size[0]}x${size[1]}';
          }
        }
      } catch (_) {
        // fall through to the next backend
      }
    }

    // Sway
    final sway = await _run('swaymsg', ['-t', 'get_tree', '-r']);
    if (sway != null && sway.exitCode == 0) {
      try {
        final root = jsonDecode(sway.stdout.toString());
        final focused = _findFocusedNode(root);
        if (focused != null && focused['rect'] is Map) {
          final rect = focused['rect'] as Map;
          final x = rect['x'], y = rect['y'];
          final w = rect['width'], h = rect['height'];
          if (x is num && y is num && w is num && h is num) {
            return '${x.toInt()},${y.toInt()} ${w.toInt()}x${h.toInt()}';
          }
        }
      } catch (_) {
        // no geometry available
      }
    }

    return null;
  }

  dynamic _findFocusedNode(dynamic node) {
    if (node is Map && node['focused'] == true) return node;
    if (node is Map) {
      for (final key in ['nodes', 'floating_nodes']) {
        final children = node[key];
        if (children is List) {
          for (final child in children) {
            final result = _findFocusedNode(child);
            if (result != null) return result;
          }
        }
      }
    }
    return null;
  }
}