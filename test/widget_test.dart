import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/main.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/hourly_forecast_item.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/stat_tile.dart';

// Minimal valid 1x1 transparent PNG, used so the fake tile provider can
// resolve a real image without any network access.
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

/// A [MarineRepository] whose response never resolves, so tests can inspect
/// the UI while a fetch is still in flight.
class _PendingMarineRepository extends MarineRepository {
  _PendingMarineRepository() : super(MarineApiService());

  final Completer<SeaCondition> completer = Completer<SeaCondition>();

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) =>
      completer.future;
}

class _FailingMarineRepository extends MarineRepository {
  _FailingMarineRepository(this._message) : super(MarineApiService());

  final String _message;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    throw Exception(_message);
  }
}

class _CountingMarineRepository extends MarineRepository {
  _CountingMarineRepository() : super(MarineApiService());

  int callCount = 0;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    callCount++;
    return SeaCondition(
      waveHeight: 0.5,
      waveDirection: 90,
      wavePeriod: 5,
      seaSurfaceTemperature: 22,
    );
  }
}

class _SucceedingMarineRepository extends MarineRepository {
  _SucceedingMarineRepository() : super(MarineApiService());

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    return SeaCondition(
      waveHeight: 0.5,
      waveDirection: 90,
      wavePeriod: 5,
      seaSurfaceTemperature: 22,
    );
  }
}

void main() {
  testWidgets('HomeScreen renders the composed location-detail layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('My Location'), findsOneWidget);
    expect(find.byType(LocationMapCard), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(4));
    expect(find.byType(HourlyForecastItem), findsWidgets);
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('HomeScreen shows a loading indicator while marine data loads', (
    WidgetTester tester,
  ) async {
    final repository = _PendingMarineRepository();
    final provider = MarineProvider(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          marineProvider: provider,
        ),
      ),
    );
    await tester.pump();

    unawaited(provider.fetchData(38.3, 26.3));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('My Location'), findsNothing);

    // Resolve the pending fetch so no future is left dangling past the test.
    repository.completer.complete(
      SeaCondition(
        waveHeight: 0.5,
        waveDirection: 90,
        wavePeriod: 5,
        seaSurfaceTemperature: 22,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'HomeScreen shows a clear error message when marine data fails to load',
    (WidgetTester tester) async {
      final provider = MarineProvider(_FailingMarineRepository('boom'));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );
      await provider.fetchData(38.3, 26.3);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('My Location'), findsNothing);
      expect(find.textContaining('boom'), findsOneWidget);
    },
  );

  testWidgets(
    'HomeScreen shows the normal layout once marine data has loaded',
    (WidgetTester tester) async {
      final provider = MarineProvider(_SucceedingMarineRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );
      await provider.fetchData(38.3, 26.3);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('My Location'), findsOneWidget);
      expect(find.byType(StatTile), findsNWidgets(4));
    },
  );

  testWidgets(
    'a pull-to-refresh gesture on the Home screen re-triggers the marine fetch',
    (WidgetTester tester) async {
      final repository = _CountingMarineRepository();
      final provider = MarineProvider(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );
      await provider.fetchData(38.3, 26.3);
      await tester.pump();

      expect(repository.callCount, 1);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    },
  );

  testWidgets(
    'a pull-to-refresh gesture on the Home screen is a no-op with no MarineProvider',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
      );
      await tester.pump();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      expect(find.text('My Location'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the search entry point opens SearchScreen, and the back '
    'chevron returns to HomeScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
      );
      await tester.pump();

      expect(find.byType(SearchScreen), findsNothing);

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
    },
  );
}
