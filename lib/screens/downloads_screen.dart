/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sautifyv2/blocs/device_library/device_library_cubit.dart';
import 'package:sautifyv2/blocs/device_library/device_library_state.dart';
import 'package:sautifyv2/blocs/download/download_cubit.dart';
import 'package:sautifyv2/blocs/download/download_state.dart';
import 'package:sautifyv2/blocs/settings/settings_cubit.dart';
import 'package:sautifyv2/blocs/settings/settings_state.dart';
import 'package:sautifyv2/l10n/app_localizations.dart';
import 'package:sautifyv2/models/streaming_model.dart';
import 'package:sautifyv2/screens/player_screen.dart';
import 'package:sautifyv2/widgets/local_artwork_image.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  static bool _isHttpUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static bool _looksLikeFilePath(String urlOrPath) {
    final s = urlOrPath.trim().toLowerCase();
    if (s.startsWith('file://')) return true;
    if (s.startsWith('content://')) return false;
    // Heuristic: absolute-ish paths or Windows drive paths.
    return s.startsWith('/') || RegExp(r'^[a-z]:\\').hasMatch(s);
  }

  static String _stripFileScheme(String s) {
    final trimmed = s.trim();
    if (trimmed.toLowerCase().startsWith('file://')) {
      return trimmed.substring('file://'.length);
    }
    return trimmed;
  }

  Widget _buildArtwork(BuildContext context, StreamingData track) {
    const double size = 50;
    final theme = Theme.of(context);

    final placeholder = Container(
      color: theme.colorScheme.primary.withAlpha(30),
      child: Icon(
        Icons.music_note,
        color: theme.colorScheme.primary,
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
      if (thumb != null && thumb.trim().isNotEmpty) {
        if (_looksLikeFilePath(thumb)) {
          child = Image.file(
            File(_stripFileScheme(thumb)),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );
        } else if (_isHttpUrl(thumb)) {
          child = CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          );
        } else {
          child = placeholder;
        }
      } else {
        child = placeholder;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: child,
      ),
    );
  }

  List<StreamingData> _combineOfflineTracks(
    List<StreamingData> downloaded,
    List<StreamingData> onDevice,
  ) {
    final seen = <String>{};
    final out = <StreamingData>[];

    void addAll(Iterable<StreamingData> items) {
      for (final t in items) {
        final key = (t.streamUrl ?? '').isNotEmpty ? t.streamUrl! : t.videoId;
        if (key.isEmpty) continue;
        if (seen.add(key)) out.add(t);
      }
    }

    addAll(downloaded);
    addAll(onDevice);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, downloadState) {
        return BlocBuilder<DeviceLibraryCubit, DeviceLibraryState>(
          builder: (context, deviceState) {
            final combined = _combineOfflineTracks(
              downloadState.downloadedTracks,
              deviceState.tracks,
            );

            final isLoading =
                (downloadState.isLoading || deviceState.isLoading) &&
                    combined.isEmpty;

            final showDownloadsPermissionGate =
                !downloadState.hasPermission && deviceState.tracks.isEmpty;

            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (showDownloadsPermissionGate) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.permissionDenied,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<DownloadCubit>()
                          .checkPermissionAndLoad(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.grantPermission),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context
                          .read<DeviceLibraryCubit>()
                          .requestPermission(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Grant device audio permission'),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                elevation: 0,
                title: Text(
                  l10n.downloadsTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () => _pickFolder(context),
                    tooltip: 'Change Download Folder',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      context.read<DownloadCubit>().loadSongs();
                      context.read<DeviceLibraryCubit>().refresh();
                    },
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              body: combined.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off_rounded,
                            size: 64,
                            color: Theme.of(context)
                                .iconTheme
                                .color
                                ?.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noSongsFound,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withOpacity(0.7),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<SettingsCubit, SettingsState>(
                            builder: (context, settings) {
                              return Text(
                                'Path: ${settings.downloadPath}',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _pickFolder(context),
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Select Folder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: combined.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final track = combined[index];
                        final canPlay =
                            track.isAvailable && track.streamUrl != null;

                        return ListTile(
                          leading: _buildArtwork(context, track),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          enabled: canPlay,
                          onTap: canPlay
                              ? () {
                                  final playlist = combined
                                      .where((t) =>
                                          t.isAvailable && t.streamUrl != null)
                                      .map(
                                        (t) => t.copyWith(
                                          isAvailable: true,
                                          isLocal: true,
                                        ),
                                      )
                                      .toList(growable: false);

                                  final initialIndex = playlist.indexWhere(
                                    (t) => t.videoId == track.videoId,
                                  );

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PlayerScreen(
                                        title: track.title,
                                        artist: track.artist,
                                        imageUrl: track.thumbnailUrl,
                                        playlist: playlist,
                                        initialIndex:
                                            initialIndex < 0 ? 0 : initialIndex,
                                        sourceType: 'OFFLINE',
                                        sourceName: 'Offline',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && context.mounted) {
        context.read<SettingsCubit>().setDownloadPath(selectedDirectory);
        context.read<DownloadCubit>().loadSongs();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error picking folder')),
        );
      }
    }
  }
}
