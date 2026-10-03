# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`). Both screens from `docs/design.md` are now
implemented and wired to real data: the Home screen is a live weather/sea-conditions/
swim-suitability dashboard with an interactive map (beach outlines and amenity markers)
and per-metric detail screens, and the Search screen shows real nearby beaches (from
OpenStreetMap) and real place-name search results, enriched with marine data, favorites
and unit preferences.

## Layers

### `lib/data/models`

Plain Dart data classes:

- `Beach` (`lib/data/models/beach.dart`) — `name`, `city`, `latitude`, `longitude`,
  plus OSM-derived fields: `surface`, `hasLifeguard`, `fee` (`BeachFee`: `free`/`paid`/
  `unknown`), the amenity flags `hasShower`/`hasToilets`/`hasChangingRoom`/
  `hasParking`/`hasCafe`/`hasBeachResort`, an optional `geometry` (polygon/line
  points), and `amenities` (a `List<BeachAmenity>` — the same amenities as the boolean
  flags, but with their own real map position each).
- `BeachAmenity` (`lib/data/models/beach_amenity.dart`) — a single real-world amenity
  (`AmenityKind`: `toilets`/`shower`/`changingRoom`/`parking`/`cafe`/`beachResort`/
  `lifeguard`) with its OSM position and optional `name`. Unlike `Beach`'s boolean
  `has...` flags (which only say "at least one of this kind exists nearby"), this
  carries where each one actually is, for the map's amenity markers.
- `Place` (`lib/data/models/place.dart`) — a geocoding search result: `name`, optional
  `admin1`/`country`, `latitude`, `longitude`. `Place.tryFromJson` returns `null`
  (rather than throwing) for an entry missing a required field, so one malformed
  result doesn't fail a whole search.
- `SeaCondition` (`lib/data/models/sea_condition.dart`) — `waveHeight`, `waveDirection`,
  `wavePeriod`, `seaSurfaceTemperature`, `currentVelocity` (ocean current speed in
  km/h — Open-Meteo's `ocean_current_velocity` needs no unit conversion, see the
  field's doc comment for how this was verified), `currentDirection` (degrees,
  oceanographic "flowing toward" convention — the opposite of `waveDirection`'s
  meteorological "coming from" convention), and `hourly` (a `List<SeaHourly>`, the
  same five fields per hour), parsed from the Open-Meteo Marine API's `current`/
  `hourly` objects. Every field but a `SeaHourly`'s `time` is nullable, so "no data"
  is never confused with a real zero.
- `WeatherCondition` (`lib/data/models/weather_condition.dart`) — `temperature`,
  `windSpeed`, `weatherCode`, plus `pressureHpa`, `uvIndex`, `rainChancePercent`,
  `highTemperature`/`lowTemperature` and a list of `WeatherHourly` entries (`time`,
  `temperature`, `weatherCode`, plus nullable `windSpeed`, `windGusts`,
  `cloudCoverPercent`, `rainChancePercent`, `pressureHpa`), parsed from Open-Meteo's
  `current`/`hourly`/`daily` fields. Missing values stay `null` rather than being
  fabricated as zero.
- `WeatherCode` (`lib/data/models/weather_code.dart`) — maps Open-Meteo's numeric WMO
  weather code to a human-readable description (`weatherCodeDescription`).

### `lib/data/mappers`

- `mapOverpassToBeaches` (`lib/data/mappers/osm_beach_mapper.dart`) — turns a raw
  Overpass JSON response into `Beach` objects: groups `natural=beach` ways/nodes,
  merges adjoining ways that represent the same physical beach (union-find over a 30m
  distance threshold), and attaches nearby amenity elements (showers, toilets,
  changing rooms, parking, cafés, lifeguards, beach resorts) — both as a boolean flag
  and as a `BeachAmenity` with its real position — to the nearest beach within 150m.

### `lib/data/static_beaches.dart`

A hardcoded `List<Beach>` of 10 Turkish beaches. Used as the Search screen's
placeholder data when no `NearbyBeachesProvider` is supplied, and as `BeachCache`'s
offline fallback (filtered to a radius) when a live Overpass fetch fails and nothing
is cached yet.

### `lib/data/services`

- `MarineApiService` (`lib/data/services/api_service.dart`) — single-location
  Open-Meteo Marine API call (`wave_height,sea_surface_temperature,wave_period,
  wave_direction,ocean_current_velocity,ocean_current_direction`, plus their hourly
  equivalents), used by `MarineRepository`/`MarineProvider` for the Home screen.
