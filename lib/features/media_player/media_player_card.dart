import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/mpris_service.dart';

class MediaPlayerCard extends StatelessWidget {
  const MediaPlayerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mpris = MprisService();
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<MprisTrack?>(
      stream: mpris.currentTrackStream,
      initialData: mpris.currentTrack,
      builder: (context, snapshot) {
        final track = snapshot.data;
        if (track == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Album Art or Music Icon
                  _AlbumArt(artUrl: track.artUrl),
                  const SizedBox(width: 12),

                  // Track Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Player Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => mpris.previous(),
                        tooltip: 'Previous',
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            track.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: colorScheme.onPrimary,
                            size: 20,
                          ),
                          onPressed: () => mpris.playPause(),
                          tooltip: track.isPlaying ? 'Pause' : 'Play',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => mpris.next(),
                        tooltip: 'Next',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String? artUrl;

  const _AlbumArt({this.artUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget? imageWidget;
    if (artUrl != null && artUrl!.isNotEmpty) {
      if (artUrl!.startsWith('file://')) {
        final filePath = Uri.decodeFull(artUrl!.replaceFirst('file://', ''));
        final file = File(filePath);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _fallbackIcon(colorScheme),
          );
        }
      } else if (artUrl!.startsWith('http://') || artUrl!.startsWith('https://')) {
        imageWidget = Image.network(
          artUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackIcon(colorScheme),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        color: colorScheme.primaryContainer,
        child: imageWidget ?? _fallbackIcon(colorScheme),
      ),
    );
  }

  Widget _fallbackIcon(ColorScheme colorScheme) {
    return Icon(
      Icons.music_note_rounded,
      color: colorScheme.onPrimaryContainer,
      size: 24,
    );
  }
}
