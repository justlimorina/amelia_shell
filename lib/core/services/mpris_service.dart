import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

class MprisTrack {
  final String playerBusName;
  final String playerName;
  final String title;
  final String artist;
  final String album;
  final String? artUrl;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const MprisTrack({
    required this.playerBusName,
    required this.playerName,
    required this.title,
    required this.artist,
    required this.album,
    this.artUrl,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });
}

class MprisService {
  static final MprisService _instance = MprisService._internal();
  factory MprisService() => _instance;
  MprisService._internal();

  DBusClient? _client;
  Timer? _pollTimer;

  final _trackController = StreamController<MprisTrack?>.broadcast();
  Stream<MprisTrack?> get currentTrackStream => _trackController.stream;

  MprisTrack? _currentTrack;
  MprisTrack? get currentTrack => _currentTrack;

  void start() {
    _client ??= DBusClient.session();
    _pollActivePlayers();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollActivePlayers();
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _client?.close();
    _client = null;
  }

  Future<void> _pollActivePlayers() async {
    try {
      final client = _client ?? DBusClient.session();
      final names = await client.listNames();

      final playerNames = names
          .where((n) => n.startsWith('org.mpris.MediaPlayer2.'))
          .toList();

      if (playerNames.isEmpty) {
        if (_currentTrack != null) {
          _currentTrack = null;
          _trackController.add(null);
        }
        return;
      }

      // Prioritize playing players, otherwise pick the first available
      MprisTrack? foundTrack;

      for (final busName in playerNames) {
        final track = await _getTrackForPlayer(client, busName);
        if (track != null) {
          if (track.isPlaying) {
            foundTrack = track;
            break;
          }
          foundTrack ??= track;
        }
      }

      _currentTrack = foundTrack;
      _trackController.add(_currentTrack);
    } catch (e) {
      debugPrint('MprisService._pollActivePlayers error: $e');
    }
  }

  Future<MprisTrack?> _getTrackForPlayer(
      DBusClient client, String busName) async {
    try {
      final object = DBusRemoteObject(
        client,
        name: busName,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );

      // Fetch PlaybackStatus
      final statusValue = await object.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'PlaybackStatus',
      );
      final status = (statusValue as DBusString).value;
      final isPlaying = status.toLowerCase() == 'playing';

      // Fetch Metadata
      final metadataValue = await object.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'Metadata',
      );

      String title = '';
      String artist = '';
      String album = '';
      String? artUrl;
      Duration duration = Duration.zero;

      if (metadataValue is DBusDict) {
        final map = metadataValue.children;

        for (final entry in map.entries) {
          final key = (entry.key as DBusString).value;
          final val = entry.value;

          if (key == 'xesam:title') {
            title = _extractString(val);
          } else if (key == 'xesam:artist') {
            artist = _extractString(val);
          } else if (key == 'xesam:album') {
            album = _extractString(val);
          } else if (key == 'mpris:artUrl') {
            artUrl = _extractString(val);
          } else if (key == 'mpris:length') {
            final unwrapped = _unwrap(val);
            if (unwrapped is DBusInt64) {
              duration = Duration(microseconds: unwrapped.value);
            } else if (unwrapped is DBusUint64) {
              duration = Duration(microseconds: unwrapped.value);
            }
          }
        }
      }

      // If title is empty, it might be stopped or an idle player
      if (title.isEmpty && !isPlaying) {
        return null;
      }

      // Friendly player name
      String playerName = busName.replaceFirst('org.mpris.MediaPlayer2.', '');
      if (playerName.contains('.')) {
        playerName = playerName.split('.').first;
      }
      playerName = playerName[0].toUpperCase() + playerName.substring(1);

      return MprisTrack(
        playerBusName: busName,
        playerName: playerName,
        title: title.isNotEmpty ? title : 'Media Audio',
        artist: artist.isNotEmpty ? artist : 'Unknown Artist',
        album: album,
        artUrl: artUrl,
        isPlaying: isPlaying,
        position: Duration.zero,
        duration: duration,
      );
    } catch (_) {
      return null;
    }
  }

  DBusValue _unwrap(DBusValue value) {
    if (value is DBusVariant) {
      return _unwrap(value.value);
    }
    return value;
  }

  String _extractString(DBusValue value) {
    final unwrapped = _unwrap(value);
    if (unwrapped is DBusString) return unwrapped.value;
    if (unwrapped is DBusArray) {
      return unwrapped.children
          .map((v) => _extractString(v))
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return '';
  }

  Future<void> playPause() async {
    final track = _currentTrack;
    if (track == null || _client == null) return;

    try {
      final object = DBusRemoteObject(
        _client!,
        name: track.playerBusName,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      await object.callMethod(
        'org.mpris.MediaPlayer2.Player',
        'PlayPause',
        [],
      );
      await _pollActivePlayers();
    } catch (e) {
      debugPrint('Error playPause: $e');
    }
  }

  Future<void> next() async {
    final track = _currentTrack;
    if (track == null || _client == null) return;

    try {
      final object = DBusRemoteObject(
        _client!,
        name: track.playerBusName,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      await object.callMethod(
        'org.mpris.MediaPlayer2.Player',
        'Next',
        [],
      );
      await _pollActivePlayers();
    } catch (e) {
      debugPrint('Error next: $e');
    }
  }

  Future<void> previous() async {
    final track = _currentTrack;
    if (track == null || _client == null) return;

    try {
      final object = DBusRemoteObject(
        _client!,
        name: track.playerBusName,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      await object.callMethod(
        'org.mpris.MediaPlayer2.Player',
        'Previous',
        [],
      );
      await _pollActivePlayers();
    } catch (e) {
      debugPrint('Error previous: $e');
    }
  }
}