- `WeatherApiService` (`lib/data/services/weather_api_service.dart`) — calls the
  Open-Meteo Forecast API for `current` (`temperature_2m,wind_speed_10m,weather_code`),
  `hourly` (`temperature_2m,weather_code,uv_index,precipitation_probability,
  pressure_msl,wind_speed_10m,wind_gusts_10m,cloud_cover`) and `daily`
  (`temperature_2m_max,temperature_2m_min`) fields.
- `MarineBatchService` (`lib/data/services/marine_batch_service.dart`) — fetches wave
  height and sea surface temperature for many beach coordinates in a single
  multi-location Open-Meteo Marine request (comma-separated `latitude`/`longitude`),
  with a 1-hour in-memory cache keyed by the sorted coordinate list. Used by
  `NearbyBeachesProvider` instead of `MarineApiService`.
- `GeocodingService` (`lib/data/services/geocoding_service.dart`) — calls the free,
  keyless Open-Meteo Geocoding API (`geocoding-api.open-meteo.com/v1/search`) to look
  up places by name. A query shorter than 2 characters short-circuits to `[]` with no
  request. Used by `PlaceSearchProvider`.
- `buildNearbyBeachesQuery` (`lib/data/services/overpass_query_builder.dart`) — a pure
  function building the Overpass QL query for beaches (`natural=beach`, full geometry)
  and nearby amenities within `radiusMeters` (default 20000) of a point.
- `OverpassService` (`lib/data/services/overpass_service.dart`) — executes an Overpass
  QL query against the public Overpass API. Tries a primary endpoint then a fallback
  mirror; retries HTTP 429/504 with bounded exponential backoff; de-duplicates
  concurrent calls for the same query string so only one HTTP request is made.

### `lib/data/repositories`

- `MarineRepository` (`lib/data/repositories/marine_repository.dart`) — wraps
  `MarineApiService`, turns the response's `current`/`hourly` objects into a
  `SeaCondition`. Throws a descriptive exception if `current` is missing or
  malformed.
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
  `unknown` only when every input is missing. Also defines the moderate/high
  thresholds (`moderateWindSpeedKmh`, `highWaveHeightM`, etc.) that
  `forecast_alerts.dart` reuses so the two never disagree about what "windy" or
  "rough" means.
- `ConditionAlertService` (`lib/logic/condition_alert_service.dart`) — decides whether
  a "conditions turned favorable" alert should fire on a verdict transition (only on
  not-good → good). Pure trigger logic only: nothing in the app yet schedules a
  background check or shows a real notification, so this isn't wired to any delivery
  mechanism.
- `buildForecastAlerts` (`lib/logic/forecast_alerts.dart`) — a pure function producing
  `ForecastAlert`s (wind/waves/clouds/rain/current) from hourly weather and sea data:
  a rule fires on a fast rise (wind, waves, current) within a 2-hour window or on
  crossing a moderate/high threshold (wind, waves, rain — reusing
  `swim_suitability.dart`'s thresholds), or on the weather code moving from
  clear/partly-cloudy into overcast/rain/thunderstorm (clouds). Adjacent triggered
  hours are merged into one alert window. The current rule only covers "speed rises"
  — the owner's "current turns away from shore" half needs
  `wave_shore_relation.dart`'s classifier plus a beach's shore bearing, not wired up
  here. **Not yet surfaced anywhere in the UI** — see `docs/features.md`.
- `classifyPressureTrend` (`lib/logic/pressure_trend.dart`) — classifies a pressure
  reading as `rising`/`steady`/`falling` against an earlier one (>= 1 hPa change
  either way is a trend, matching the ~1 hPa/3h "rapid change" meteorological
  convention), with `pressureTrendLabel`/`pressureTrendExplanation` for the Pressure
  detail screen's copy. `null` ("not enough data") is distinct from `steady`.
- `seawardBearingFromGeometry`/`classifyDirection`
  (`lib/logic/wave_shore_relation.dart`) — derives a beach's seaward-pointing bearing
  from its OSM geometry and amenities (a heuristic: land-side amenities are assumed to
  cluster away from the water, so "away from the amenities' average position, toward
  the geometry centroid" approximates the seaward direction — see the function's doc
  comment for its limitations), then classifies a current's or wave's direction of
  travel as `towardShore`/`awayFromShore`/`alongShore` relative to it (within 45° of
  the seaward/landward normal counts as away/toward; the rest is along-shore). Used by
  the Home screen's Sea section to flag a current or wave heading out to sea.
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
- `PlaceSearchProvider` (`lib/logic/providers/place_search_provider.dart`) — drives a
  place-search-by-name UI: debounces (400ms default) `search(query)` calls against
  `GeocodingService` and exposes `results`, `isLoading`, `error`, and a `status`
  (`idle`/`loading`/`loaded`/`empty`/`error`), following the same request-id/debounce/
  disposal-guard pattern as `NearbyBeachesProvider`. A blank query clears immediately
  with no debounce or network call.

### `lib/presentation/widgets`

Reusable widgets built against `docs/design.md`:

- `StatTile` (`stat_tile.dart`) — icon + label + bold value + trend indicator, used in
  the Home screen's 2×2 stat grid. Optionally `onTap` (used by the Pressure tile to
  open its detail screen).
