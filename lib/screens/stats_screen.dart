import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sautifyv2/constants/ui_colors.dart';
import 'package:sautifyv2/db/library_store.dart';
import 'package:sautifyv2/models/stats_model.dart';
import 'package:sautifyv2/models/streaming_model.dart';
import 'package:sautifyv2/services/audio_player_service.dart';
import 'package:sautifyv2/services/image_cache_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgcolor,
        appBar: AppBar(
          backgroundColor: bgcolor,
          foregroundColor: Colors.white,
          title: const Text('Listening History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: cardcolor,
                    title: Row(
                      //spacing: 10,
                      children: [
                        Text(
                          'Clear History',
                          style: TextStyle(color: txtcolor),
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
                      style: TextStyle(color: txtcolor.withAlpha(200)),
                    ),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: appbarcolor),
                            ),
                          ),

                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: SizedBox(
                              height: 30,
                              width: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.red.withAlpha(100),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await LibraryStore.clearHistory();
                  if (mounted) setState(() {});
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: appbarcolor,
            labelColor: appbarcolor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Recently Played'),
              Tab(text: 'Most Played'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecentlyPlayedTab(key: UniqueKey()),
            const _MostPlayedTab(),
          ],
        ),
      ),
    );
  }
}

class _RecentlyPlayedTab extends StatelessWidget {
  const _RecentlyPlayedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StreamingData>>(
      future: LibraryStore.getRecentPlays(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: BoxConstraints(maxWidth: 50, maxHeight: 50),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
        final tracks = snapshot.data!;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: txtcolor),
              ),
              subtitle: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: txtcolor.withAlpha(180)),
              ),
              onTap: () {
                AudioPlayerService().loadPlaylist(
                  [track],
                  autoPlay: true,
                  sourceName: 'Recently Played',
                  sourceType: 'HISTORY',
                );
              },
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
    return FutureBuilder<List<SongStats>>(
      future: LibraryStore.getMostPlayed(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: BoxConstraints(maxWidth: 50, maxHeight: 50),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
        final stats = snapshot.data!;
        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return ListTile(
              leading: SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: appbarcolor,
                    ),
                  ),
                ),
              ),
              title: Text(
                stat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: txtcolor),
              ),
              subtitle: Text(
                '${stat.artist} • ${stat.playCount} plays',
                style: TextStyle(color: txtcolor.withAlpha(180)),
              ),
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: stat.thumbnailUrl ?? '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              onTap: () {
                final track = StreamingData(
                  videoId: stat.videoId,
                  title: stat.title,
                  artist: stat.artist,
                  thumbnailUrl: stat.thumbnailUrl,
                );
                AudioPlayerService().loadPlaylist(
                  [track],
                  autoPlay: true,
                  sourceName: 'Most Played',
                  sourceType: 'STATS',
                );
              },
            );
          },
        );
      },
    );
  }
}
