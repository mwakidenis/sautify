import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sautifyv2/models/album_search_result.dart';
import 'package:sautifyv2/models/streaming_model.dart';
import 'package:sautifyv2/services/search_worker_service.dart';
import 'package:sautifyv2/services/ytmusic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final YTMusicService _yt = YTMusicService.instance;
  final SearchWorkerService _worker = SearchWorkerService.instance;
  static const _recentKey = 'recent_searches';
  static const _recentMax = 10;

  SearchBloc() : super(const SearchState()) {
    on<SearchStarted>(_onStarted);
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 350))
          .switchMap(mapper),
    );
    on<SearchSubmitted>(_onSubmitted);
    on<SearchSuggestionsRequested>(_onSuggestionsRequested);
    on<SearchCleared>(_onCleared);
    on<SearchRecentLoaded>(_onRecentLoaded);
    on<SearchRecentAdded>(_onRecentAdded);
    on<SearchRecentRemoved>(_onRecentRemoved);
    on<SearchRecentCleared>(_onRecentCleared);

    add(SearchStarted());
    add(SearchRecentLoaded());
  }

  Future<void> _onStarted(
    SearchStarted event,
    Emitter<SearchState> emit,
  ) async {
    try {
      try {
        await _worker.initializeIfNeeded(timeout: const Duration(seconds: 15));
        emit(state.copyWith(isInitialized: true));
        return;
      } catch (_) {
        // Fallback to the in-process client if the worker can't start.
      }

      await _yt.initializeIfNeeded(timeout: const Duration(seconds: 15));
      emit(state.copyWith(isInitialized: true));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to initialize search: $e'));
    }
  }

  Future<void> _onRecentLoaded(
    SearchRecentLoaded event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentKey) ?? [];
      emit(state.copyWith(recentSearches: list.take(_recentMax).toList()));
    } catch (_) {}
  }

  Future<void> _onRecentAdded(
    SearchRecentAdded event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    final recent = List<String>.from(state.recentSearches);
    recent.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    recent.insert(0, query);
    final updated = recent.take(_recentMax).toList();

    emit(state.copyWith(recentSearches: updated));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, updated);
    } catch (_) {}
  }

  Future<void> _onRecentRemoved(
    SearchRecentRemoved event,
    Emitter<SearchState> emit,
  ) async {
    final recent = List<String>.from(state.recentSearches);
    recent.removeWhere((e) => e.toLowerCase() == event.query.toLowerCase());
    emit(state.copyWith(recentSearches: recent));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, recent);
    } catch (_) {}
  }

  Future<void> _onRecentCleared(
    SearchRecentCleared event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(recentSearches: []));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentKey);
    } catch (_) {}
  }

  String? _pickBetterThumb(List<dynamic>? thumbs) {
    if (thumbs == null || thumbs.isEmpty) return null;
    // Prefer higher resolution if available
    return thumbs.last.url as String?;
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    emit(state.copyWith(query: query));
    if (query.isEmpty) {
      emit(state.copyWith(suggestions: []));
      return;
    }

    if (!state.isInitialized) return;

    try {
      List<String> suggestions;
      try {
        suggestions = await _worker.suggestions(
          query,
          timeout: const Duration(seconds: 4),
        );
      } catch (_) {
        suggestions = await _yt.getSearchSuggestions(
          query,
          timeout: const Duration(seconds: 4),
        );
      }
      emit(state.copyWith(suggestions: suggestions));
    } catch (e) {
      // Non-fatal
    }
  }

  Future<void> _onSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty || !state.isInitialized) return;

    emit(state.copyWith(
        status: SearchStatus.loading, query: query, error: null));

    try {
      List<StreamingData> mappedSongs;
      List<AlbumSearchResult> mappedAlbums;

      try {
        final res = await _worker.search(
          query,
          timeout: const Duration(seconds: 10),
        );

        mappedSongs = res.songs.map((m) {
          final seconds = m['durationSeconds'] as int?;
          return StreamingData(
            videoId: (m['videoId'] as String?) ?? '',
            title: (m['title'] as String?) ?? '',
            artist: (m['artist'] as String?) ?? '',
            thumbnailUrl: m['thumbnailUrl'] as String?,
            duration: seconds != null ? Duration(seconds: seconds) : null,
          );
        }).toList(growable: false);

        mappedAlbums = res.albums.map((m) {
          return AlbumSearchResult(
            albumId: (m['albumId'] as String?) ?? '',
            playlistId: (m['playlistId'] as String?) ?? '',
            title: (m['title'] as String?) ?? '',
            artist: (m['artist'] as String?) ?? '',
            thumbnailUrl: m['thumbnailUrl'] as String?,
          );
        }).toList(growable: false);
      } catch (_) {
        final songsFut =
            _yt.searchSongs(query, timeout: const Duration(seconds: 10));
        final albumsFut =
            _yt.searchAlbums(query, timeout: const Duration(seconds: 10));

        final results = await Future.wait([songsFut, albumsFut]);
        final songs = results[0];
        final albums = results[1];

        mappedSongs = songs.map((song) {
          final thumb = _pickBetterThumb(song.thumbnails);
          final int? seconds = song.duration;
          final Duration? dur =
              seconds != null ? Duration(seconds: seconds) : null;
          return StreamingData(
            videoId: song.videoId,
            title: song.name,
            artist: song.artist.name,
            thumbnailUrl: thumb,
            duration: dur,
          );
        }).toList();

        mappedAlbums = albums.map((album) {
          final thumb = _pickBetterThumb(album.thumbnails);
          return AlbumSearchResult(
            albumId: album.albumId,
            playlistId: album.playlistId,
            title: album.name,
            artist: album.artist.name,
            thumbnailUrl: thumb,
          );
        }).toList();
      }

      emit(state.copyWith(
        status: SearchStatus.success,
        results: mappedSongs,
        albumResults: mappedAlbums,
      ));
    } catch (e) {
      emit(state.copyWith(status: SearchStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSuggestionsRequested(
    SearchSuggestionsRequested event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty || !state.isInitialized) return;

    try {
      List<String> suggestions;
      try {
        suggestions = await _worker.suggestions(query);
      } catch (_) {
        suggestions = await _yt.getSearchSuggestions(query);
      }
      emit(state.copyWith(suggestions: suggestions));
    } catch (e) {
      // Non-fatal
    }
  }

  void _onCleared(SearchCleared event, Emitter<SearchState> emit) {
    emit(state.copyWith(
      query: '',
      results: [],
      suggestions: [],
      albumResults: [],
      status: SearchStatus.initial,
    ));
  }

  Future<List<StreamingData>> fetchAlbumTracks(String albumId) async {
    try {
      try {
        final tracks = await _worker.albumTracks(
          albumId,
          timeout: const Duration(seconds: 10),
        );
        return tracks.map((m) {
          final seconds = m['durationSeconds'] as int?;
          return StreamingData(
            videoId: (m['videoId'] as String?) ?? '',
            title: (m['title'] as String?) ?? '',
            artist: (m['artist'] as String?) ?? '',
            thumbnailUrl: m['thumbnailUrl'] as String?,
            duration: seconds != null ? Duration(seconds: seconds) : null,
          );
        }).toList(growable: false);
      } catch (_) {
        final album = await _yt.getAlbum(albumId);
        return album.tracks.map((track) {
          final thumb = _pickBetterThumb(track.thumbnails);
          final int? seconds = track.duration;
          final Duration? dur =
              seconds != null ? Duration(seconds: seconds) : null;
          return StreamingData(
            videoId: track.videoId,
            title: track.name,
            artist: track.artist.name,
            thumbnailUrl: thumb,
            duration: dur,
          );
        }).toList();
      }
    } catch (e) {
      return [];
    }
  }
}
