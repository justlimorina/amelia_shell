import 'dart:convert';
import 'dart:io';

/// Outcome of a capture attempt: either [path] or a user-readable [error].
class CaptureResult {
  final String? path;
  final String? error;

  const CaptureResult.ok(this.path) : error = null;
  const CaptureResult.fail(this.error) : path = null;
}

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

  /// Run a command without ever throwing - spawn failures (missing binary,
  /// no PATH) come back as an exit-127 result so callers can show a real
  /// error message instead of failing silently.
  Future<ProcessResult> _run(String cmd, List<String> args) async {
    try {
      return await Process.run(cmd, args);
    } on ProcessException catch (e) {
      return ProcessResult(-1, 127, '', '$cmd: ${e.message}');
    } catch (e) {
      return ProcessResult(-1, 1, '', '$cmd: $e');
    }
  }

  String _failure(String cmd, ProcessResult r) {
    final err = r.stderr.toString().trim();
    if (err.isNotEmpty) return err;
    if (r.exitCode == 127) return '$cmd is not installed';
    return '$cmd failed (exit ${r.exitCode})';
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }

  /// Absolute path for a new screenshot file, or null when no candidate
  /// directory is writable. Never throws.
  String? _newPathOrNull() {
    try {
      final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
      String? pictures = Platform.environment['XDG_PICTURES_DIR'];
      if (pictures != null && pictures.isNotEmpty) {
        pictures = pictures.replaceAll('\$HOME', home).replaceAll('~', home);
      }
      final candidates = <String>[
        if (pictures != null && pictures.isNotEmpty) '$pictures/Screenshots',
        if (pictures != null && pictures.isNotEmpty) pictures,
        '$home/Pictures/Screenshots',
        '$home/Pictures',
        home,
        Directory.systemTemp.path,
      ];
      for (final base in candidates) {
        try {
          final dir = Directory(base);
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return '${dir.path}/Screenshot from ${_stamp()}.png';
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Capture the whole compositor.
  Future<CaptureResult> captureFull() async {
    final path = _newPathOrNull();
    if (path == null) {
      return const CaptureResult.fail('Cannot write to Pictures folder');
    }
    final r = await _run('grim', [path]);
    if (r.exitCode == 0) return CaptureResult.ok(path);
    return CaptureResult.fail(_failure('grim', r));
  }

  /// Let the user drag a region; capture it.
  Future<CaptureResult> captureRegion() async {
    final geo = await _run('slurp', [
      '-d',
      '-b', '#00000055',
      '-c', '#8AB4F8',
      '-s', '#8AB4F822',
      '-w', '2',
    ]);
    if (geo.exitCode != 0) {
      if (geo.exitCode == 127) {
        return const CaptureResult.fail('slurp is not installed');
      }
      return const CaptureResult.fail('Selection cancelled');
    }
    final geometry = geo.stdout.toString().trim();
    if (geometry.isEmpty) {
      return const CaptureResult.fail('Selection cancelled');
    }

    final path = _newPathOrNull();
    if (path == null) {
      return const CaptureResult.fail('Cannot write to Pictures folder');
    }
    final r = await _run('grim', ['-g', geometry, path]);
    if (r.exitCode == 0) return CaptureResult.ok(path);
    return CaptureResult.fail(_failure('grim', r));
  }

  /// Capture a window. Prompts the user to click a window if compositor
  /// geometries are available (Hyprland / Sway), otherwise falls back to
  /// interactive region selection.
  Future<CaptureResult> captureFocusedWindow() async {
    final boxes = await _getWindowGeometries();
    if (boxes.isNotEmpty) {
      try {
        final process = await Process.start('slurp', [
          '-r',
          '-b', '#00000055',
          '-c', '#8AB4F8',
          '-s', '#8AB4F822',
          '-B', '#8AB4F833',
          '-w', '2',
        ]);
        process.stdin.writeln(boxes.join('\n'));
        await process.stdin.close();

        final outFuture = process.stdout.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        final geometry = (await outFuture).trim();
        if (exitCode == 0 && geometry.isNotEmpty) {
          final path = _newPathOrNull();
          if (path == null) {
            return const CaptureResult.fail('Cannot write to Pictures folder');
          }
          final r = await _run('grim', ['-g', geometry, path]);
          if (r.exitCode == 0) return CaptureResult.ok(path);
          return CaptureResult.fail(_failure('grim', r));
        } else {
          return const CaptureResult.fail('Selection cancelled');
        }
      } catch (_) {
        // Fall back to interactive capture
      }
    }

    // Fallback: interactive capture for window/region
    return captureRegion();
  }

  /// Collect window geometries across supported compositors.
  Future<List<String>> _getWindowGeometries() async {
    final geometries = <String>[];

    // Hyprland
    final hypr = await _run('hyprctl', ['clients', '-j']);
    if (hypr.exitCode == 0) {
      try {
        final list = jsonDecode(hypr.stdout.toString());
        if (list is List) {
          for (final item in list) {
            if (item is Map &&
                item['mapped'] == true &&
                item['hidden'] != true &&
                item['at'] is List &&
                item['size'] is List) {
              final at = item['at'] as List;
              final size = item['size'] as List;
              if (at.length >= 2 && size.length >= 2) {
                geometries.add('${at[0]},${at[1]} ${size[0]}x${size[1]}');
              }
            }
          }
        }
      } catch (_) {}
    }

    if (geometries.isNotEmpty) return geometries;

    // Sway
    final sway = await _run('swaymsg', ['-t', 'get_tree', '-r']);
    if (sway.exitCode == 0) {
      try {
        final root = jsonDecode(sway.stdout.toString());
        _collectSwayWindowGeometries(root, geometries);
      } catch (_) {}
    }

    return geometries;
  }

  void _collectSwayWindowGeometries(dynamic node, List<String> out) {
    if (node is! Map) return;
    if (node['pid'] != null &&
        node['visible'] == true &&
        node['rect'] is Map) {
      final rect = node['rect'] as Map;
      final x = rect['x'], y = rect['y'], w = rect['width'], h = rect['height'];
      if (x is num && y is num && w is num && h is num && w > 0 && h > 0) {
        out.add('${x.toInt()},${y.toInt()} ${w.toInt()}x${h.toInt()}');
      }
    }
    for (final key in ['nodes', 'floating_nodes']) {
      final children = node[key];
      if (children is List) {
        for (final child in children) {
          _collectSwayWindowGeometries(child, out);
        }
      }
    }
  }
}
