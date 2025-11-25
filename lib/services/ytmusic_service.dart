import 'dart:async';

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/foundation.dart';
import 'package:sautifyv2/services/connectivity_service.dart';
import 'package:sautifyv2/utils/app_config.dart';

/// Shared singleton wrapper around dart_ytmusic_api to:
/// - Deduplicate initialization across the app
/// - Apply short, bounded timeouts and light retry/backoff
/// - Offer convenience wrappers with per-call timeouts
class YTMusicService {
  YTMusicService._internal();
  static final YTMusicService instance = YTMusicService._internal();

  final YTMusic _ytmusic = YTMusic();
  Future<void>? _initFuture;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initialize the underlying client with timeout & minimal retries.
  /// Concurrent callers will await the same future.
  Future<void> initializeIfNeeded({
    Duration timeout = const Duration(seconds: 15),
    int retries = 3,
  }) async {
    if (_initialized) return;
    if (AppConfig.isTest) {
      // Skip network init entirely in tests.
      _initialized = true;
      return;
    }
    if (_initFuture != null) {
      return _initFuture; // ignore: void_checks
    }

    final offline = !ConnectivityService().isOnline$.value;
    if (offline) {
      throw TimeoutException('YTMusic init skipped: offline');
    }

    final completer = Completer<void>();
    _initFuture = completer.future;

    () async {
      try {
        int attempt = 0;
        while (true) {
          attempt++;
          try {
            await _ytmusic.initialize().timeout(timeout);
            _initialized = true;
            completer.complete();
            break;
          } on TimeoutException catch (e) {
            if (kDebugMode) {
              debugPrint('YTMusic init timeout (attempt $attempt): $e');
            }
            if (attempt > retries) rethrow;
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('YTMusic init error (attempt $attempt): $e');
            }
            // Retry on other errors too (like HttpException)
            if (attempt > retries) rethrow;
            await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        // If failed, allow future attempts; if succeeded, keep initialized flag.
        if (!_initialized) _initFuture = null;
      }
    }();

    return _initFuture; // ignore: void_checks
  }

  /// Wrappers with per-call timeout; assumes caller either initialized or allows lazy attempt.
  Future<List<dynamic>> getHomeSections({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 20),
        retries: 1,
      );
    }
    return _ytmusic.getHomeSections().timeout(timeout);
  }

  Future<List<String>> getSearchSuggestions(
    String q, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 15),
        retries: 1,
      );
    }
    final res = await _ytmusic.getSearchSuggestions(q).timeout(timeout);
    return List<String>.from(res.map((e) => e.toString()));
  }

  Future<List<dynamic>> searchSongs(
    String q, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 20),
        retries: 1,
      );
    }
    return _ytmusic.searchSongs(q).timeout(timeout);
  }

  Future<List<dynamic>> searchAlbums(
    String q, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 20),
        retries: 1,
      );
    }
    return _ytmusic.searchAlbums(q).timeout(timeout);
  }

  Future<dynamic> getAlbum(
    String albumId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 20),
        retries: 1,
      );
    }
    return _ytmusic.getAlbum(albumId).timeout(timeout);
  }

  Future<dynamic> getTimedLyrics(
    String videoId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      await initializeIfNeeded(
        timeout: const Duration(seconds: 20),
        retries: 1,
      );
    }
    return _ytmusic.getTimedLyrics(videoId).timeout(timeout);
  }
}
