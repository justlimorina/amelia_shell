import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum SessionActionType {
  lock,
  logout,
  suspend,
  reboot,
  powerOff,
}

class SessionAction {
  final SessionActionType type;
  final String title;
  final String description;
  final IconData icon;
  final List<String> command;

  const SessionAction({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.command,
  });

  Future<void> execute() async {
    try {
      if (command.isNotEmpty) {
        await Process.run(command.first, command.skip(1).toList());
      }
    } catch (_) {}
  }
}

class SessionService {
  static const List<SessionAction> actions = [
    SessionAction(
      type: SessionActionType.lock,
      title: 'Lock Screen',
      description: 'Lock current session and return to lock screen',
      icon: Symbols.lock_rounded,
      command: ['loginctl', 'lock-session'],
    ),
    SessionAction(
      type: SessionActionType.suspend,
      title: 'Sleep / Suspend',
      description: 'Suspend computer to RAM',
      icon: Symbols.bedtime_rounded,
      command: ['systemctl', 'suspend'],
    ),
    SessionAction(
      type: SessionActionType.logout,
      title: 'Sign Out / Log Out',
      description: 'Terminate active session for current user',
      icon: Symbols.logout_rounded,
      command: ['loginctl', 'terminate-user', ''],
    ),
    SessionAction(
      type: SessionActionType.reboot,
      title: 'Restart',
      description: 'Reboot system',
      icon: Symbols.restart_alt_rounded,
      command: ['systemctl', 'reboot'],
    ),
    SessionAction(
      type: SessionActionType.powerOff,
      title: 'Shut Down',
      description: 'Power off computer',
      icon: Symbols.power_settings_new_rounded,
      command: ['systemctl', 'poweroff'],
    ),
  ];

  static List<SessionAction> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    return actions.where((action) {
      final titleMatch = action.title.toLowerCase().contains(q);
      final descMatch = action.description.toLowerCase().contains(q);
      final keyMatch = switch (action.type) {
        SessionActionType.lock => 'lock'.startsWith(q),
        SessionActionType.suspend => 'sleep'.startsWith(q) || 'suspend'.startsWith(q),
        SessionActionType.logout => 'logout'.startsWith(q) || 'sign out'.startsWith(q) || 'exit'.startsWith(q),
        SessionActionType.reboot => 'reboot'.startsWith(q) || 'restart'.startsWith(q),
        SessionActionType.powerOff => 'shutdown'.startsWith(q) || 'power off'.startsWith(q) || 'poweroff'.startsWith(q) || 'turn off'.startsWith(q),
      };
      return titleMatch || descMatch || keyMatch;
    }).toList();
  }
}
