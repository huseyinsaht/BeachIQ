import 'dart:convert';

import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/presentation/widgets/amenity_legend.dart';
import 'package:beachiq/presentation/widgets/amenity_marker.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_http_client.dart';

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

SharedPreferences? _mockPrefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _mockPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('renders without hitting the network', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: const LatLng(38.3, 26.3),
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('shows the place name and pin icon in the docked bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationMapCard(
            center: const LatLng(38.3, 26.3),
            placeName: 'Cesme, Izmir',
            tileProvider: _FakeTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cesme, Izmir'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  group('shouldShowAmenityMarkers', () {
    test('below kAmenityMarkersMinZoom, returns false', () {
      expect(shouldShowAmenityMarkers(kAmenityMarkersMinZoom - 0.1), isFalse);
    });

    test('at or above kAmenityMarkersMinZoom, returns true', () {
      expect(shouldShowAmenityMarkers(kAmenityMarkersMinZoom), isTrue);
      expect(shouldShowAmenityMarkers(kAmenityMarkersMinZoom + 2), isTrue);
    });
  });

  group('amenity markers (issue #172)', () {
    const center = LatLng(38.3220, 26.3260);

    NearbyBeachesProvider buildFixtureProvider() {
      final client = FakeHttpClient();
      client.queueResponse(
        host: 'marine-api.open-meteo.com',
        body: json.encode([
          {
            'current': {
              'wave_height': 0.5,
              'wave_direction': 90,
              'wave_period': 4,
              'sea_surface_temperature': 23.0,
            },
          },
        ]),
      );
      client.queueResponse(
        host: 'overpass-api.de',
        body: json.encode({
          'elements': [
            {
              'type': 'way',
              'id': 1,
              'tags': {'natural': 'beach', 'name': 'Fixture Beach'},
              'geometry': [
                {'lat': 38.3220, 'lon': 26.3260},
                {'lat': 38.3230, 'lon': 26.3260},
                {'lat': 38.3230, 'lon': 26.3270},
              ],
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 38.32205,
              'lon': 26.3261,
              'tags': {'amenity': 'cafe', 'name': 'Fixture Cafe'},
            },
            {
              'type': 'node',
              'id': 3,
              'lat': 38.32210,
              'lon': 26.3262,
              'tags': {'amenity': 'parking'},
            },
          ],
        }),
      );

      return NearbyBeachesProvider(
        OverpassService(client),
        BeachCache(_mockPrefs!),
        MarineBatchService(client),
        debounceDuration: const Duration(milliseconds: 1),
      );
    }

    /// A single beach with a single amenity — used only for the tap test
    /// below, so the tapped marker is unambiguous (two real amenities
    /// close enough together to both attach to one beach can render close
    /// enough on screen, at this map's fixed zoom, to visually overlap).
    NearbyBeachesProvider buildSingleAmenityFixtureProvider() {
      final client = FakeHttpClient();
      client.queueResponse(
        host: 'marine-api.open-meteo.com',
        body: json.encode([
          {
            'current': {
              'wave_height': 0.5,
              'wave_direction': 90,
              'wave_period': 4,
              'sea_surface_temperature': 23.0,
            },
          },
        ]),
      );
      client.queueResponse(
        host: 'overpass-api.de',
        body: json.encode({
          'elements': [
            {
              'type': 'way',
              'id': 1,
              'tags': {'natural': 'beach', 'name': 'Fixture Beach'},
              'geometry': [
                {'lat': 38.3220, 'lon': 26.3260},
                {'lat': 38.3230, 'lon': 26.3260},
                {'lat': 38.3230, 'lon': 26.3270},
              ],
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 38.32205,
              'lon': 26.3261,
              'tags': {'amenity': 'cafe', 'name': 'Fixture Cafe'},
            },
          ],
        }),
      );

      return NearbyBeachesProvider(
        OverpassService(client),
        BeachCache(_mockPrefs!),
        MarineBatchService(client),
        debounceDuration: const Duration(milliseconds: 1),
      );
    }

    testWidgets(
      'each amenity of a beach inside the radius appears as its own marker',
      (tester) async {
        final provider = buildFixtureProvider();
        addTearDown(provider.dispose);

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
        provider.pickLocation(center);
        await tester.pumpAndSettle();

        expect(provider.beaches, hasLength(1));
        expect(provider.beaches.single.amenities, hasLength(2));
        expect(find.byType(AmenityMarker), findsNWidgets(2));
        expect(find.byType(AmenityLegend), findsOneWidget);
        // Marker labels can show the same text as the legend chips (e.g.
        // "Parking" has no OSM name, so its pin label falls back to the
        // kind label too), so scope these to the legend specifically.
        final legend = find.byType(AmenityLegend);
        expect(
          find.descendant(of: legend, matching: find.text('Cafe')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: legend, matching: find.text('Parking')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'each marker shows a short name-or-kind label under its pin at the '
      "map's default (beach) zoom, per the owner's Google-Maps-style note",
      (tester) async {
        final provider = buildSingleAmenityFixtureProvider();
        addTearDown(provider.dispose);

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
        provider.pickLocation(center);
        await tester.pumpAndSettle();

        // Default zoom (13.0, per _initialZoom) is above
        // kAmenityMarkersMinZoom, so the label is already visible without
        // any zoom gesture or marker tap.
        expect(find.byType(AmenityMarker), findsOneWidget);
        final marker = tester.widget<AmenityMarker>(find.byType(AmenityMarker));
        expect(marker.showLabel, isTrue);
        expect(find.text('Fixture Cafe'), findsOneWidget);
      },
    );

    testWidgets('toggling a legend chip hides and reshows that kind', (
      tester,
    ) async {
      final provider = buildFixtureProvider();
      addTearDown(provider.dispose);

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
      provider.pickLocation(center);
      await tester.pumpAndSettle();

      expect(find.byType(AmenityMarker), findsNWidgets(2));

      await tester.tap(find.text('Cafe'));
      await tester.pump();

      expect(find.byType(AmenityMarker), findsNWidgets(1));

      await tester.tap(find.text('Cafe'));
      await tester.pump();

      expect(find.byType(AmenityMarker), findsNWidgets(2));
    });

    testWidgets('tapping a marker shows a label with its name and kind', (
      tester,
    ) async {
      final provider = buildSingleAmenityFixtureProvider();
      addTearDown(provider.dispose);

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
      provider.pickLocation(center);
      await tester.pumpAndSettle();

      expect(find.byType(AmenityMarker), findsOneWidget);
      // The pin itself already shows a "Fixture Cafe" label (#172's "label
      // at beach zoom" requirement); the selected card's text is the more
      // specific "name · kind" combination, so assert on that exact string
      // rather than a substring match that the pin's own label would also
      // satisfy.
      await tester.tap(find.byType(AmenityMarker));
      await tester.pump();

      expect(find.text('Fixture Cafe · Cafe'), findsOneWidget);
    });
  });

  group('beachBoundsToFit (#214)', () {
    test('a null beach -> null', () {
      expect(beachBoundsToFit(null), isNull);
    });

    test('a beach with no geometry -> null', () {
      expect(beachBoundsToFit(aBeach(geometry: null)), isNull);
    });

    test('a beach with a single-point geometry -> null', () {
      expect(
        beachBoundsToFit(aBeach(geometry: const [LatLng(38.3, 26.3)])),
        isNull,
      );
    });

    test('a beach with a 2-point geometry -> its bounding box', () {
      const points = [LatLng(38.30, 26.30), LatLng(38.31, 26.32)];
      final bounds = beachBoundsToFit(aBeach(geometry: points));

      expect(bounds, isNotNull);
      expect(bounds!.south, 38.30);
      expect(bounds.north, 38.31);
      expect(bounds.west, 26.30);
      expect(bounds.east, 26.32);
    });

    test('a beach with a 3+ point geometry -> its bounding box', () {
      const points = [
        LatLng(38.30, 26.30),
        LatLng(38.31, 26.30),
        LatLng(38.31, 26.31),
      ];
      final bounds = beachBoundsToFit(aBeach(geometry: points));

      expect(bounds, isNotNull);
      expect(bounds!.south, 38.30);
      expect(bounds.north, 38.31);
      expect(bounds.west, 26.30);
      expect(bounds.east, 26.31);
    });
  });

  group('camera follows center/selectedBeach (#214)', () {
    testWidgets(
      'given a center change from outside, the camera moves there at a zoom '
      'that keeps amenity markers visible',
      (tester) async {
        final controller = MapController();
        addTearDown(controller.dispose);

        Future<void> pump(LatLng center) {
          return tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LocationMapCard(
                  center: center,
                  placeName: 'Cesme, Izmir',
                  tileProvider: _FakeTileProvider(),
                  mapController: controller,
                ),
              ),
            ),
          );
        }

        await pump(const LatLng(38.3, 26.3));
        await tester.pump();

        const newCenter = LatLng(37.03, 27.43);
        await pump(newCenter);
        // The camera move is deferred to a post-frame callback (#214's own
        // doc comment explains why); pumpAndSettle lets that callback and
        // the resulting rebuild both run.
        await tester.pumpAndSettle();

        expect(controller.camera.center.latitude, closeTo(37.03, 0.0001));
        expect(controller.camera.center.longitude, closeTo(27.43, 0.0001));
        expect(
          controller.camera.zoom,
          greaterThanOrEqualTo(kAmenityMarkersMinZoom),
        );
      },
    );

    testWidgets(
      'given a selectedBeach with geometry, the camera fits its bounds '
      'instead of just centering on the picked point',
      (tester) async {
        final controller = MapController();
        addTearDown(controller.dispose);
        const center = LatLng(38.3, 26.3);
        final beach = aBeach(
          geometry: const [LatLng(38.40, 26.40), LatLng(38.42, 26.44)],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                mapController: controller,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Fixture Beach',
                tileProvider: _FakeTileProvider(),
                mapController: controller,
                selectedBeach: beach,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fitting to the beach's own geometry bounds lands the camera near
        // that geometry, not at `center` (which is nowhere close to it) —
        // the distinguishing behavior from the plain "move to point" path
        // above.
        expect(
          controller.camera.center.latitude,
          inInclusiveRange(38.40, 38.42),
        );
        expect(
          controller.camera.center.longitude,
          inInclusiveRange(26.40, 26.44),
        );
      },
    );
  });

  group('selected-beach highlight (#214)', () {
    const center = LatLng(38.3, 26.3);

    Future<NearbyBeachesProvider> loadedProviderWithTwoBeaches(
      WidgetTester tester,
    ) async {
      final client = FakeHttpClient()
        ..queueJson(
          host: 'overpass-api.de',
          json: {
            'elements': [
              {
                'type': 'way',
                'id': 1,
                'tags': {'natural': 'beach', 'name': 'Fixture Beach'},
                'geometry': [
                  {'lat': 38.30, 'lon': 26.30},
                  {'lat': 38.31, 'lon': 26.30},
                  {'lat': 38.31, 'lon': 26.31},
                ],
              },
              {
                'type': 'way',
                'id': 2,
                'tags': {'natural': 'beach', 'name': 'Other Beach'},
                'geometry': [
                  {'lat': 38.40, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.41},
                ],
              },
            ],
          },
        )
        ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[]);
      final provider = NearbyBeachesProvider(
        OverpassService(client),
        BeachCache(_mockPrefs!),
        MarineBatchService(client),
        debounceDuration: const Duration(milliseconds: 1),
      );
      provider.pickLocation(center);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      return provider;
    }

    testWidgets(
      'the selected beach gets a white, thicker-stroked polygon; the other '
      'beach keeps the plain gold outline',
      (tester) async {
        final provider = await loadedProviderWithTwoBeaches(tester);
        addTearDown(provider.dispose);
        final selected = provider.beaches.firstWhere(
          (b) => b.name == 'Fixture Beach',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationMapCard(
                center: center,
                placeName: 'Cesme, Izmir',
                tileProvider: _FakeTileProvider(),
                nearbyBeachesProvider: provider,
                selectedBeach: selected,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final polygonLayer = tester.widget<PolygonLayer>(
          find.byType(PolygonLayer),
        );
        expect(polygonLayer.polygons, hasLength(2));

        final selectedPolygon = polygonLayer.polygons.firstWhere(
          (p) => p.points.first.latitude == 38.30,
        );
        final otherPolygon = polygonLayer.polygons.firstWhere(
          (p) => p.points.first.latitude == 38.40,
        );

        expect(selectedPolygon.borderColor, Colors.white);
        expect(selectedPolygon.borderStrokeWidth, 4);
        expect(otherPolygon.borderColor, isNot(Colors.white));
        expect(otherPolygon.borderStrokeWidth, 2);
      },
    );

    testWidgets(
      'no selectedBeach -> every beach keeps the plain gold outline',
      (tester) async {
        final provider = await loadedProviderWithTwoBeaches(tester);
        addTearDown(provider.dispose);

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
        await tester.pumpAndSettle();

        final polygonLayer = tester.widget<PolygonLayer>(
          find.byType(PolygonLayer),
        );
        for (final polygon in polygonLayer.polygons) {
          expect(polygon.borderColor, isNot(Colors.white));
          expect(polygon.borderStrokeWidth, 2);
        }
      },
    );
  });
}
