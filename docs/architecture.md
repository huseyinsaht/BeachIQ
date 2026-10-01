# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`). Both screens from `docs/design.md` are now
implemented and wired to real data: the Home screen is a live weather/swim-suitability
dashboard with an interactive map, and the Search screen shows real nearby beaches
(from OpenStreetMap) enriched with marine data, favorites and unit preferences.

## Layers

### `lib/data/models`

Plain Dart data classes:

- `Beach` (`lib/data/models/beach.dart`) — `name`, `city`, `latitude`, `longitude`,
  plus OSM-derived fields: `surface`, `hasLifeguard`, `fee` (`BeachFee`: `free`/`paid`/
  `unknown`), the amenity flags `hasShower`/`hasToilets`/`hasChangingRoom`/
  `hasParking`/`hasCafe`/`hasBeachResort`, and an optional `geometry` (polygon/line
  points).
- `SeaCondition` (`lib/data/models/sea_condition.dart`) — `waveHeight`, `waveDirection`,
  `wavePeriod`, `seaSurfaceTemperature`, parsed from the Open-Meteo Marine API's
  `current` object.
- `WeatherCondition` (`lib/data/models/weather_condition.dart`) — `temperature`,
  `windSpeed`, `weatherCode`, plus `pressureHpa`, `uvIndex`, `rainChancePercent`,
  `highTemperature`/`lowTemperature` and a list of `WeatherHourly` entries (`time`,
  `temperature`, `weatherCode`), parsed from Open-Meteo's `current`/`hourly`/`daily`
  fields. Missing values stay `null` rather than being fabricated as zero.
- `WeatherCode` (`lib/data/models/weather_code.dart`) — maps Open-Meteo's numeric WMO
  weather code to a human-readable description (`weatherCodeDescription`).

### `lib/data/mappers`

- `mapOverpassToBeaches` (`lib/data/mappers/osm_beach_mapper.dart`) — turns a raw
  Overpass JSON response into `Beach` objects: groups `natural=beach` ways/nodes,
  merges adjoining ways that represent the same physical beach (union-find over a 30m
  distance threshold), and attaches nearby amenity elements (showers, toilets,
  changing rooms, parking, cafés, lifeguards, beach resorts) to the nearest beach
  within 150m.

### `lib/data/static_beaches.dart`

A hardcoded `List<Beach>` of 10 Turkish beaches. Used as the Search screen's
placeholder data when no `NearbyBeachesProvider` is supplied, and as `BeachCache`'s
offline fallback (filtered to a radius) when a live Overpass fetch fails and nothing
is cached yet.

### `lib/data/services`

- `MarineApiService` (`lib/data/services/api_service.dart`) — single-location
  Open-Meteo Marine API call (`wave_height,sea_surface_temperature,wave_period,
  wave_direction`), used by `MarineRepository`/`MarineProvider` for the Home screen.
- `WeatherApiService` (`lib/data/services/weather_api_service.dart`) — calls the
  Open-Meteo Forecast API for `current` (`temperature_2m,wind_speed_10m,weather_code`),
  `hourly` (`temperature_2m,weather_code,uv_index,precipitation_probability,
  pressure_msl`) and `daily` (`temperature_2m_max,temperature_2m_min`) fields.
- `MarineBatchService` (`lib/data/services/marine_batch_service.dart`) — fetches wave
  height and sea surface temperature for many beach coordinates in a single
  multi-location Open-Meteo Marine request (comma-separated `latitude`/`longitude`),
  with a 1-hour in-memory cache keyed by the sorted coordinate list. Used by
  `NearbyBeachesProvider` instead of `MarineApiService`.
- `buildNearbyBeachesQuery` (`lib/data/services/overpass_query_builder.dart`) — a pure
  function building the Overpass QL query for beaches (`natural=beach`, full geometry)
  and nearby amenities within `radiusMeters` (default 20000) of a point.