- `HourlyForecastItem` (`hourly_forecast_item.dart`) — time label + colored weather
  icon (day/night variant chosen from the entry's own `time`, not the device clock) +
  bold temperature, used in the Home screen's scrollable hourly row.
- `SearchField` (`search_field.dart`) — the rounded "paper" search input.
- `LocationMapCard` (`location_map_card.dart`) — the rounded "paper" map card: a real
  `FlutterMap` (OpenStreetMap tiles), a docked bottom location bar. When given a
  `NearbyBeachesProvider`, the map becomes interactive: tapping it calls
  `pickLocation`, draws a 20km search-radius circle around the pick, and renders the
  resulting beaches as gold polygons/lines (capped at 40 overlays, nearest-first) via
  `PolygonLayer`/`PolylineLayer`. At zoom >= 12 (`kAmenityMarkersMinZoom`), each
  visible beach's amenities are drawn as `AmenityMarker` pins (hidden below that zoom
  to avoid visual noise), with an `AmenityLegend` toggle row and a tap-to-select info
  card showing the amenity's name/kind and distance from the pick. Includes an
  `OsmAttribution` credit in the bottom-left corner.
- `AmenityMarker`/`amenityColor`/`amenityIcon`/`amenityLabel`
  (`amenity_marker.dart`) — a single colored circular pin per `AmenityKind` (orange
  cafe, blue toilets/shower/changing room, blue-grey "P" parking, teal beach club, red
  lifeguard), optionally showing a short name/kind label underneath at close zoom, and
  growing/brightening when selected.
- `AmenityLegend` (`amenity_legend.dart`) — a horizontally scrollable row of toggle
  chips, one per amenity kind actually present on the map; tapping one hides/shows
  that kind's markers.
- `OsmAttribution` (`osm_attribution.dart`) — a small "© OpenStreetMap contributors"
  credit required by OSM's ODbL license, tapping it opens the OSM copyright page.
- `SwimSuggestionPill` (`swim_suggestion_pill.dart`) — renders a `SwimVerdict` (from
  `scoreSwimSuitability`) as the Home screen's "smart suggestion pill", colored per
  `verdict_palette.dart`'s `paletteForVerdict` (green/orange/red-orange/neutral grey,
  each contrast-checked against WCAG AA).
- `SeaConditionsRow` (`sea_conditions_row.dart`) — the Home screen's "Sea" section
  under the suggestion pill: wave height, water temperature, wave direction, current
  speed and current direction, read from `MarineProvider.currentData`. When a
  `seawardBearingDegrees` is supplied (the nearest beach's shore bearing, from
  `wave_shore_relation.dart`), the direction tiles also show a toward/away/along-shore
  label, with "away from shore" shown as a bold warning. Renders nothing when no sea
  data has loaded yet; any individual missing field shows "No data".
- `BeachResultCard` (`beach_result_card.dart`) — the Search screen's result-sheet row:
  beach name/subtitle, a weather icon/temperature, a favorite-toggle heart (when a
  callback is supplied), and — once any beach info is supplied — a two-column block of
  plain-text info lines (entry fee, wave height, water temperature, shoe advice, car
  park, beach club, café). Unit-aware via `UnitSystem`. Every field renders "No data"/
  "Unknown" rather than inventing a value when the source has none.
- `MetricDetailScaffold` (`metric_detail_scaffold.dart`) — the shared layout for every
  per-metric detail screen (Pressure today; UV index/rain chance/wind/wave height/
  water temperature/current are tracked follow-ups, see `docs/features.md`): a back
  button + title, a hero value with optional unit/trend line, a chart slot, a min/now/
  max summary row, and an explanation paragraph.
