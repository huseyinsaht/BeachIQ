import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/osm_attribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_client.dart';

// Minimal valid 1x1 transparent PNG, used so the fake tile provider can
// resolve a real image without any network access (same trick as
// `location_map_card_test.dart`).
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

/// An [http.Client] that fails any request made through it. The fake
/// provider below overrides [NearbyBeachesProvider.pickLocation] so the
/// underlying services are never actually exercised, but valid instances
/// are still required to construct the provider.
class _NeverClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('No network access expected in this test');
  }
}

Future<BeachCache> _emptyBeachCache() async {
  SharedPreferences.setMockInitialValues({});
  return BeachCache(await SharedPreferences.getInstance());
}

/// A [NearbyBeachesProvider] whose [pickLocation] just records the call
/// (instead of debouncing and hitting Overpass), and whose [beaches]/
/// [status] are driven directly by the test.
class _FakeNearbyBeachesProvider extends NearbyBeachesProvider {
  _FakeNearbyBeachesProvider(
    super.overpassService,
    super.beachCache,
    super.marineBatchService,
  );

  LatLng? lastPickedPoint;
  int pickLocationCallCount = 0;

  List<Beach> fakeBeaches = const [];
  NearbyBeachesStatus fakeStatus = NearbyBeachesStatus.idle;

  @override
  void pickLocation(LatLng point) {
    lastPickedPoint = point;
    pickLocationCallCount++;
  }

  @override
  List<Beach> get beaches => fakeBeaches;

  @override
  NearbyBeachesStatus get status => fakeStatus;

  void setBeaches(
    List<Beach> beaches, {
    NearbyBeachesStatus status = NearbyBeachesStatus.loaded,
  }) {
    fakeBeaches = beaches;
    fakeStatus = status;
    notifyListeners();
  }
}

