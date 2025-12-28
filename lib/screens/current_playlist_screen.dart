/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';
import 'package:sautifyv2/blocs/audio_player_cubit.dart';

class CurrentPlaylistScreen extends StatelessWidget {
  const CurrentPlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioCubit = context.read<AudioPlayerCubit>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
        ),
        title: Text(
          'Now Playing',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (context, state) {
              return IconButton(
                onPressed: () => audioCubit.setShuffle(!state.isShuffleEnabled),
                icon: Icon(
                  Icons.shuffle,
                  color: state.isShuffleEnabled
                      ? colorScheme.primary
                      : Theme.of(context).iconTheme.color?.withAlpha(180),
                ),
              );
            },
          ),
          BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (context, state) {
              final mode = state.loopMode;
              IconData icon;
              Color? color;
              if (mode == LoopMode.one) {
                icon = Icons.repeat_one;
                color = colorScheme.primary;
              } else if (mode == LoopMode.all) {
                icon = Icons.repeat;
                color = colorScheme.primary;
              } else {
                icon = Icons.repeat;
                color = Theme.of(context).iconTheme.color?.withAlpha(180);
              }
              return IconButton(
                onPressed: () {
                  final newMode = mode == LoopMode.off
                      ? LoopMode.all
                      : (mode == LoopMode.all ? LoopMode.one : LoopMode.off);
                  audioCubit.setLoopMode(newMode);
                },
                icon: Icon(icon, color: color),
              );
            },
          ),
          BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${state.playlist.length} songs',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withAlpha(180),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (context, state) {
          final playlist = state.playlist;

          if (playlist.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 64,
                    color: Theme.of(context).iconTheme.color?.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No songs in playlist',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withAlpha(180),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(50),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: 8 + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: playlist.length,
                  itemBuilder: (context, index) {
                    final track = playlist[index];
                    final isCurrentTrack = index == state.currentIndex;

                    return Container(
                      color: isCurrentTrack
                          ? colorScheme.primary.withAlpha(30)
                          : Colors.transparent,
                      child: ListTile(
                        onTap: () async {
                          if (index != state.currentIndex) {
                            final success = await audioCubit.seek(Duration.zero,
                                index: index);
                            if (context.mounted) {
                              if (success) {
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Unable to play track. Please try again.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: M3Container.square(
                            width: 56,
                            height: 56,
                            child: track.thumbnailUrl != null
                                ? CachedNetworkImage(
                                    placeholder: (context, url) =>
                                        M3Container.square(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withAlpha(155),
                                      child: LoadingIndicatorM3E(
                                        color:
                                            colorScheme.primary.withAlpha(155),
                                      ),
                                    ),
                                    imageUrl: track.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    width: 48,
                                    height: 48,
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.music_note,
                                      color: Theme.of(context)
                                          .iconTheme
                                          .color
                                          ?.withAlpha(180),
                                      size: 24,
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    color: Theme.of(context)
                                        .iconTheme
                                        .color
                                        ?.withAlpha(180),
                                    size: 24,
                                  ),
                          ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentTrack
                                ? colorScheme.primary
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                            fontWeight: isCurrentTrack
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentTrack
                                ? colorScheme.primary.withAlpha(180)
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withAlpha(180),
                            fontSize: 13,
                          ),
                        ),
                        trailing: isCurrentTrack
                            ? SizedBox(
                                width: 40,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: MiniMusicVisualizer(
                                    animate: true,
                                    color: colorScheme.primary,
                                    width: 4,
                                    height: 15,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
