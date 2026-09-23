import 'dart:io';

/// Service to resolve Linux freedesktop icon names to actual file paths on disk.
/// Prioritizes the installed Papirus icon theme (high fidelity SVGs) with fallback to hicolor and pixmaps.
class IconThemeService {
  static final IconThemeService _instance = IconThemeService._internal();
  factory IconThemeService() => _instance;
  IconThemeService._internal();

  final Map<String, String?> _cache = {};

  static const List<String> _searchDirs = [
    '/usr/share/icons/Papirus/48x48/apps',
    '/usr/share/icons/Papirus/64x64/apps',
    '/usr/share/icons/Papirus/32x32/apps',
    '/usr/share/icons/Papirus/scalable/apps',
    '/usr/share/icons/Papirus-Dark/48x48/apps',
    '/usr/share/icons/hicolor/48x48/apps',
    '/usr/share/icons/hicolor/scalable/apps',
    '/usr/share/icons/hicolor/32x32/apps',
    '/usr/share/icons/hicolor/64x64/apps',
    '/usr/share/pixmaps',
  ];

  /// Find the absolute file path for a given icon name.
  String? findIcon(String iconName) {
    final cleanName = iconName.trim();
    if (cleanName.isEmpty) return null;

    if (_cache.containsKey(cleanName)) {
      return _cache[cleanName];
    }

    // 1. Direct path check
    if (cleanName.startsWith('/')) {
      final file = File(cleanName);
      if (file.existsSync()) {
        _cache[cleanName] = cleanName;
        return cleanName;
      }
    }

    // Strip known extensions if provided in .desktop file (e.g. icon.png -> icon)
    String baseName = cleanName;
    if (baseName.endsWith('.png') ||
        baseName.endsWith('.svg') ||
        baseName.endsWith('.xpm')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    final extensions = ['.svg', '.png', '.xpm'];
    final candidateNames = [
      baseName,
      baseName.toLowerCase(),
      ..._getAliases(baseName.toLowerCase()),
    ];

    for (final dir in _searchDirs) {
      for (final name in candidateNames) {
        for (final ext in extensions) {
          final path = '$dir/$name$ext';
          if (File(path).existsSync()) {
            _cache[cleanName] = path;
            return path;
          }
        }
      }
    }

    // Fallback search in user local directory
    final home = Platform.environment['HOME'];
    if (home != null) {
      final userDirs = [
        '$home/.local/share/icons/Papirus/48x48/apps',
        '$home/.local/share/icons/hicolor/48x48/apps',
        '$home/.local/share/icons',
      ];
      for (final dir in userDirs) {
        for (final name in candidateNames) {
          for (final ext in extensions) {
            final path = '$dir/$name$ext';
            if (File(path).existsSync()) {
              _cache[cleanName] = path;
              return path;
            }
          }
        }
      }
    }

    _cache[cleanName] = null;
    return null;
  }

  List<String> _getAliases(String name) {
    switch (name) {
      case 'chrome':
      case 'google-chrome':
        return ['google-chrome', 'chromium-browser', 'chromium'];
      case 'terminal':
      case 'foot':
      case 'ptyxis':
      case 'org.gnome.terminal':
        return [
          'utilities-terminal',
          'org.gnome.Terminal',
          'terminal',
          'org.gnome.Ptyxis',
          'foot',
          'alacritty',
        ];
      case 'files':
      case 'nautilus':
      case 'org.gnome.nautilus':
        return [
          'system-file-manager',
          'org.gnome.Nautilus',
          'nautilus',
          'thunar',
        ];
      case 'code':
      case 'vscode':
      case 'visual-studio-code':
        return ['com.visualstudio.code', 'vscode', 'code'];
      case 'settings':
      case 'gnome-control-center':
        return [
          'preferences-system',
          'org.gnome.Settings',
          'gnome-control-center',
        ];
      case 'text-editor':
      case 'gedit':
        return [
          'accessories-text-editor',
          'org.gnome.TextEditor',
          'gedit',
        ];
      default:
        return [];
    }
  }
}

