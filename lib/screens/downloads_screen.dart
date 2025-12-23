/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sautifyv2/l10n/app_localizations.dart';
import 'package:sautifyv2/models/streaming_model.dart';
import 'package:sautifyv2/screens/player_screen.dart';
import 'package:sautifyv2/services/audio_player_service.dart';
import 'package:sautifyv2/services/settings_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;
  bool _isLoading = true;
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    setState(() => _isLoading = true);
    try {
      // Check permissions based on Android version
      bool permissionGranted = false;
      if (Platform.isAndroid) {
        // For Android 13+ (SDK 33+), use audio permission
        // For older versions, use storage permission
        // We can try requesting both or checking status
        final audioStatus = await Permission.audio.status;
        final storageStatus = await Permission.storage.status;

        if (audioStatus.isGranted || storageStatus.isGranted) {
          permissionGranted = true;
        } else {
          // Request permissions
          // Note: On Android 13, requesting storage might not work as expected if targeting SDK 33
          Map<Permission, PermissionStatus> statuses = await [
            Permission.audio,
            Permission.storage,
          ].request();

          if (statuses[Permission.audio]?.isGranted == true ||
              statuses[Permission.storage]?.isGranted == true) {
            permissionGranted = true;
          }
        }
      } else {
        // For other platforms (iOS, etc.), assume granted or handle differently
        permissionGranted = true;
      }

      setState(() => _hasPermission = permissionGranted);

      if (permissionGranted) {
        await _loadSongs();
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSongs() async {
    try {
      // Get all songs from device
      // We query all and then filter because querying by path is limited/complex with MediaStore
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter by download path
      final settings = Provider.of<SettingsService>(context, listen: false);
      final downloadPath = settings.downloadPath;

      // Normalize path for comparison (remove trailing slash if any)
      final normalizedDownloadPath = downloadPath.endsWith('/')
          ? downloadPath.substring(0, downloadPath.length - 1)
          : downloadPath;

      final filteredSongs = songs.where((song) {
        // Check if song data path starts with our download path
        // song.data contains the absolute path
        if (song.data.isEmpty) return false;

        // Case insensitive check for path
        return song.data.toLowerCase().contains(
          normalizedDownloadPath.toLowerCase(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _songs = filteredSongs;
        });
      }
    } catch (e) {
      debugPrint('Error loading songs: $e');
    }
  }

  Future<void> _pickFolder() async {
    try {
      debugPrint('Requesting folder picker...');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      debugPrint('Selected directory: $selectedDirectory');

      if (selectedDirectory != null) {
        if (mounted) {
          final settings = Provider.of<SettingsService>(context, listen: false);
          await settings.setDownloadPath(selectedDirectory);
          await _loadSongs();
        }
      }
    } catch (e, stack) {
      debugPrint('Error picking folder: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error picking folder. Using manual entry.'),
            duration: Duration(seconds: 2),
          ),
        );
        _showManualPathDialog();
      }
    }
  }

  void _showManualPathDialog() {
    final controller = TextEditingController(
      text: Provider.of<SettingsService>(context, listen: false).downloadPath,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Enter Folder Path',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            labelText: 'Path',
            labelStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            hintText: '/storage/emulated/0/Music',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.3),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                Provider.of<SettingsService>(
                  context,
                  listen: false,
                ).setDownloadPath(path);
                _loadSongs();
                Navigator.pop(context);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
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
              onPressed: _checkPermissionAndLoad,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.grantPermission),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 64,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSongsFound,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyLarge?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Path: ${Provider.of<SettingsService>(context).downloadPath}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFolder,
              icon: Icon(Icons.folder_open, size: 18),
              label: Text('Select Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // backgroundColor: bgcolor,
      appBar: AppBar(
        // backgroundColor: bgcolor,
        elevation: 0,
        title: Text(
          l10n.downloadsTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<SettingsService>(
            builder: (context, settings, child) {
              return Row(
                children: [
                  const Text('Offline', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: settings.offlineMode,
                    onChanged: (v) => settings.setOfflineMode(v),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.folder_open,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _pickFolder,
            tooltip: 'Change Folder',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
            onPressed: _loadSongs,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // Space for mini player
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
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
              leading: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
                artworkBorder: BorderRadius.circular(8),
                artworkWidth: 50,
                artworkHeight: 50,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                song.artist ?? '<Unknown>',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              onTap: () => _playSong(index),
            ),
          );
        },
      ),
    );
  }

  Future<void> _playSong(int index) async {
    final audioService = Provider.of<AudioPlayerService>(
      context,
      listen: false,
    );

    // Convert SongModel list to StreamingData list
    final playlist = _songs.map((song) {
      // For local files, we use the file path as the ID or URL
      // AudioPlayerService needs to handle local files correctly
      // Assuming StreamingData can handle file paths in videoId or we need a way to distinguish

      // We'll use the file URI as the videoId/streamUrl for local playback
      // The AudioPlayerService needs to detect if it's a local file

      return StreamingData(
        videoId: song.data, // Use path as ID
        title: song.title,
        artist: song.artist ?? 'Unknown',
        thumbnailUrl:
            null, // We can't easily pass local artwork path here without extraction
        duration: Duration(milliseconds: song.duration ?? 0),
        streamUrl: song.data, // Local path
        isLocal: true,
        isAvailable: true,
        localId: song.id,
      );
    }).toList();

    await audioService.loadPlaylist(
      playlist,
      initialIndex: index,
      autoPlay: true,
      sourceType: 'DOWNLOADS',
      sourceName: 'Offline Music',
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: playlist[index].title,
            artist: playlist[index].artist,
            imageUrl:
                null, // Local artwork handling might be needed in PlayerScreen
            duration: playlist[index].duration,
            videoId: playlist[index].videoId,
            playlist: playlist,
            initialIndex: index,
            sourceType: 'DOWNLOADS',
            sourceName: 'Offline Music',
          ),
        ),
      );
    }
  }
}
