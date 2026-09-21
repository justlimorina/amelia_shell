import 'dart:io';
import 'package:flutter/foundation.dart';

class WifiNetwork {
  final String ssid;
  final int signal; // 0 - 100
  final String security;
  final bool isConnected;

  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
    required this.isConnected,
  });

  bool get isSecured =>
      security.isNotEmpty && !security.toLowerCase().contains('--');
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  Future<bool> isWifiEnabled() async {
    try {
      final result = await Process.run('nmcli', ['radio', 'wifi']);
      return result.stdout.toString().trim().toLowerCase() == 'enabled';
    } catch (_) {
      return true;
    }
  }

  Future<void> setWifiEnabled(bool enable) async {
    try {
      await Process.run('nmcli', ['radio', 'wifi', enable ? 'on' : 'off']);
    } catch (e) {
      debugPrint('Error toggling wifi: $e');
    }
  }

  Future<List<WifiNetwork>> scanWifi() async {
    try {
      final result = await Process.run(
        'nmcli',
        ['-t', '-f', 'SSID,SIGNAL,SECURITY,IN-USE', 'dev', 'wifi', 'list'],
      );

      final lines = result.stdout.toString().split('\n');
      final Map<String, WifiNetwork> networkMap = {};

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // Escape colons in nmcli format or split by :
        final parts = line.split(':');
        if (parts.length >= 4) {
          final ssid = parts[0].replaceAll(r'\:', ':').trim();
          if (ssid.isEmpty) continue;

          final signal = int.tryParse(parts[1]) ?? 50;
          final security = parts[2].trim();
          final isConnected = parts[3].trim() == '*';

          final network = WifiNetwork(
            ssid: ssid,
            signal: signal,
            security: security,
            isConnected: isConnected,
          );

          // Keep highest signal if duplicated SSID
          if (!networkMap.containsKey(ssid) ||
              (networkMap[ssid]!.signal < signal && !networkMap[ssid]!.isConnected)) {
            networkMap[ssid] = network;
          }
        }
      }

      final list = networkMap.values.toList();
      list.sort((a, b) {
        if (a.isConnected) return -1;
        if (b.isConnected) return 1;
        return b.signal.compareTo(a.signal);
      });

      return list;
    } catch (e) {
      debugPrint('Error scanning wifi: $e');
      return [];
    }
  }

  Future<bool> connect(String ssid, [String? password]) async {
    try {
      final args = ['dev', 'wifi', 'connect', ssid];
      if (password != null && password.isNotEmpty) {
        args.addAll(['password', password]);
      }
      final result = await Process.run('nmcli', args);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error connecting to wifi: $e');
      return false;
    }
  }
}
