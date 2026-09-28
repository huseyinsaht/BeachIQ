import 'dart:convert';

import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

// Minimal valid 1x1 transparent PNG so map tiles resolve without network.
final _transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPixelPng);
  }
}

/// App-level smoke test: boots the real widget tree (MarineApp with its
/// provider) on a device/emulator and checks the home screen comes up.
/// Extend this file whenever a PR adds or changes a screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots, provides MarineProvider and shows the map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MarineApp(tileProvider: _FakeTileProvider()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    final context = tester.element(find.byType(HomeScreen));
    final provider = Provider.of<MarineProvider>(context, listen: false);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });
}
