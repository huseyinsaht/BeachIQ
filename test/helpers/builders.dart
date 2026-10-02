/// Object builders for tests: each function returns a valid instance with
/// sensible defaults, so a test only has to name the field(s) it cares
/// about instead of filling in every constructor argument.
library;

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:latlong2/latlong.dart';

Beach aBeach({
  String name = 'Test Beach',
  String city = 'Test City',
  double latitude = 38.3,
  double longitude = 26.3,
  String? surface = 'sand',
  bool? hasLifeguard,
  BeachFee fee = BeachFee.unknown,
  bool hasShower = false,
  bool hasToilets = false,
  bool hasChangingRoom = false,
  bool hasParking = false,
  bool hasCafe = false,
  bool hasBeachResort = false,
  List<LatLng>? geometry,
  List<BeachAmenity> amenities = const [],
}) {
  return Beach(
    name: name,
    city: city,
    latitude: latitude,
    longitude: longitude,
    surface: surface,
    hasLifeguard: hasLifeguard,
    fee: fee,
    hasShower: hasShower,
    hasToilets: hasToilets,
    hasChangingRoom: hasChangingRoom,
    hasParking: hasParking,
    hasCafe: hasCafe,
    hasBeachResort: hasBeachResort,
    geometry: geometry,
    amenities: amenities,
  );
}

BeachAmenity anAmenity({
  AmenityKind kind = AmenityKind.toilets,
  LatLng position = const LatLng(38.3, 26.3),
  String? name,
}) {
  return BeachAmenity(kind: kind, position: position, name: name);
}

SeaCondition aSeaCondition({
  double waveHeight = 0.8,
  double waveDirection = 180,
  double wavePeriod = 5,
  double seaSurfaceTemperature = 24.0,
}) {
  return SeaCondition(
    waveHeight: waveHeight,
    waveDirection: waveDirection,
    wavePeriod: wavePeriod,
    seaSurfaceTemperature: seaSurfaceTemperature,
  );
}

WeatherCondition aWeatherCondition({
  double temperature = 28.0,
  double windSpeed = 12.0,
  int weatherCode = 0,
  double? pressureHpa,
  double? uvIndex,
  double? rainChancePercent,
  double? highTemperature,
  double? lowTemperature,
  List<WeatherHourly> hourly = const [],
}) {
  return WeatherCondition(
    temperature: temperature,
    windSpeed: windSpeed,
    weatherCode: weatherCode,
    pressureHpa: pressureHpa,
    uvIndex: uvIndex,
    rainChancePercent: rainChancePercent,
    highTemperature: highTemperature,
    lowTemperature: lowTemperature,
    hourly: hourly,
  );
}

WeatherHourly aWeatherHourly({
  required DateTime time,
  double temperature = 28.0,
  int weatherCode = 0,
  double? windSpeed,
  double? windGusts,
  double? cloudCoverPercent,
  double? pressureHpa,
}) {
  return WeatherHourly(
    time: time,
    temperature: temperature,
    weatherCode: weatherCode,
    windSpeed: windSpeed,
    windGusts: windGusts,
    cloudCoverPercent: cloudCoverPercent,
    pressureHpa: pressureHpa,
  );
}
