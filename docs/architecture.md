# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`) currently in early development: the code lays
out data models and a repository/service layer for marine conditions, but only one
screen exists so far, and it does not yet consume that data.

## Layers

### `lib/data/models`

Plain Dart data classes:

- `Beach` (`lib/data/models/beach.dart`) — `name`, `city`, `latitude`, `longitude`.
- `SeaCondition` (`lib/data/models/sea_condition.dart`) — `waveHeight`, `waveDirection`,
  `wavePeriod`, `seaSurfaceTemperature`. `SeaCondition.fromJson` parses the Open-Meteo
  Marine API's `current` object.
- `WeatherCondition` (`lib/data/models/weather_condition.dart`) — `temperature`,
  `windSpeed`, `weatherCode`, parsed from Open-Meteo forecast fields (`temperature_2m`,
  `wind_speed_10m`, `weather_code`). Not yet consumed by any service, repository, or
  provider.

### `lib/data/static_beaches.dart`

A hardcoded `List<Beach>` of 10 Turkish beaches, used as placeholder data until a real
beach data source exists. Not yet rendered by any screen.

### `lib/data/services`

- `MarineApiService` (`lib/data/services/api_service.dart`) — calls the Open-Meteo
  Marine API (`https://marine-api.open-meteo.com/v1/marine`) for
  `wave_height,sea_surface_temperature,wave_period,wave_direction` at a given
  latitude/longitude. Throws on a non-200 response or a network error.

### `lib/data/repositories`

- `MarineRepository` (`lib/data/repositories/marine_repository.dart`) — wraps
  `MarineApiService`, pulls the response's `current` object, and turns it into a
  `SeaCondition`. Throws a descriptive exception if `current` is missing or not a map.

### `lib/logic/providers`

- `MarineProvider` (`lib/logic/providers/marine_provider.dart`) — a `ChangeNotifier`
  exposing `currentData` (`SeaCondition?`), `isLoading`, and `error`. `fetchData(lat,
  lon)` calls `MarineRepository.getMarineData` and notifies listeners before and after.
  Nothing in the UI calls `fetchData` yet.

### UI (`lib/main.dart`)

- `MarineApp` — the root widget. Creates one `MarineProvider` (backed by a real
  `MarineRepository`/`MarineApiService`) via `ChangeNotifierProvider` and hosts
  `HomeScreen` inside a `MaterialApp`.
- `HomeScreen` — currently renders a single `FlutterMap` (OpenStreetMap tiles, initial
  center near the Turkish Aegean coast). It does not yet read from `MarineProvider`,
  show beach data, or implement the screens described in `docs/design.md`.

## State flow

`MarineProvider` is provided once at the app root via `provider`. Once a screen calls
`fetchData(lat, lon)`, the provider requests data through `MarineRepository` →
`MarineApiService` → the Open-Meteo Marine API, updates `currentData` / `isLoading` /
`error`, and notifies listeners via `ChangeNotifier`. No screen currently triggers this
flow — the provider is wired into the widget tree but idle.

## External APIs

- **Open-Meteo Marine API** (`marine-api.open-meteo.com/v1/marine`) — sea condition
  data, used by `MarineApiService`.
- **Open-Meteo forecast API** — the field names in `WeatherCondition.fromJson` match
  Open-Meteo's forecast API, but no service calls it yet.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) — used directly by `flutter_map`
  in `HomeScreen`.

## Tests

- `flutter test` — unit tests for the models and repository (`test/data/models`,
  `test/data/repositories`), plus a widget test (`test/widget_test.dart`) that renders
  `HomeScreen` with a fake tile provider to avoid real network calls.
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree and checks the home screen and map come up with
  `MarineProvider` in a clean state (`isLoading: false`, `error: null`). CI runs this on
  Linux under a virtual display: `xvfb-run -a flutter test integration_test -d linux
  --reporter expanded`.
