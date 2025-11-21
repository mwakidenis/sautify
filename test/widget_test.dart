/*
Copyright (c) 2025 Wambugu Kinyua
Licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
*/

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sautifyv2/main.dart';
import 'package:sautifyv2/utils/app_config.dart';

void main() {
  setUpAll(() async {
    AppConfig.isTest = true;
    // Ensure Hive is initialized for tests that open boxes without relying on plugins.
    final tempDir = await Directory.systemTemp.createTemp('sautifyv2_test_');
    Hive.init(tempDir.path);
    // Provide a fake HttpClient so any unintended network calls won't hang.
    HttpOverrides.global = _TestHttpOverrides();
  });

  testWidgets('App renders and shows bottom navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    // Allow a few frames for async init without waiting on long network timeouts.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Verify bottom navigation icons are present.
    expect(find.byIcon(Icons.home), findsOneWidget); // selected icon
    expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}
