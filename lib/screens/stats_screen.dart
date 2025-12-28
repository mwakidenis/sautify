import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sautifyv2/blocs/library/library_cubit.dart';
import 'package:sautifyv2/blocs/library/library_state.dart';
import 'package:sautifyv2/models/streaming_model.dart';
import 'package:sautifyv2/services/audio_player_service.dart';
import 'package:sautifyv2/widgets/local_artwork_image.dart';

bool _isHttpUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

bool _looksLikeFilePath(String urlOrPath) {
  final s = urlOrPath.trim().toLowerCase();
  if (s.startsWith('file://')) return true;
  if (s.startsWith('content://')) return false;
  return s.startsWith('/') || RegExp(r'^[a-z]:\\').hasMatch(s);
}

String _stripFileScheme(String s) {
  final trimmed = s.trim();
  if (trimmed.toLowerCase().startsWith('file://')) {
    return trimmed.substring('file://'.length);
  }
  return trimmed;
}

int? _tryParseLocalId(String videoId) {
  if (videoId.startsWith('local_')) {
    return int.tryParse(videoId.substring('local_'.length));
  }
  if (videoId.startsWith('local:')) {
    return int.tryParse(videoId.substring('local:'.length));
  }
  return null;
}

Widget _buildTrackArtwork(BuildContext context, StreamingData track) {
  const double size = 50;
  final theme = Theme.of(context);

  final placeholder = Container(
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.music_note,
      color: theme.iconTheme.color?.withAlpha(100),
    ),
  );

  Widget child;
  if (track.isLocal && track.localId != null) {
    child = LocalArtworkImage(
      localId: track.localId!,
      placeholder: placeholder,
      fit: BoxFit.cover,
    );
  } else {
    final thumb = track.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      if (_looksLikeFilePath(thumb)) {
        child = Image.file(
          File(_stripFileScheme(thumb)),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } else if (_isHttpUrl(thumb)) {
        child = CachedNetworkImage(
          imageUrl: thumb,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => placeholder,
          placeholder: (_, __) => placeholder,
        );
      } else {
        child = placeholder;
      }
    } else {
      child = placeholder;
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(width: size, height: size, child: child),
  );
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listening History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).cardColor,
                    title: Row(
                      children: [
                        Text(
                          'Clear History',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                    content: Text(
                      'This will remove your recently played history! Are you sure you want to continue?',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withAlpha(200),
                      ),
                    ),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  context.read<LibraryCubit>().clearHistory();
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Recently Played'),
              Tab(text: 'Most Played'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RecentlyPlayedTab(),
            _MostPlayedTab(),
          ],
        ),
      ),
    );
  }
}

class _RecentlyPlayedTab extends StatelessWidget {
  const _RecentlyPlayedTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const Center(
            child: LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: BoxConstraints(maxWidth: 50, maxHeight: 50),
            ),
          );
        }
        if (state.recentPlays.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'No recent plays yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        final tracks = state.recentPlays;
        return ListView.builder(
          itemCount: tracks.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(50),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: _buildTrackArtwork(context, track),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withAlpha(180),
                  ),
                ),
                onTap: () {
                  AudioPlayerService().loadPlaylist(
                    [track],
                    autoPlay: true,
                    sourceName: 'Recently Played',
                    sourceType: 'HISTORY',
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _MostPlayedTab extends StatelessWidget {
  const _MostPlayedTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const Center(
            child: LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: BoxConstraints(maxWidth: 50, maxHeight: 50),
            ),
          );
        }
        if (state.mostPlayed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 64, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'No stats available yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        final stats = state.mostPlayed;
        return ListView.builder(
          itemCount: stats.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final stat = stats[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(50),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: _buildTrackArtwork(
                  context,
                  StreamingData(
                    videoId: stat.videoId,
                    title: stat.title,
                    artist: stat.artist,
                    thumbnailUrl: stat.thumbnailUrl,
                    isLocal: _tryParseLocalId(stat.videoId) != null,
                    localId: _tryParseLocalId(stat.videoId),
                  ),
                ),
                title: Text(
                  stat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${stat.artist}  ${stat.playCount} plays',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withAlpha(180),
                  ),
                ),
                trailing: Text(
                  '#${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                onTap: () {
                  final localId = _tryParseLocalId(stat.videoId);
                  final isLocal = localId != null;
                  final track = StreamingData(
                    videoId: stat.videoId,
                    title: stat.title,
                    artist: stat.artist,
                    thumbnailUrl: stat.thumbnailUrl,
                    isLocal: isLocal,
                    localId: localId,
                    streamUrl: isLocal
                        ? 'content://media/external/audio/media/$localId'
                        : null,
                    isAvailable: true,
                  );
                  AudioPlayerService().loadPlaylist(
                    [track],
                    autoPlay: true,
                    sourceName: 'Most Played',
                    sourceType: 'STATS',
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