- `HourlyMetricChart` (`hourly_metric_chart.dart`) — a reusable hourly line chart
  (`CustomPaint`-based, no charting package) for the metric detail screens: a "Now"
  marker, optional horizontal threshold lines, an optional filled area band, and gaps
  (never a fabricated zero) wherever an hour's value is `null`.

### `lib/presentation/theme`

- `verdict_palette.dart` — `paletteForVerdict(SwimSuitabilityLevel)`, the pure mapping
  from a swim verdict to its `VerdictPalette` (gradient + foreground color + icon) used
  by `SwimSuggestionPill`.

### `lib/presentation/navigation`

- `detail_routes.dart` — `buildDetailRoute(DetailMetric metric, ...)` builds the
  `MaterialPageRoute` (named `/detail/<metric>`) for a tapped Home stat tile. Only
  `DetailMetric.pressure` is wired to a real screen (`PressureDetailScreen`); the other
  `DetailMetric` values (`uvIndex`, `rainChance`, `wind`, `waveHeight`,
  `waterTemperature`, `current`) throw `UnimplementedError` until their own screens
  land.

### `lib/presentation/screens`

- `HomeScreen` (`lib/presentation/screens/home_screen.dart`) — the real dashboard: a
  header (place name, live temperature), a condition row (description, high/low),
  `LocationMapCard`, a tappable (non-editable) `SearchField` that pushes
  `SearchScreen`, `SwimSuggestionPill`, the `SeaConditionsRow` (once marine data has
  loaded), the 2×2 `StatTile` grid (wind speed, rain chance, pressure — tappable to
  `PressureDetailScreen`, UV index — all from `WeatherProvider`), and the hourly
  forecast row (trimmed to the next 24 entries from "now"). Shows a full-screen
  loading spinner or error message (driven by `MarineProvider`) before the first
  successful load; pull-to-refresh re-fetches both `MarineProvider` and
  `WeatherProvider` without tearing down the screen. Also derives the nearest beach to
  the fixed location (by real distance — `NearbyBeachesProvider.beaches` is in
  Overpass element-id order, not distance order) and that beach's seaward bearing, fed
  into `SeaConditionsRow` for its shore-relation labels.
- `SearchScreen` (`lib/presentation/screens/search_screen.dart`) — composed from
  `SearchField` + a `BeachResultCard` list. Backed by `NearbyBeachesProvider.beaches`
  when supplied, else `staticBeaches`. Filters the list by name/city substring as the
  user types, and (when a `FavoritesProvider` is supplied) to favorites-only via a
  header star toggle. When a `PlaceSearchProvider` is supplied, typing also shows a
  "Places" section (any place by name, not just nearby/static beaches) above the beach
  list; tapping a place re-centers `NearbyBeachesProvider` on it. Shows
  `NearbyBeachesProvider`'s loading/error states. Supports pull-to-refresh via an
  injected `onRefresh` callback.
- `PressureDetailScreen` (`lib/presentation/screens/detail/pressure_detail_screen.dart`)
  — the day's hourly sea-level pressure as an `HourlyMetricChart` with a "Now" marker
  and a low-pressure threshold line, a min/max/now summary, and a rising/steady/
  falling trend (`classifyPressureTrend`, comparing "now" to 3 hours earlier). Pushed
  from `HomeScreen`'s pressure `StatTile` via `buildDetailRoute`.

### `lib/main.dart`

- `main()` — initializes Flutter bindings, loads `SharedPreferences`, creates one
  shared `http.Client`, builds a `NearbyBeachesProvider` (`OverpassService` +
  `BeachCache` + `MarineBatchService`), a `UnitPreferencesProvider`, and a
  `PlaceSearchProvider` (`GeocodingService`), and runs `MarineApp` with all three.
- `MarineApp` — the root widget. Creates `MarineProvider`/`WeatherProvider` via
  `MultiProvider`/`ChangeNotifierProvider` and hosts `HomeScreen` inside a
  `MaterialApp`, forwarding the `UnitPreferencesProvider`/`NearbyBeachesProvider`/
  `PlaceSearchProvider` passed into `main()`. Every optional provider defaults to
  `null`, so existing widget tests that construct `MarineApp` without them still
  render the pre-wiring layout.

## State flow

