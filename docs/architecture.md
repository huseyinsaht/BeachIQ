# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`). The app has two real screens (Home and
Search) wired together with navigation, and a growing layer of data/logic code behind
them. Some of that backing code — real weather data, the wave/marine fetch, and the
OSM "nearby beaches" pipeline — is already live in the running app; other pieces (the
OSM nearby-beaches search, swim suitability scoring, gear advice, condition alerts) are
fully implemented and unit/widget-tested but not yet wired into a screen. Each section
below says which is which.

## Layers

### `lib/data/models`

Plain Dart data classes:

- `Beach` (`lib/data/models/beach.dart`) — `name`, `city`, `latitude`, `longitude`,
  plus OSM-derived fields: `surface`, `hasLifeguard`, `fee` (a `BeachFee` enum:
  `free`/`paid`/`unknown`), `hasShower`/`hasToilets`/`hasChangingRoom`/`hasParking`/
  `hasCafe`/`hasBeachResort`, and an optional `geometry` (the beach's polygon/line
  points, for map overlays).
- `SeaCondition` (`lib/data/models/sea_condition.dart`) — `waveHeight`,
  `waveDirection`, `wavePeriod`, `seaSurfaceTemperature`. `SeaCondition.fromJson` parses
  the Open-Meteo Marine API's `current` object.
- `WeatherCondition` (`lib/data/models/weather_condition.dart`) — `temperature`,
  `windSpeed`, `weatherCode`, plus `pressureHpa`, `uvIndex`, `rainChancePercent`,
  `highTemperature`/`lowTemperature`, and an hourly forecast (`List<WeatherHourly>`:
  `time`, `temperature`, `weatherCode`). `fromJson` reads Open-Meteo's `current`,
  `hourly` and `daily` blocks; UV index, rain chance and pressure come from the hourly
  arrays (Open-Meteo only exposes those hourly) picked at the hourly entry matching the
  API's own `current.time`. A field the response doesn't have is left `null`, never
  guessed as `0`.
- `weather_code.dart` — `weatherCodeDescription(code)`, mapping an Open-Meteo WMO
  weather code to a short human-readable string.

### `lib/data/static_beaches.dart`

A hardcoded `List<Beach>` of 10 Turkish beaches. Returned by `BeachRepository`, and used
as `BeachCache`'s offline fallback (see below) and as `SearchScreen`'s placeholder
results (see UI section) until the real OSM nearby-beaches pipeline is wired into a
screen.

### `lib/data/services`

- `MarineApiService` (`lib/data/services/api_service.dart`) — calls the Open-Meteo
  Marine API (`https://marine-api.open-meteo.com/v1/marine`) for
  `wave_height,sea_surface_temperature,wave_period,wave_direction` at a given
  latitude/longitude. Throws on a non-200 response or a network error.
- `WeatherApiService` (`lib/data/services/weather_api_service.dart`) — calls the
  Open-Meteo Forecast API (`https://api.open-meteo.com/v1/forecast`) for `current`
  (temperature, wind speed, weather code), `hourly` (temperature, weather code, UV
  index, precipitation probability, pressure) and `daily` (min/max temperature) fields.
  Same 200/error handling shape as `MarineApiService`.
- `buildNearbyBeachesQuery` (`lib/data/services/overpass_query_builder.dart`) — a pure
  function (no network, no I/O) that builds the Overpass QL query for finding beaches
  (`natural=beach`, with full geometry) and nearby amenities — showers, toilets,
  changing rooms, parking, cafés, lifeguards, beach resorts — within `radiusMeters`
  (default 20000) of a point.
- `OverpassService` (`lib/data/services/overpass_service.dart`) — runs an Overpass QL
  query against the public Overpass API. Falls back to a second mirror endpoint if the
  primary fails, retries HTTP 429/504 responses with exponential backoff, and
  de-duplicates concurrent identical queries into a single in-flight request. Returns
  the raw decoded Overpass JSON; mapping it to `Beach`es is a separate step.