- `OverpassService` (`lib/data/services/overpass_service.dart`) — executes an Overpass
  QL query against the public Overpass API. Tries a primary endpoint then a fallback
  mirror; retries HTTP 429/504 with bounded exponential backoff; de-duplicates
  concurrent calls for the same query string so only one HTTP request is made.

### `lib/data/repositories`

- `MarineRepository` (`lib/data/repositories/marine_repository.dart`) — wraps
  `MarineApiService`, turns the response's `current` object into a `SeaCondition`.
  Throws a descriptive exception if `current` is missing or malformed.
- `WeatherRepository` (`lib/data/repositories/weather_repository.dart`) — wraps
  `WeatherApiService`, turns the response into a `WeatherCondition`. Same error
  handling shape as `MarineRepository`.
- `BeachRepository` (`lib/data/repositories/beach_repository.dart`) — returns
  `staticBeaches` from `getBeaches()`. Not used by either screen directly any more
  (Search gets its real list from `NearbyBeachesProvider`, falling back to
  `staticBeaches` itself when no provider is supplied); kept as a stable interface.

### `lib/data/services/beach_cache.dart`

`BeachCache` — a persistent (`SharedPreferences`-backed) cache of OSM beach query
results, keyed by a coarse grid cell (`gridSize` degrees, default 0.25°) so nearby
picks share a cache entry. Each entry has a 7-day TTL; an expired entry is still
returned immediately (stale-while-revalidate) with `isStale: true`, letting the caller
trigger a background `refresh()`. When nothing is cached and the live fetch fails,
falls back to `staticBeaches` filtered to `fallbackRadiusKm` (default 100km) and marks
the result `isFallback: true`.

### `lib/logic`

Pure, platform-agnostic logic with no I/O:

- `scoreSwimSuitability` (`lib/logic/swim_suitability.dart`) — scores wave height, wind
  speed and rain chance (each optional) into a `SwimVerdict` (`good`/`caution`/`poor`/
  `unknown`) with a one-line message, used by the Home screen's suggestion pill.
  `unknown` only when every input is missing.
- `ConditionAlertService` (`lib/logic/condition_alert_service.dart`) — decides whether
  a "conditions turned favorable" alert should fire on a verdict transition (only on
  not-good → good). Pure trigger logic only: nothing in the app yet schedules a
  background check or shows a real notification, so this isn't wired to any delivery
  mechanism.
- `adviseOnShoes` (`lib/logic/beach_gear_advisor.dart`) — advises `advised`/
  `notNeeded`/`unknown` on bringing shoes/slippers, from a beach's OSM `surface` tag.
  Framed as advice, never as a fact.
- `lib/logic/unit_preferences.dart` — the `UnitSystem` enum (`metric`/`imperial`) and
  conversion/formatting helpers (`formatWaveHeight`, `formatTemperature`,
  `formatWindSpeed`, plus the raw `metersToFeet`/`celsiusToFahrenheit`/`kmhToMph`
  converters).

### `lib/logic/providers`

- `MarineProvider` (`lib/logic/providers/marine_provider.dart`) — a `ChangeNotifier`
  exposing `currentData` (`SeaCondition?`), `isLoading`, `error`. `fetchData(lat, lon)`
  calls `MarineRepository.getMarineData`. On the Home screen this is only triggered by
  pull-to-refresh (see below), not on initial load.
- `WeatherProvider` (`lib/logic/providers/weather_provider.dart`) — same shape as
  `MarineProvider`, wrapping `WeatherRepository.getWeatherData`. Fetched for the fixed
  Çeşme coordinates as soon as the Home screen mounts.
- `FavoritesProvider` (`lib/logic/providers/favorites_provider.dart`) — persists the
  set of favorited beaches via `SharedPreferences`, keyed by `"name|city"` (beaches
  have no stable id). `toggleFavorite`/`isFavorite`/`favoritesAmong`.
