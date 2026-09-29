# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`) currently in early development: the code lays
out data models, a repository/service layer for marine and weather conditions, and a
growing set of presentational widgets matching `docs/design.md`, but only one screen is
wired up so far, and it does not yet consume any of that data or render any of those
widgets.

## Layers

### `lib/data/models`

Plain Dart data classes:

- `Beach` (`lib/data/models/beach.dart`) — `name`, `city`, `latitude`, `longitude`.
- `SeaCondition` (`lib/data/models/sea_condition.dart`) — `waveHeight`, `waveDirection`,
  `wavePeriod`, `seaSurfaceTemperature`. `SeaCondition.fromJson` parses the Open-Meteo
  Marine API's `current` object.
- `WeatherCondition` (`lib/data/models/weather_condition.dart`) — `temperature`,
  `windSpeed`, `weatherCode`, parsed from Open-Meteo forecast fields (`temperature_2m`,
  `wind_speed_10m`, `weather_code`). Fetched by `WeatherApiService`/`WeatherRepository`,
  but not yet consumed by any provider-driven screen.

### `lib/data/static_beaches.dart`

A hardcoded `List<Beach>` of 10 Turkish beaches, used as placeholder data until a real
beach data source exists. Returned by `BeachRepository`; not yet rendered by any screen.

### `lib/data/services`

- `MarineApiService` (`lib/data/services/api_service.dart`) — calls the Open-Meteo
  Marine API (`https://marine-api.open-meteo.com/v1/marine`) for
  `wave_height,sea_surface_temperature,wave_period,wave_direction` at a given
  latitude/longitude. Throws on a non-200 response or a network error.
- `WeatherApiService` (`lib/data/services/weather_api_service.dart`) — calls the
  Open-Meteo Forecast API (`https://api.open-meteo.com/v1/forecast`) for
  `temperature_2m,wind_speed_10m,weather_code` at a given latitude/longitude. Same
  200/error handling shape as `MarineApiService`.
- `buildNearbyBeachesQuery` (`lib/data/services/overpass_query_builder.dart`) — a pure
  function (no network, no I/O) that builds the Overpass QL query for finding beaches
  (`natural=beach`, with full geometry) and nearby amenities — showers, toilets,
  changing rooms, parking, cafés, lifeguards, beach resorts — within `radiusMeters`
  (default 20000) of a point. Nothing calls the Overpass API with this query yet; there
  is no `OverpassService`.

### `lib/data/repositories`

- `MarineRepository` (`lib/data/repositories/marine_repository.dart`) — wraps
  `MarineApiService`, pulls the response's `current` object, and turns it into a
  `SeaCondition`. Throws a descriptive exception if `current` is missing or not a map.
- `WeatherRepository` (`lib/data/repositories/weather_repository.dart`) — wraps
  `WeatherApiService`, pulls the response's `current` object, and turns it into a
  `WeatherCondition`. Same shape and error handling as `MarineRepository`.
- `BeachRepository` (`lib/data/repositories/beach_repository.dart`) — returns
  `staticBeaches` from `getBeaches()`. A placeholder so callers don't need to change
  once a real beach data API exists.

### `lib/logic/providers`

- `MarineProvider` (`lib/logic/providers/marine_provider.dart`) — a `ChangeNotifier`
  exposing `currentData` (`SeaCondition?`), `isLoading`, and `error`. `fetchData(lat,
  lon)` calls `MarineRepository.getMarineData` and notifies listeners before and after.
  Nothing in the UI calls `fetchData` yet.
- `WeatherProvider` (`lib/logic/providers/weather_provider.dart`) — the same
  loading/data/error `ChangeNotifier` shape as `MarineProvider`, wrapping
  `WeatherRepository.getWeatherData`. Not created or provided anywhere in `main.dart`.

### `lib/presentation/widgets`

Pure presentational widgets built against `docs/design.md`'s home/search screens. None
of them are referenced from `lib/main.dart` yet — each is exercised only by its own
widget tests:

- `StatTile` (`stat_tile.dart`) — icon + label + bold value + up/down trend indicator,
  for the home screen's 2×2 stat grid (wind speed, rain chance, pressure, UV index).
- `HourlyForecastItem` (`hourly_forecast_item.dart`) — time label + weather icon + bold
  temperature, for the horizontally scrollable hourly forecast row.
- `SearchField` (`search_field.dart`) — a rounded "paper" search input with a leading
  search icon and `onChanged`/`onSubmitted` callbacks, for city search.
- `LocationMapCard` (`location_map_card.dart`) — the rounded "paper" map card (a real
  `FlutterMap`, optionally overridable `TileProvider`) with a docked bottom bar (pin
  icon, bold place name, overflow menu).

### UI (`lib/main.dart`)

- `MarineApp` — the root widget. Creates one `MarineProvider` (backed by a real
  `MarineRepository`/`MarineApiService`) via `ChangeNotifierProvider` and hosts
  `HomeScreen` inside a `MaterialApp`.
- `HomeScreen` — currently renders a single `FlutterMap` (OpenStreetMap tiles, initial
  center near the Turkish Aegean coast). It does not yet read from `MarineProvider` or
  `WeatherProvider`, show beach data, or use any of the `lib/presentation/widgets`
  components described in `docs/design.md`.

## State flow

`MarineProvider` is provided once at the app root via `provider`. Once a screen calls
`fetchData(lat, lon)`, the provider requests data through `MarineRepository` →
`MarineApiService` → the Open-Meteo Marine API, updates `currentData` / `isLoading` /
`error`, and notifies listeners via `ChangeNotifier`. No screen currently triggers this
flow — the provider is wired into the widget tree but idle. `WeatherProvider` follows
the identical pattern through `WeatherRepository`/`WeatherApiService`, but isn't created
or provided anywhere yet, so it has no state flow in the running app at all.

## External APIs

- **Open-Meteo Marine API** (`marine-api.open-meteo.com/v1/marine`) — sea condition
  data, used by `MarineApiService`.
- **Open-Meteo Forecast API** (`api.open-meteo.com/v1/forecast`) — current
  temperature/wind speed/weather code, used by `WeatherApiService`.
- **Overpass API** (OpenStreetMap data) — `buildNearbyBeachesQuery` builds the query
  string for it, but no service calls the API yet.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) — used directly by `flutter_map`
  in `HomeScreen` and in `LocationMapCard`.

## Tests

- `flutter test` — unit tests for the models, services, and repositories
  (`test/data/models`, `test/data/services`, `test/data/repositories`), provider tests
  (`test/logic/providers`), widget tests for each presentational widget
  (`test/presentation/widgets`), plus a widget test (`test/widget_test.dart`) that
  renders `HomeScreen` with a fake tile provider to avoid real network calls. The API
  service tests fake `http.Client` so none of them hit the network.
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree and checks the home screen and map come up with
  `MarineProvider` in a clean state (`isLoading: false`, `error: null`). CI runs this on
  Linux under a virtual display: `xvfb-run -a flutter test integration_test -d linux
  --reporter expanded`.