- `mapOverpassToBeaches` (`lib/data/mappers/osm_beach_mapper.dart`) — turns a raw
  Overpass JSON response into `Beach` objects: groups `natural=beach` elements that are
  within 30m of each other (adjoining ways representing the same physical beach) via
  union-find, then attaches nearby amenity elements to the nearest beach group within
  150m (matching the Overpass query's own `around.b:150` radius).
- `BeachCache` (`lib/data/services/beach_cache.dart`) — a `SharedPreferences`-backed,
  stale-while-revalidate cache of OSM beach results, keyed by a coarse 0.25°×0.25° grid
  cell so nearby picks share a cache entry. A cached entry (even if past its 7-day TTL)
  is always returned immediately; a stale result also tells the caller to trigger a
  background `refresh()`. If nothing is cached and the fetch fails (offline, or every
  Overpass endpoint down), falls back to `staticBeaches` filtered to a 100km radius so
  the caller never gets a blank result.
- `MarineBatchService` (`lib/data/services/marine_batch_service.dart`) — fetches wave
  height and sea surface temperature for many beach coordinates in a single Open-Meteo
  Marine API request (its multi-location comma-separated `latitude`/`longitude`
  parameters), with an in-memory 1-hour cache keyed by the sorted coordinate list. A
  separate path from `MarineApiService`, which stays dedicated to the single-location
  Home screen lookup.

### `lib/data/repositories`

- `MarineRepository` (`lib/data/repositories/marine_repository.dart`) — wraps
  `MarineApiService`, pulls the response's `current` object, and turns it into a
  `SeaCondition`. Throws a descriptive exception if `current` is missing or not a map.
- `WeatherRepository` (`lib/data/repositories/weather_repository.dart`) — wraps
  `WeatherApiService`, turns its response into a `WeatherCondition`. Same shape and
  error handling as `MarineRepository`.
- `BeachRepository` (`lib/data/repositories/beach_repository.dart`) — returns
  `staticBeaches` from `getBeaches()`. A placeholder so callers don't need to change
  once a real beach data API exists.

### `lib/logic`

Pure logic, no widgets and no network:

- `adviseOnShoes` (`lib/logic/beach_gear_advisor.dart`) — maps a beach's OSM `surface`
  tag to a `ShoeAdvice` (`advised`/`notNeeded`/`unknown`): always phrased as advice, not
  a fact, since `surface` doesn't say how sharp or hot the ground actually is.
- `scoreSwimSuitability` (`lib/logic/swim_suitability.dart`) — scores wave height, wind
  speed and rain chance into a `SwimVerdict` (`SwimSuitabilityLevel`:
  `good`/`caution`/`poor`/`unknown`, plus a one-line message). Each input is optional
  and independently missing inputs are skipped; the result is the worst level triggered
  by any available input, deliberately biased toward caution.
- `ConditionAlertService` (`lib/logic/condition_alert_service.dart`) — a pure trigger
  decision for a "conditions turned favorable" alert: `shouldAlert` returns true only
  when alerts are enabled and the verdict transitions from not-good to good. This is
  only the decision logic — it does not send, schedule, or request permission for any
  actual notification (see the class doc for the follow-up work that would need).

### `lib/logic/providers`

- `MarineProvider` (`lib/logic/providers/marine_provider.dart`) — a `ChangeNotifier`
  exposing `currentData` (`SeaCondition?`), `isLoading`, and `error`. `fetchData(lat,
  lon)` calls `MarineRepository.getMarineData` and notifies listeners before and after.
  Created app-wide in `main.dart`; `HomeScreen` currently only reads its
  loading/error state, not `currentData`.
- `WeatherProvider` (`lib/logic/providers/weather_provider.dart`) — the same
  loading/data/error `ChangeNotifier` shape as `MarineProvider`, wrapping
  `WeatherRepository.getWeatherData`. Created app-wide in `main.dart`; drives
  `HomeScreen`'s header, stat grid and hourly row.
- `NearbyBeachesProvider` (`lib/logic/providers/nearby_beaches_provider.dart`) — ties
  the OSM nearby-beaches pipeline together for a single picked map location:
  `pickLocation(point)` debounces (400ms default) rapid repeated picks, then resolves
  beaches via `BeachCache` (which only calls `OverpassService` on a cache miss/stale
  entry) and enriches them with sea conditions via one `MarineBatchService.fetchBatch`
  call. Exposes `beaches`, `seaConditionFor(beach)`, `isLoading`, `error`, and a
  `NearbyBeachesStatus` (`idle`/`loading`/`loaded`/`empty`/`error`). Guards against a
  disposed provider's in-flight fetch calling `notifyListeners()` after disposal. **Not
  created anywhere in `main.dart`** — it exists, is fully unit-tested, and is proven
  end-to-end only inside `integration_test/app_test.dart`'s own composed widget tree
  (see Tests below).

### `lib/presentation/widgets`

Pure presentational widgets built against `docs/design.md`:

- `StatTile` (`stat_tile.dart`) — icon + label + bold value + up/down trend indicator,
  used on the Home screen's 2×2 stat grid. Wired to real `WeatherProvider` values
  (wind speed, rain chance, pressure, UV index); the trend arrow/delta on each tile is
  still a hardcoded placeholder (e.g. `"2 km/h"`), not derived from real historical
  data.
- `HourlyForecastItem` (`hourly_forecast_item.dart`) — time label + weather icon + bold
  temperature, used on the Home screen's scrollable hourly forecast row, wired to
  `WeatherProvider.currentData.hourly`.
- `SearchField` (`search_field.dart`) — a rounded "paper" search input with a leading
  search icon and `onChanged`/`onSubmitted` callbacks. Used non-interactively (wrapped
  in `AbsorbPointer`) as a tappable entry point on Home that pushes `SearchScreen`, and
  interactively at the top of `SearchScreen` itself (no filtering wired up yet).
- `LocationMapCard` (`location_map_card.dart`) — the rounded "paper" map card (a real
  `FlutterMap`, optionally overridable `TileProvider`) with a docked bottom bar (pin
  icon, place name, overflow menu) and an `OsmAttribution` credit. Used on the Home
  screen purely presentationally today (no `nearbyBeachesProvider` passed). When a
  `NearbyBeachesProvider` *is* supplied — currently only in
  `integration_test/app_test.dart` — tapping the map calls `pickLocation` and draws the
  returned beaches as gold polygons/lines inside a 20km radius circle (capped to the 40
  nearest beaches).
- `OsmAttribution` (`osm_attribution.dart`) — a small "© OpenStreetMap contributors"
  credit, required by OSM's ODbL license wherever OSM data/tiles are shown; tapping it
  opens the OSM copyright page. Placed in `LocationMapCard`'s corner.
- `BeachResultCard` (`beach_result_card.dart`) — the white "paper" search-result card:
  a result row (pin icon, place name, area subtitle, weather icon + temperature) plus,
  only when the caller supplies at least one beach-info value, a two-column "Beaches
  Near" info block (entry fee, wave height, water temperature, shoe advice, and
  car park/beach club/cafe presence). Every field renders "No data"/"Unknown" text
  rather than inventing a value. Used by `SearchScreen` today with only `placeName`/
  `areaSubtitle`/`temperature` set (no beach-info block shown, since it's still backed
  by `staticBeaches`); the fuller field set is exercised in
  `integration_test/app_test.dart`'s own composed results sheet.