Future<_FakeNearbyBeachesProvider> _fakeProvider() async {
  final overpassService = OverpassService(_NeverClient());
  final beachCache = await _emptyBeachCache();
  final marineBatchService = MarineBatchService(_NeverClient());
  return _FakeNearbyBeachesProvider(
    overpassService,
    beachCache,
    marineBatchService,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const center = LatLng(38.3, 26.3);

  testWidgets('tapping the map calls pickLocation with the tapped coordinate', (
    tester,
  ) async {
    final provider = await _fakeProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: center,
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
            nearbyBeachesProvider: provider,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tapping the widget's own center taps the map's visual center, which
    // (with no panning yet) sits at `initialCenter`. flutter_map delays a
    // single tap by `PositionedTapDetector2`'s double-tap window (250ms,
    // since double-tap-to-zoom is also wired up) before firing `onTap`, so
    // the pump has to advance past that.
    await tester.tap(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 300));

    expect(provider.pickLocationCallCount, 1);
    expect(provider.lastPickedPoint, isNotNull);
    expect(provider.lastPickedPoint!.latitude, closeTo(center.latitude, 0.05));
    expect(
      provider.lastPickedPoint!.longitude,
      closeTo(center.longitude, 0.05),
    );
  });

  testWidgets('the circle layer radius matches the 20km constant', (
    tester,
  ) async {
    final provider = await _fakeProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: center,
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
            nearbyBeachesProvider: provider,
          ),
        ),
      ),
    );
    await tester.pump();

    final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circleLayer.circles, hasLength(1));
    expect(circleLayer.circles.single.radius, kNearbyBeachesRadiusMeters);
    expect(circleLayer.circles.single.useRadiusInMeter, isTrue);
  });

  testWidgets('beach geometry renders as gold polygons and lines', (
    tester,
  ) async {
    final provider = await _fakeProvider();
    provider.setBeaches([
      Beach(
        name: 'Polygon Beach',
        city: 'Cesme',
        latitude: 38.31,
        longitude: 26.31,
        geometry: const [
          LatLng(38.30, 26.30),
          LatLng(38.31, 26.30),
          LatLng(38.31, 26.31),
          LatLng(38.30, 26.30),
        ],
      ),
      Beach(
        name: 'Line Beach',
        city: 'Cesme',
        latitude: 38.32,
        longitude: 26.32,
        geometry: const [LatLng(38.32, 26.32), LatLng(38.33, 26.33)],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: center,
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
            nearbyBeachesProvider: provider,
          ),
        ),
      ),
    );
    await tester.pump();

    final polygonLayer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(polygonLayer.polygons, hasLength(1));
    expect(polygonLayer.polygons.single.borderColor, const Color(0xFFC9A227));

    final polylineLayer = tester.widget<PolylineLayer>(
      find.byType(PolylineLayer),
    );
    expect(polylineLayer.polylines, hasLength(1));
    expect(polylineLayer.polylines.single.color, const Color(0xFFC9A227));
  });

  testWidgets(
    'falls back to the last non-empty beach list when a later fetch errors out empty',
    (tester) async {
      final provider = await _fakeProvider();
      final beach = Beach(
        name: 'Line Beach',
        city: 'Cesme',
        latitude: 38.32,
        longitude: 26.32,
        geometry: const [LatLng(38.32, 26.32), LatLng(38.33, 26.33)],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: center,
              placeName: 'Cesme, Izmir',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
            ),
          ),
        ),
      );
      await tester.pump();

      // A successful pick with data.
      provider.setBeaches([beach]);
      await tester.pump();
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        hasLength(1),
      );

      // A later fetch errors out with nothing: the previous data stays on
      // screen instead of leaving the map blank.
      provider.setBeaches(const [], status: NearbyBeachesStatus.error);
      await tester.pump();
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        hasLength(1),
      );

      // A later fetch that is merely empty (not an error) clears the
      // overlay rather than keeping stale data forever.
      provider.setBeaches(const [], status: NearbyBeachesStatus.loaded);
      await tester.pump();
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        isEmpty,
      );
    },
  );

  testWidgets(
    'individual beach overlays are capped at kMaxRenderedBeachOverlays',
    (tester) async {
      final provider = await _fakeProvider();
      provider.setBeaches([
        for (var i = 0; i < kMaxRenderedBeachOverlays + 10; i++)
          Beach(
            name: 'Beach $i',
            city: 'Cesme',
            latitude: 38.3 + i * 0.001,
            longitude: 26.3,
            geometry: [
              LatLng(38.3 + i * 0.001, 26.3),
              LatLng(38.3 + i * 0.001, 26.301),
            ],
          ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: center,
              placeName: 'Cesme, Izmir',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
            ),
          ),
        ),
      );
      await tester.pump();

      final polylineLayer = tester.widget<PolylineLayer>(
        find.byType(PolylineLayer),
      );
      expect(polylineLayer.polylines, hasLength(kMaxRenderedBeachOverlays));
    },
  );

  testWidgets(
    'a center change resets the picked point back to the new center',
    (tester) async {
      final provider = await _fakeProvider();
      const otherCenter = LatLng(40.0, 29.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: center,
              placeName: 'Cesme, Izmir',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
            ),
          ),
        ),
      );
      await tester.pump();

      // Pick a point away from the initial center.
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 300));
      var circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      final pickedLat = circleLayer.circles.single.point.latitude;
      expect(pickedLat, closeTo(center.latitude, 0.05));

      // Changing `center` (e.g. the user searched a new place) resets the
      // circle back to the new center rather than keeping the old pick.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: otherCenter,
              placeName: 'Istanbul',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
            ),
          ),
        ),
      );
      await tester.pump();

      circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      expect(circleLayer.circles.single.point, otherCenter);
    },
  );

  testWidgets('OsmAttribution is visible on the map card', (tester) async {
    final provider = await _fakeProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: center,
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
            nearbyBeachesProvider: provider,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(OsmAttribution), findsOneWidget);
  });

  group('place search (issue #158)', () {
    testWidgets('given no placeSearchProvider, the search icon is not shown', (
      tester,
    ) async {
      final provider = await _fakeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: center,
              placeName: 'Cesme, Izmir',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('map-search-toggle')), findsNothing);
    });

    testWidgets('tapping the search icon reveals the field, and a second tap '
        'collapses it', (tester) async {
      final provider = await _fakeProvider();
      final placeSearchProvider = PlaceSearchProvider(
        GeocodingService(FakeHttpClient()),
      );
      addTearDown(placeSearchProvider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationMapCard(
              center: center,
              placeName: 'Cesme, Izmir',
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: provider,
              placeSearchProvider: placeSearchProvider,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('map-search-field-bar')), findsNothing);
      expect(find.text('Cesme, Izmir'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-toggle')));
      await tester.pump();

      expect(find.byKey(const Key('map-search-field-bar')), findsOneWidget);
      expect(find.text('Cesme, Izmir'), findsNothing);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pump();

      expect(find.byKey(const Key('map-search-field-bar')), findsNothing);
      expect(find.text('Cesme, Izmir'), findsOneWidget);
    });

    testWidgets(
      'typing shows a loading indicator, then the real geocoding results',
      (tester) async {
        final provider = await _fakeProvider();
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
              ],
            },
            delay: const Duration(milliseconds: 20),
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                nearbyBeachesProvider: provider,
                placeSearchProvider: placeSearchProvider,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('map-search-toggle')));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'bodrum');
        await tester.pump(const Duration(milliseconds: 2));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 25));

        expect(
          find.byKey(const ValueKey('map-search-result-0-Bodrum')),
          findsOneWidget,
        );
        expect(find.text('Bodrum'), findsOneWidget);
      },
    );

    testWidgets(
      'given no matching places, typing a query -> shows an empty message',
      (tester) async {
        final provider = await _fakeProvider();
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {'results': <Object?>[]},
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                nearbyBeachesProvider: provider,
                placeSearchProvider: placeSearchProvider,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('map-search-toggle')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'nowhereville');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(find.textContaining('No places match'), findsOneWidget);
      },
    );

    testWidgets(
      'given a failed search, typing a query -> shows an error message',
      (tester) async {
        final provider = await _fakeProvider();
        final client = FakeHttpClient()
          ..queueResponse(
            host: 'geocoding-api.open-meteo.com',
            body: 'Service Unavailable',
            statusCode: 503,
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                nearbyBeachesProvider: provider,
                placeSearchProvider: placeSearchProvider,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('map-search-toggle')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'bodrum');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(
          find.text('Could not search for places. Please try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selecting a result recenters the map, collapses the search and '
      'triggers the same flow as a map pick',
      (tester) async {
        final provider = await _fakeProvider();
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
              ],
            },
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        LatLng? pickedPoint;
        String? pickedName;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                nearbyBeachesProvider: provider,
                placeSearchProvider: placeSearchProvider,
                onLocationPicked: (point, name) {
                  pickedPoint = point;
                  pickedName = name;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('map-search-toggle')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'bodrum');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey('map-search-result-0-Bodrum')),
        );
        await tester.pump();

        // Recenters the map (never the formatted-coordinates fallback —
        // the real looked-up name) and triggers the same flow a map tap
        // would: pickLocation plus onLocationPicked.
        expect(provider.pickLocationCallCount, 1);
        expect(provider.lastPickedPoint?.latitude, closeTo(37.03, 0.001));
        expect(provider.lastPickedPoint?.longitude, closeTo(27.43, 0.001));
        expect(pickedPoint?.latitude, closeTo(37.03, 0.001));
        expect(pickedName, 'Bodrum');

        final circleLayer = tester.widget<CircleLayer>(
          find.byType(CircleLayer),
        );
        expect(
          circleLayer.circles.single.point.latitude,
          closeTo(37.03, 0.001),
        );

        // The search collapses back to the normal location bar.
        expect(find.byKey(const Key('map-search-field-bar')), findsNothing);
        expect(find.text('Cesme, Izmir'), findsOneWidget);
      },
    );
  });
}
