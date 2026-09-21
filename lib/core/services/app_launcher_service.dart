import 'dart:io';
import 'package:flutter/material.dart';

class DesktopAppInfo {
  final String name;
  final String exec;
  final String iconName;
  final String? comment;

  DesktopAppInfo({
    required this.name,
    required this.exec,
    required this.iconName,
    this.comment,
  });

  Future<void> launch() async {
    try {
      // Strip out desktop action placeholders like %U, %u, %F, %f
      var cleanExec = exec.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
      final parts = cleanExec.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        await Process.start(parts[0], parts.sublist(1),
            mode: ProcessStartMode.detached);
      }
    } catch (e) {
      debugPrint('Error launching $name: $e');
    }
  }

  IconData getFallbackIcon() {
    final lowerName = name.toLowerCase();
    final lowerExec = exec.toLowerCase();

    if (lowerName.contains('chrome') ||
        lowerName.contains('firefox') ||
        lowerName.contains('browser')) {
      return Icons.language_rounded;
    }
    if (lowerName.contains('terminal') ||
        lowerExec.contains('ptyxis') ||
        lowerExec.contains('foot')) {
      return Icons.terminal_rounded;
    }
    if (lowerName.contains('file') || lowerExec.contains('nautilus')) {
      return Icons.folder_rounded;
    }
    if (lowerName.contains('code') ||
        lowerName.contains('dev') ||
        lowerExec.contains('code')) {
      return Icons.code_rounded;
    }
    if (lowerName.contains('discord') ||
        lowerName.contains('chat') ||
        lowerName.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lowerName.contains('setting') || lowerName.contains('control')) {
      return Icons.settings_rounded;
    }
    if (lowerName.contains('music') ||
        lowerName.contains('audio') ||
        lowerName.contains('sound')) {
      return Icons.music_note_rounded;
    }
    if (lowerName.contains('video') || lowerName.contains('player')) {
      return Icons.play_circle_fill_rounded;
    }
    if (lowerName.contains('text') || lowerName.contains('edit')) {
      return Icons.edit_note_rounded;
    }
    if (lowerName.contains('calc')) {
      return Icons.calculate_rounded;
    }

    return Icons.apps_rounded;
  }

  Color getIconColor() {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('chrome')) return const Color(0xFF4285F4);
    if (lowerName.contains('terminal') || lowerName.contains('ptyxis')) {
      return const Color(0xFF34A853);
    }
    if (lowerName.contains('code')) return const Color(0xFF007ACC);
    if (lowerName.contains('discord')) return const Color(0xFF5865F2);
    if (lowerName.contains('file')) return const Color(0xFFFBBC05);
    if (lowerName.contains('setting')) return const Color(0xFF9AA0A6);
    return const Color(0xFF1A73E8);
  }
}

class AppLauncherService {
  static final AppLauncherService _instance = AppLauncherService._internal();
  factory AppLauncherService() => _instance;
  AppLauncherService._internal();

  List<DesktopAppInfo> _installedApps = [];
  List<DesktopAppInfo> get installedApps => _installedApps;

  bool _isLoaded = false;

  Future<void> loadApps() async {
    if (_isLoaded) return;

    final directories = [
      Directory('/usr/share/applications'),
      Directory('/usr/local/share/applications'),
      Directory('${Platform.environment['HOME']}/.local/share/applications'),
    ];

    final Map<String, DesktopAppInfo> appsMap = {};

    for (final dir in directories) {
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.desktop')) {
            final app = _parseDesktopFile(entity);
            if (app != null && !appsMap.containsKey(app.name)) {
              appsMap[app.name] = app;
            }
          }
        }
      } catch (e) {
        debugPrint('Error reading directory ${dir.path}: $e');
      }
    }

    _installedApps = appsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _isLoaded = true;
  }

  DesktopAppInfo? _parseDesktopFile(File file) {
    try {
      final lines = file.readAsLinesSync();
      bool inDesktopEntry = false;
      String? name;
      String? exec;
      String? icon;
      String? comment;
      bool noDisplay = false;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        if (line.startsWith('[') && line.endsWith(']')) {
          inDesktopEntry = line == '[Desktop Entry]';
          continue;
        }

        if (inDesktopEntry) {
          if (line.startsWith('Name=')) {
            name = line.substring(5).trim();
          } else if (line.startsWith('Exec=')) {
            exec = line.substring(5).trim();
          } else if (line.startsWith('Icon=')) {
            icon = line.substring(5).trim();
          } else if (line.startsWith('Comment=')) {
            comment = line.substring(8).trim();
          } else if (line.startsWith('NoDisplay=')) {
            noDisplay = line.substring(10).trim().toLowerCase() == 'true';
          }
        }
      }

      if (noDisplay || name == null || exec == null) {
        return null;
      }

      return DesktopAppInfo(
        name: name,
        exec: exec,
        iconName: icon ?? '',
        comment: comment,
      );
    } catch (_) {
      return null;
    }
  }
}

