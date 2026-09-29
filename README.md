# BeachIQ

A Flutter app that shows current weather and sea conditions for beaches, so you can decide whether
it's a good time to go swimming.

## APIs used

BeachIQ pulls data from two free, keyless [Open-Meteo](https://open-meteo.com/) endpoints — no API
key or account is required for local development.

### Open-Meteo Weather Forecast API

- Base URL: `https://api.open-meteo.com/v1/forecast`
- Used by: `lib/data/services/weather_api_service.dart` via `lib/data/repositories/weather_repository.dart`
- Provides: current weather (temperature, wind speed, weather code) for a given latitude/longitude —
  see `lib/data/models/weather_condition.dart`.

### Open-Meteo Marine Weather API

- Base URL: `https://marine-api.open-meteo.com/v1/marine`
- Used by: `lib/data/services/api_service.dart` via `lib/data/repositories/marine_repository.dart`
- Provides: sea state (wave height, wave direction, wave period, sea surface temperature) for a given
  latitude/longitude — see `lib/data/models/sea_condition.dart`.

Both services take an injectable `http.Client`, so tests fake the client instead of hitting the
network (see `test/data/services/`).

BeachIQ also queries the [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) (OSM data)
for nearby beaches; `lib/data/services/overpass_query_builder.dart` builds that query.

## Folder structure

```
lib/
  data/
    models/         # Plain data classes (Beach, SeaCondition, WeatherCondition)
    repositories/   # Fetch + adapt service responses for the UI/providers
    services/        # Thin HTTP clients for the Open-Meteo APIs
    static_beaches.dart
  logic/
    providers/       # ChangeNotifier providers exposing weather/marine state to the UI
  main.dart          # App entry point and screens

test/                # Unit/widget tests, mirroring the lib/ folder structure
integration_test/    # End-to-end integration tests
docs/                # Design reference (docs/design.md) and mockup assets
```

## Setup

1. Install a Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`'s
   `environment.sdk` (currently `^3.8.1`).
2. Fetch dependencies:
   ```
   flutter pub get
   ```
3. Run static analysis and tests:
   ```
   dart analyze
   flutter test
   ```
4. Run the app:
   ```
   flutter run
   ```

No API keys or `.env` file are needed — both Open-Meteo endpoints above are public and keyless.
