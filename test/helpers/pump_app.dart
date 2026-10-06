import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/bathymetry_service.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/depth_cache.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/depth_provider.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'builders.dart';
import 'fake_http_client.dart';

/// A minimal valid 1x1 transparent PNG, used so [FakeTileProvider] can
/// resolve a real image without any network access.
final _transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

/// A [TileProvider] that never touches the real OSM tile network, for any
/// widget test that renders `LocationMapCard`/`flutter_map`.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPixelPng);
  }
}

/// Pumps [child] inside a bare [MaterialApp] and settles — the minimal
/// shell most widget tests need, since screens already build their own
/// `Scaffold`/background.
Future<void> pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

/// A [MarineRepository] that resolves instantly to a fixed result instead
/// of calling the network.
class FakeMarineRepository extends MarineRepository {
  FakeMarineRepository({this.data, this.error}) : super(MarineApiService());

  final SeaCondition? data;
  final Object? error;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    if (error != null) throw error!;
    return data!;
  }
}

/// A [WeatherRepository] that resolves instantly to a fixed result instead
/// of calling the network.
class FakeWeatherRepository extends WeatherRepository {
  FakeWeatherRepository({this.data, this.error}) : super(WeatherApiService());

  final WeatherCondition? data;
  final Object? error;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    if (error != null) throw error!;
    return data!;
  }
}

/// Builds a [MarineProvider] whose [MarineProvider.currentData] is already
/// [data] (the fetch has already resolved), for a widget test that wants a
/// loaded Home screen without going through a real fetch.
Future<MarineProvider> aLoadedMarineProvider(SeaCondition data) async {
  final provider = MarineProvider(FakeMarineRepository(data: data));
  await provider.fetchData(0, 0);
  return provider;
}

/// Builds a [WeatherProvider] whose [WeatherProvider.currentData] is
/// already [data] (the fetch has already resolved).
Future<WeatherProvider> aLoadedWeatherProvider(WeatherCondition data) async {
  final provider = WeatherProvider(FakeWeatherRepository(data: data));
  await provider.fetchData(0, 0);
  return provider;
}

/// Builds a [NearbyBeachesProvider] wired to [client] (a [FakeHttpClient]
/// pre-queued with Overpass/marine-batch responses) and a throwaway
/// [SharedPreferences] instance, so a widget test gets tap-to-pick/search
/// wiring without any real network or persisted state leaking between
/// tests.
Future<NearbyBeachesProvider> fakeNearbyBeachesProvider({
  required FakeHttpClient client,
  Duration debounceDuration = const Duration(milliseconds: 1),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return NearbyBeachesProvider(
    OverpassService(client),
    BeachCache(prefs),
    MarineBatchService(client),
    debounceDuration: debounceDuration,
  );
}

/// A [BathymetryService] that resolves instantly to a fixed [DepthProfile]
/// instead of calling the network (issue #217), mirroring
/// [FakeMarineRepository]/[FakeWeatherRepository] above.
class FakeBathymetryService extends BathymetryService {
  FakeBathymetryService({this.profile}) : super(FakeHttpClient());

  final DepthProfile? profile;

  @override
  Future<DepthProfile> fetchProfile(Beach beach) async {
    return profile ?? const DepthProfile.unavailable();
  }
}

/// Builds a [DepthProvider] whose [DepthProvider.profile] is already
/// [profile] (the fetch has already resolved for a throwaway beach), for a
/// widget test that wants a loaded water-depth tile/detail screen without
/// going through a real transect/HTTP fetch.
Future<DepthProvider> aLoadedDepthProvider(DepthProfile profile) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final provider = DepthProvider(
    FakeBathymetryService(profile: profile),
    DepthCache(prefs),
  );
  await provider.fetchForBeach(aBeach());
  return provider;
}