- `SwimSuggestionPill` (`swim_suggestion_pill.dart`) — a rounded pill rendering a
  `SwimVerdict` (icon + one-line message). **Not used anywhere in `lib/main.dart`**:
  the Home screen's suggestion pill is still a hardcoded "Good conditions for a swim
  right now" string, not `scoreSwimSuitability`'s real output. Only exercised by its
  own widget test.

### `lib/presentation/screens/search_screen.dart`

`SearchScreen` — the Search screen: a header (back chevron, "Search" title, overflow
menu), a `SearchField`, and a bottom result sheet of `BeachResultCard`s under a
"Beaches Near" label, with `isLoading`/`error` parameters for loading/error states.
Currently renders `staticBeaches` as placeholder results (temperature always `"--°"`,
no beach-info block) — it takes no `NearbyBeachesProvider` and has no network/provider
dependency of its own yet; a caller wires loading/error state and (eventually) real
results in.

### UI (`lib/main.dart`)

- `MarineApp` — the root widget. Creates one `MarineProvider` and one `WeatherProvider`
  (each backed by its real repository/service) via `MultiProvider`, and hosts
  `HomeScreen` inside a `MaterialApp`.
- `HomeScreen` — a `StatefulWidget` rendering the Home / location-detail screen for a
  fixed location (Çeşme, İzmir). On first frame it fetches weather data for that point
  via `WeatherProvider` (deferred with `addPostFrameCallback` to avoid a
  "setState() during build" crash, since it's built inside the `Consumer2` that also
  listens to it). Shows a full-screen loading spinner or error message only on the
  *first* load (`MarineProvider.isLoading`/`error` with no data yet) — a
  pull-to-refresh re-fetch (`RefreshIndicator` wrapping the whole scroll view) no
  longer tears the screen down to that shell once data has loaded once. Renders the
  header temperature/condition/high-low, a `LocationMapCard`, a tappable search entry
  (pushes `SearchScreen`), a hardcoded suggestion pill, a `StatTile` 2×2 grid (wind
  speed, rain chance, pressure, UV index — all real `WeatherProvider` values, trend
  deltas hardcoded), and an hourly forecast row built from `WeatherProvider`'s hourly
  data, trimmed to start at the current hour (`_upcomingHourly`) and capped to 24
  entries. Tapping the search entry pushes `SearchScreen`; its back chevron pops back
  to `HomeScreen`.