On mount, `HomeScreen` calls `WeatherProvider.fetchData` and
`NearbyBeachesProvider.pickLocation` for the fixed Çeşme coordinates (post-frame, to
avoid notifying an ancestor mid-build). `WeatherProvider`/`MarineProvider` are
`ChangeNotifier`s updated through their repository → service → Open-Meteo API chain;
`HomeScreen` listens to both (plus `UnitPreferencesProvider` and
`NearbyBeachesProvider`, the latter so the Sea section's shore-relation bearing
appears once beaches resolve) and rebuilds on change. `MarineProvider.fetchData` is
**not** called on initial load — only on pull-to-refresh — so `SwimSuggestionPill`'s
wave-height input and `SeaConditionsRow` are typically absent until the user refreshes
once; `MarineProvider` is otherwise used for the initial loading/error shell.

`NearbyBeachesProvider.pickLocation` (debounced) resolves beaches via `BeachCache` →
`OverpassService` → the Overpass API, maps them with `mapOverpassToBeaches`, then
enriches them with a single `MarineBatchService` call; it notifies `LocationMapCard`
(which redraws the beach/amenity overlay) and, once the user opens `SearchScreen`,
that screen too. Tapping the map calls `pickLocation` again with the tapped point.
`PlaceSearchProvider.search` (debounced) resolves place matches via `GeocodingService`;
selecting one on `SearchScreen` calls `NearbyBeachesProvider.pickLocation` with its
coordinates instead. `FavoritesProvider` and `UnitPreferencesProvider` are each
created once SharedPreferences is available and persist across restarts.

Tapping a detail-capable `StatTile` (currently only Pressure) pushes a route from
`buildDetailRoute`, passing that metric's hourly series and current value from
`WeatherProvider`'s already-loaded `WeatherCondition` — no separate fetch.

## External APIs

- **Open-Meteo Marine API** (`marine-api.open-meteo.com/v1/marine`) — single-location
  sea condition data including ocean current speed/direction (`MarineApiService`,
  Home screen) and a batched multi-location variant (`MarineBatchService`,
  nearby-beaches results).
- **Open-Meteo Forecast API** (`api.open-meteo.com/v1/forecast`) — current/hourly/daily
  temperature, wind (plus gusts), cloud cover, pressure, UV index and rain chance, used
  by `WeatherApiService`.
- **Open-Meteo Geocoding API** (`geocoding-api.open-meteo.com/v1/search`) — free,
  keyless place-name search, used by `GeocodingService`.
- **Overpass API** (OpenStreetMap data, with a fallback mirror) — queried by
  `OverpassService` with `buildNearbyBeachesQuery`'s query, for beaches and nearby
  amenities around a picked point.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) — used by `flutter_map` in
  `HomeScreen`'s `LocationMapCard`; credited via the `OsmAttribution` widget as
  required by OSM's ODbL license.

## Tests

- `flutter test` — unit tests for models, mappers, services, repositories
  (`test/data/`), pure logic (`test/logic/`, including `swim_suitability_test.dart`,
  `condition_alert_service_test.dart`, `forecast_alerts_test.dart`,
  `pressure_trend_test.dart`, `wave_shore_relation_test.dart`,
  `beach_gear_advisor_test.dart`, `unit_preferences_test.dart`), provider tests
  (`test/logic/providers/`, including `NearbyBeachesProvider`/`PlaceSearchProvider`/
  `FavoritesProvider`/`UnitPreferencesProvider`/`MarineProvider`/`WeatherProvider`),
  widget tests for every presentational widget and for `SearchScreen`/
  `PressureDetailScreen` (`test/presentation/`), plus `test/widget_test.dart` rendering
  `HomeScreen` with a fake tile provider. API/service tests fake `http.Client` so none
  hit the network. Shared fixtures/fakes/builders live in `test/helpers/` (see
  `docs/testing.md` for the full conventions: layout, naming, `mocktail` usage, and
  which edge cases are mandatory).
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree with a fake tile provider and a fixture `http.Client`
  (covering Overpass and the marine batch endpoint) and checks: the app boots with
  `MarineProvider` clean; Home-to-Search navigation (search entry → `SearchScreen`,
  back chevron → `HomeScreen`); and the full nearby-beaches flow (pick on boot → real
  `BeachResultCard` fields from the fixture data). CI runs this on Linux under a
  virtual display: `xvfb-run -a flutter test integration_test -d linux --reporter
  expanded`.
- A `functional-verify` GitHub Actions workflow runs each pull request's acceptance
  criteria as an additional automated check, alongside `flutter analyze`/`flutter
  test`/the integration test run.
