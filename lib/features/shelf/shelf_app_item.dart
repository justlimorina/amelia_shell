import 'dart:io';
import 'package:flutter/material.dart';

class ShelfAppItem {
  final String id;
  final String name;
  final String iconName;
  final String exec;
  final bool isRunning;
  final bool isPinned;

  const ShelfAppItem({
    required this.id,
    required this.name,
    required this.iconName,
    required this.exec,
    this.isRunning = false,
    this.isPinned = true,
  });

  Future<void> launch() async {
    try {
      final parts = exec.split(' ');
      if (parts.isNotEmpty) {
        Process.start(parts[0], parts.sublist(1), mode: ProcessStartMode.detached);
      }
    } catch (e) {
      debugPrint('Error launching $name ($exec): $e');
    }
  }

  static List<ShelfAppItem> defaultPinnedApps() {
    return [
      const ShelfAppItem(
        id: 'chrome',
        name: 'Google Chrome',
        iconName: 'google-chrome',
        exec: 'google-chrome',
        isRunning: false,
      ),
      const ShelfAppItem(
        id: 'terminal',
        name: 'Terminal',
        iconName: 'utilities-terminal',
        exec: 'x-terminal-emulator',
        isRunning: true,
      ),
      const ShelfAppItem(
        id: 'files',
        name: 'Files',
        iconName: 'system-file-manager',
        exec: 'nautilus',
        isRunning: false,
      ),
      const ShelfAppItem(
        id: 'editor',
        name: 'Text Editor',
        iconName: 'accessories-text-editor',
        exec: 'gnome-text-editor',
        isRunning: false,
      ),
    ];
  }
}
