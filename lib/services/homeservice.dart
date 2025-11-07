/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/foundation.dart';
import 'package:sautifyv2/models/home/home.dart';
import 'package:sautifyv2/services/connectivity_service.dart';
import 'package:sautifyv2/services/home_service.dart';

class HomeScreenService implements HomeService {
  final YTMusic ytmusic = YTMusic();
  bool _isLoading = false;
  HomeData? _homeData;
  static const Duration _netTimeout = Duration(seconds: 6);

  @override
  Future<void> getHomeSections() async {
    _isLoading = true;
    try {
      // Fast-fail when offline to avoid indefinite hangs and skeletons
      final offline = !ConnectivityService().isOnline$.value;
      if (offline) {
        throw Exception('Offline');
      }

      // Apply a short timeout so we surface an error instead of hanging
      List<dynamic> rawSections = await ytmusic.getHomeSections().timeout(
        _netTimeout,
      );
      _homeData = HomeData.fromYTMusicSections(rawSections);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching home sections: $e');
      }
      _homeData = null;
      // Rethrow so upstream can surface a user-visible error instead of
      // keeping a skeleton loading state forever when offline.
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  @override
  Future<void> initialize() async {
    try {
      // If offline, skip heavy init and return quickly
      final offline = !ConnectivityService().isOnline$.value;
      if (offline) return;

      // Add a timeout to avoid blocking on launch when network is slow/down
      await ytmusic.initialize().timeout(_netTimeout);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing YTMusic: $e');
      }
    }
  }

  @override
  HomeData? get homeData => _homeData;

  @override
  bool get isLoading => _isLoading;
}
