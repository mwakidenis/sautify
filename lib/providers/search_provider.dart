/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'dart:async';

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sautifyv2/models/album_search_result.dart';
import 'package:sautifyv2/models/streaming_model.dart';

class SearchProvider extends ChangeNotifier {
  final YTMusic _ytmusic = YTMusic();

  bool _initialized = false;
  bool _isLoading = false;
  String _query = '';
  String? _error;

  // Raw results from YTMusic (keep only needed fields by mapping to StreamingData)
  final List<StreamingData> _results = [];
  final List<String> _suggestions = [];
  final List<AlbumSearchResult> _albumResults = [];

  // RxDart streams for input and lifecycle
  final _querySubject = BehaviorSubject<String>.seeded('');
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final Duration _debounceDuration = const Duration(milliseconds: 350);

  SearchProvider() {
    _initialize();
    _setupStreams();
  }

  // Getters
  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  String get query => _query;
  String? get error => _error;
  List<StreamingData> get results => List.unmodifiable(_results);
  List<String> get suggestions => List.unmodifiable(_suggestions);
  List<AlbumSearchResult> get albumResults => List.unmodifiable(_albumResults);

  Future<void> _initialize() async {
    try {
      await _ytmusic.initialize();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize search: $e';
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    _query = value;
    // Push into the query stream; suggestions will debounce/cancel via Rx
    _querySubject.add(value);
    notifyListeners();
  }

  Future<void> fetchSuggestions([String? q]) async {
    final searchText = (q ?? _query).trim();
    if (searchText.isEmpty || !_initialized) {
      _suggestions.clear();
      notifyListeners();
      return;
    }
    try {
      final sugg = await _ytmusic.getSearchSuggestions(searchText);

      _suggestions
        ..clear()
        ..addAll(sugg);
      notifyListeners();
    } catch (e) {
      // Non-fatal
    }
  }

  Future<void> search([String? q]) async {
    final searchText = (q ?? _query).trim();
    if (searchText.isEmpty || !_initialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Kick off both requests
      final songs = await _ytmusic.searchSongs(searchText);
      final albums = await _ytmusic.searchAlbums(searchText);

      _results
        ..clear()
        ..addAll(
          songs.map((song) {
            final thumb = _pickBetterThumb(song.thumbnails);
            // Convert API duration (int? seconds) to Duration?
            final int? seconds = song.duration;
            final Duration? dur = seconds != null
                ? Duration(seconds: seconds)
                : null;

            return StreamingData(
              videoId: song.videoId,
              title: song.name,
              artist: song.artist.name,
              thumbnailUrl: thumb,
              duration: dur,
            );
          }),
        );

      _albumResults
        ..clear()
        ..addAll(
          albums.map((album) {
            final thumb = _pickBetterThumb(album.thumbnails);
            return AlbumSearchResult(
              albumId: album.albumId,
              playlistId: album.playlistId,
              title: album.name,
              artist: album.artist.name,
              thumbnailUrl: thumb,
            );
          }),
        );
    } catch (e) {
      _error = 'Search failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<StreamingData>> fetchAlbumTracks(String albumId) async {
    if (!_initialized) return [];
    try {
      final album = await _ytmusic.getAlbum(albumId);
      // Map tracks to StreamingData
      final tracks = album.songs.map((s) {
        final thumb = _pickBetterThumb(s.thumbnails);
        final int? seconds = s.duration;
        final Duration? dur = seconds != null
            ? Duration(seconds: seconds)
            : null;
        return StreamingData(
          videoId: s.videoId,
          title: s.name,
          artist: s.artist.name,
          thumbnailUrl: thumb,
          duration: dur,
        );
      }).toList();
      return tracks;
    } catch (e) {
      _error = 'Failed to load album: $e';
      notifyListeners();
      return [];
    }
  }

  // Prefer medium/high thumbnail: pick second if present, else last, else null
  String? _pickBetterThumb(List thumbnails) {
    if (thumbnails.isEmpty) return null;
    if (thumbnails.length >= 2) return thumbnails[1].url;
    return thumbnails.last.url;
  }

  @override
  void dispose() {
    _subscriptions.dispose();
    _querySubject.close();
    super.dispose();
  }

  void _setupStreams() {
    // Debounced, cancellable suggestions stream.
    // On every query change, wait for the debounce window and fetch suggestions.
    // switchMap ensures in-flight requests are ignored/cancelled when a new query arrives.
    final s = _querySubject
        .debounceTime(_debounceDuration)
        .map((q) => q.trim())
        .distinct()
        .where((q) => q.isNotEmpty)
        .switchMap<List<String>>((q) {
          Future<List<String>> fut;
          if (_initialized) {
            fut = _ytmusic
                .getSearchSuggestions(q)
                .then((s) => List<String>.from(s.map((e) => e.toString())));
          } else {
            fut = Future.value(<String>[]);
          }
          return Stream.fromFuture(fut).onErrorReturn(<String>[]);
        })
        .listen((sugg) {
          _suggestions
            ..clear()
            ..addAll(sugg);
          notifyListeners();
        });
    _subscriptions.add(s);
  }
}
