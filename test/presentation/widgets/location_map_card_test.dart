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
        expect(find.text('Cafe'), findsOneWidget);
        expect(find.text('Parking'), findsOneWidget);
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
      await tester.tap(find.byType(AmenityMarker));
      await tester.pump();

      expect(find.textContaining('Fixture Cafe'), findsOneWidget);
    });
  });
}