- `UnitPreferencesProvider` (`lib/logic/providers/unit_preferences_provider.dart`) —
  holds and persists the user's `UnitSystem` choice via `SharedPreferences`, defaulting
  to metric.
- `NearbyBeachesProvider` (`lib/logic/providers/nearby_beaches_provider.dart`) — the
  glue for a single picked map location: `pickLocation(point)` debounces (400ms
  default) then resolves beaches via `BeachCache` (which only calls `OverpassService`
  on a cache miss/stale entry), and enriches them with marine data in one
  `MarineBatchService.fetchBatch` call. Exposes `beaches`, `seaConditionFor(beach)`,
  `isLoading`, `error`, and a `status` (`idle`/`loading`/`loaded`/`empty`/`error`).
  Guards against races from rapid picks and against calling `notifyListeners()` after
  disposal.

### `lib/presentation/widgets`

Reusable widgets built against `docs/design.md`:

- `StatTile` (`stat_tile.dart`) — icon + label + bold value + trend indicator, used in
  the Home screen's 2×2 stat grid.
- `HourlyForecastItem` (`hourly_forecast_item.dart`) — time label + weather icon + bold
  temperature, used in the Home screen's scrollable hourly row.
- `SearchField` (`search_field.dart`) — the rounded "paper" search input.
- `LocationMapCard` (`location_map_card.dart`) — the rounded "paper" map card: a real
  `FlutterMap` (OpenStreetMap tiles), a docked bottom location bar. When given a
  `NearbyBeachesProvider`, the map becomes interactive: tapping it calls
  `pickLocation`, draws a 20km search-radius circle around the pick, and renders the
  resulting beaches as gold polygons/lines (capped at 40 overlays, nearest-first) via
  `PolygonLayer`/`PolylineLayer`. Includes an `OsmAttribution` credit in the
  bottom-left corner.
- `OsmAttribution` (`osm_attribution.dart`) — a small "© OpenStreetMap contributors"
  credit required by OSM's ODbL license, tapping it opens the OSM copyright page.
- `SwimSuggestionPill` (`swim_suggestion_pill.dart`) — renders a `SwimVerdict` (from
  `scoreSwimSuitability`) as the Home screen's "smart suggestion pill".
- `BeachResultCard` (`beach_result_card.dart`) — the Search screen's result-sheet row:
  beach name/subtitle, a weather icon/temperature, a favorite-toggle heart (when a
  callback is supplied), and — once any beach info is supplied — a two-column block of
  plain-text info lines (entry fee, wave height, water temperature, shoe advice, car
  park, beach club, café). Unit-aware via `UnitSystem`. Every field renders "No data"/
  "Unknown" rather than inventing a value when the source has none.

### `lib/presentation/screens`

- `SearchScreen` (`lib/presentation/screens/search_screen.dart`) — composed from
  `SearchField` + a `BeachResultCard` list. Backed by `NearbyBeachesProvider.beaches`
  when supplied, else `staticBeaches`. Filters the list by name/city substring as the
  user types, and (when a `FavoritesProvider` is supplied) to favorites-only via a
  header star toggle. Shows `NearbyBeachesProvider`'s loading/error states. Supports
  pull-to-refresh via an injected `onRefresh` callback.

### `lib/main.dart`

- `main()` — initializes Flutter bindings, loads `SharedPreferences`, creates one
  shared `http.Client`, builds a `NearbyBeachesProvider` (`OverpassService` +
  `BeachCache` + `MarineBatchService`) and a `UnitPreferencesProvider`, and runs
  `MarineApp` with both.
- `MarineApp` — the root widget. Creates `MarineProvider`/`WeatherProvider` via
  `MultiProvider`/`ChangeNotifierProvider` and hosts `HomeScreen` inside a
  `MaterialApp`, forwarding the `UnitPreferencesProvider`/`NearbyBeachesProvider`
  passed into `main()`. Every optional provider defaults to `null`, so existing widget
  tests that construct `MarineApp` without them still render the pre-wiring layout.