## State flow

`WeatherProvider` and `MarineProvider` are both provided once at the app root. On
`HomeScreen`'s first frame, `WeatherProvider.fetchData` is called for the fixed Çeşme
coordinates; its `currentData`/`isLoading`/`error` drive the header, stat grid and
hourly row, and `HomeScreen` rebuilds via a listener on both providers.
`MarineProvider` is only consulted for its loading/error flags (not its `currentData`)
to decide whether to show the full-screen loading/error shell. A pull-to-refresh
gesture re-calls `fetchData` on both providers without tearing down the screen.

`NearbyBeachesProvider` follows a separate flow that only runs where it's actually
instantiated (currently just the integration test): `pickLocation(point)` debounces,
then resolves beaches through `BeachCache` → (on a cache miss) `OverpassService` →
`mapOverpassToBeaches`, and enriches the result with `MarineBatchService.fetchBatch`,
notifying listeners after each stage. This provider is not created in `main.dart`, so
it has no state flow in the shipped app yet.

## External APIs

- **Open-Meteo Forecast API** (`api.open-meteo.com/v1/forecast`) — current/hourly/daily
  temperature, wind speed, weather code, UV index, precipitation probability and
  pressure, used by `WeatherApiService` and rendered live on the Home screen.
- **Open-Meteo Marine API** (`marine-api.open-meteo.com/v1/marine`) — single-location
  sea condition data, used by `MarineApiService`/`MarineRepository`/`MarineProvider`
  (fetched, but not yet displayed).
- **Open-Meteo Marine API, batch mode** — the same endpoint's multi-location query
  parameters, used by `MarineBatchService` for the nearby-beaches sea-condition
  enrichment.
- **Overpass API** (OpenStreetMap data, `overpass-api.de` primary +
  `overpass.kumi.systems` mirror) — `OverpassService` runs `buildNearbyBeachesQuery`'s
  query to find beaches and amenities; not yet triggered from any shipped screen.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) — used directly by `flutter_map` in
  `LocationMapCard`.

## Tests

- `flutter test` — unit tests for the models, services, repositories, mappers, and
  logic functions (`test/data/**`, `test/logic/**` outside `providers/`), provider tests
  (`test/logic/providers`), widget tests for each screen/presentational widget
  (`test/presentation/**`), plus `test/widget_test.dart`. Service tests fake
  `http.Client` so none of them hit the network.
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree on Linux/xvfb and covers three flows: (1) the app boots with
  `MarineProvider` in a clean idle state and the map renders; (2) tapping Home's search
  entry opens `SearchScreen` and its back chevron returns to `HomeScreen`; (3) a
  self-contained results sheet (composed in the test file itself, not from `lib/`)
  wired to a real `NearbyBeachesProvider`/`OverpassService`/`MarineBatchService`/
  `BeachCache` against a fixture `http.Client` proves the full OSM pick → beach list →
  real-field `BeachResultCard` pipeline end-to-end, even though that pipeline isn't
  wired into a shipped screen yet. CI runs this via `xvfb-run -a flutter test
  integration_test -d linux --reporter expanded`.
