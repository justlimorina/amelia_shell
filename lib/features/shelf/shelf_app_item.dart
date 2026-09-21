import 'dart:io';
import 'package:flutter/material.dart';

class ShelfAppItem {
  final String id;
  final String name;
  final IconData icon;
  final Color iconColor;
  final String exec;
  final bool isRunning;
  final bool isPinned;

  const ShelfAppItem({
    required this.id,
    required this.name,
    required this.icon,
    this.iconColor = Colors.white,
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
        icon: Icons.language,
        iconColor: Color(0xFF4285F4),
        exec: 'google-chrome',
        isRunning: false,
      ),
      const ShelfAppItem(
        id: 'terminal',
        name: 'Terminal',
        icon: Icons.terminal,
        iconColor: Color(0xFF34A853),
        exec: 'x-terminal-emulator',
        isRunning: true,
      ),
      const ShelfAppItem(
        id: 'files',
        name: 'Files',
        icon: Icons.folder,
        iconColor: Color(0xFFFBBC05),
        exec: 'nautilus',
        isRunning: false,
      ),
      const ShelfAppItem(
        id: 'editor',
        name: 'Text Editor',
        icon: Icons.edit_note,
        iconColor: Color(0xFFEA4335),
        exec: 'gnome-text-editor',
        isRunning: false,
      ),
    ];
  }
}