- `HomeScreen` — the real dashboard: a header (place name, live temperature), a
  condition row (description, high/low), `LocationMapCard`, a tappable (non-editable)
  `SearchField` that pushes `SearchScreen`, `SwimSuggestionPill`, the 2×2 `StatTile`
  grid (wind speed, rain chance, pressure, UV index — all from `WeatherProvider`), and
  the hourly forecast row (trimmed to the next 24 entries from "now"). Shows a
  full-screen loading spinner or error message (driven by `MarineProvider`) before the
  first successful load; pull-to-refresh re-fetches both `MarineProvider` and
  `WeatherProvider` without tearing down the screen.

## State flow

On mount, `HomeScreen` calls `WeatherProvider.fetchData` and
`NearbyBeachesProvider.pickLocation` for the fixed Çeşme coordinates (post-frame, to
avoid notifying an ancestor mid-build). `WeatherProvider`/`MarineProvider` are
`ChangeNotifier`s updated through their repository → service → Open-Meteo API chain;
`HomeScreen` listens to both (plus `UnitPreferencesProvider`) and rebuilds on change.
`MarineProvider.fetchData` is **not** called on initial load — only on pull-to-refresh
— so `SwimSuggestionPill`'s wave-height input is typically absent until the user
refreshes once; `MarineProvider` is otherwise used for the initial loading/error shell.

`NearbyBeachesProvider.pickLocation` (debounced) resolves beaches via `BeachCache` →
`OverpassService` → the Overpass API, maps them with `mapOverpassToBeaches`, then
enriches them with a single `MarineBatchService` call; it notifies `LocationMapCard`
(which redraws the beach overlay) and, once the user opens `SearchScreen`, that screen
too. Tapping the map calls `pickLocation` again with the tapped point.
`FavoritesProvider` and `UnitPreferencesProvider` are each created once SharedPreferences
is available and persist across restarts.

## External APIs

- **Open-Meteo Marine API** (`marine-api.open-meteo.com/v1/marine`) — single-location
  sea condition data (`MarineApiService`, Home screen) and a batched multi-location
  variant (`MarineBatchService`, nearby-beaches results).
- **Open-Meteo Forecast API** (`api.open-meteo.com/v1/forecast`) — current/hourly/daily
  temperature, wind, pressure, UV index and rain chance, used by `WeatherApiService`.
- **Overpass API** (OpenStreetMap data, with a fallback mirror) — queried by
  `OverpassService` with `buildNearbyBeachesQuery`'s query, for beaches and nearby
  amenities around a picked point.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) — used by `flutter_map` in
  `HomeScreen`'s `LocationMapCard`; credited via the `OsmAttribution` widget as
  required by OSM's ODbL license.

## Tests

- `flutter test` — unit tests for models, mappers, services, repositories
  (`test/data/`), pure logic (`test/logic/swim_suitability_test.dart`,
  `condition_alert_service_test.dart`, `beach_gear_advisor_test.dart`,
  `unit_preferences_test.dart`), provider tests (`test/logic/providers/`, including
  `NearbyBeachesProvider`/`FavoritesProvider`/`UnitPreferencesProvider`/
  `MarineProvider`/`WeatherProvider`), widget tests for every presentational widget and
  for `SearchScreen` (`test/presentation/`), plus `test/widget_test.dart` rendering
  `HomeScreen` with a fake tile provider. API/service tests fake `http.Client` so none
  hit the network.
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree with a fake tile provider and a fixture `http.Client`
  (covering Overpass and the marine batch endpoint) and checks: the app boots with
  `MarineProvider` clean; Home-to-Search navigation (search entry → `SearchScreen`,
  back chevron → `HomeScreen`); and the full nearby-beaches flow (pick on boot → real
  `BeachResultCard` fields from the fixture data). CI runs this on Linux under a
  virtual display: `xvfb-run -a flutter test integration_test -d linux --reporter
  expanded`.
