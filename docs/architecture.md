# Architecture

BeachIQ is a Flutter app (SDK `^3.8.1`). Both screens from `docs/design.md` are now
implemented and wired to real data: the Home screen is a live weather/sea-conditions/
swim-suitability dashboard for a user-selected location (tapped on the map, searched
by place name, or restored from a previous session) with an interactive map (beach
outlines, amenity markers and an in-card place search) and a detail screen for every
stat tile, and the Search screen shows real nearby beaches (from OpenStreetMap) and
real place-name search results, enriched with marine data, favorites and unit
preferences.

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
  `highTemperature`/`lowTemperature`, `daylightWindows` (#229: a `List<DaylightWindow>`
  — one `sunrise`/`sunset` pair per forecast day, from `daily.sunrise`/`daily.sunset`;
  a day missing either value is dropped rather than paired with a fabricated one) and
  a list of `WeatherHourly` entries (`time`, `temperature`, `weatherCode`, plus
  nullable `windSpeed`, `windGusts`, `cloudCoverPercent`, `rainChancePercent`,
  `pressureHpa`), parsed from Open-Meteo's `current`/`hourly`/`daily` fields. Missing
  values stay `null` rather than being fabricated as zero.
- `WeatherCode` (`lib/data/models/weather_code.dart`) — maps Open-Meteo's numeric WMO
  weather code to a human-readable description (`weatherCodeDescription`).
- `DepthSample`/`DepthProfile` (`lib/data/models/depth_profile.dart`) — a nearshore
  depth-profile sample (distance from shore + depth, `depthMeters` nullable for
  land/NoData, never `0`) and the profile itself (an ordered list of samples,
  `available`, and `approximate` — always `true`, since the underlying EMODnet grid is
  coarse). `DepthProfile.unavailable()` is the single "nothing to show" result every
  failure path in `BathymetryService`/`DepthCache` returns. Built for the water-depth
  tile (#217) from the data layer `BathymetryService` fetches (#216).

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
- `NotificationService`/`LocalNotificationsPlugin` (`lib/data/services/notification_service.dart`)
  — initializes `flutter_local_notifications`, requests the platform's runtime
  notification permission once, and shows a single foreground "conditions turned
  favorable" notification. `LocalNotificationsPlugin` is the injectable interface
  (`RealLocalNotificationsPlugin` in production) so tests never touch a real platform
  channel. A no-op if the permission was denied. Used by `ConditionAlertDispatcher`.
- `BathymetryService` (`lib/data/services/bathymetry_service.dart`) — fetches a beach's
  nearshore depth profile (#216) from EMODnet Bathymetry's public WMS `GetFeatureInfo`
  endpoint (`ows.emodnet-bathymetry.eu/wms`, the `emodnet:mean` layer, no API
  key): one small request per point on the beach's seaward transect (see
  `lib/logic/transect.dart`), up to 5 per beach. Tolerantly parses either a JSON or
  GeoServer plain-text response body and never throws — any failure (no geometry/
  bearing to build a transect from, network error, timeout, non-200, an unparseable
  body, or every point landing on land/NoData) resolves to `DepthProfile.unavailable()`.

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

### `lib/data/services/depth_cache.dart`

`DepthCache` — a persistent (`SharedPreferences`-backed) cache of `DepthProfile`s (#216),
keyed by a coarse grid cell (`gridSize` degrees, default 0.001°, close to EMODnet's own
~115m cells) with a 90-day TTL — mirroring `BeachCache`'s pattern, with one difference:
an expired entry is simply treated as a miss and re-fetched, there is no
stale-while-revalidate step. Only an `available` profile is cached, so a transient
failure is retried on the next call rather than remembered for 90 days.

### `lib/logic`

Pure, platform-agnostic logic with no I/O:

- `scoreSwimSuitability` (`lib/logic/swim_suitability.dart`) — scores wave height, wind
  speed and rain chance (each optional) into a `SwimVerdict` (`good`/`caution`/`poor`/
  `unknown`) with a one-line message, used by the Home screen's suggestion pill.
  `unknown` only when every input is missing. Also defines the moderate/high
  thresholds (`moderateWindSpeedKmh`, `highWaveHeightM`, etc.) that
  `forecast_alerts.dart` reuses so the two never disagree about what "windy" or
  "rough" means.
- `windStatusFor`/`windStatusLabel`/`windStatusColor` (`lib/logic/wind_status.dart`) and
  `rainChanceStatusFor`/`rainChanceStatusLabel`/`rainChanceStatusColor`
  (`lib/logic/rain_status.dart`) — classify a wind speed or rain chance into a
  calm/moderate/strong (or low/medium/high) status word + color for the Home stat
  grid's tiles (#215), reusing `swim_suitability.dart`'s exact moderate/high thresholds
  so a tile's status word can never disagree with the suggestion pill's verdict.
- `ConditionAlertService` (`lib/logic/condition_alert_service.dart`) — decides whether
  a "conditions turned favorable" alert should fire on a verdict transition (only on
  not-good → good). Pure trigger-decision logic; `ConditionAlertDispatcher` (see
  `lib/logic/providers`) is the delivery half that actually calls it.
- `buildForecastAlerts` (`lib/logic/forecast_alerts.dart`) — a pure function producing
  `ForecastAlert`s (wind/waves/clouds/rain/current) from hourly weather and sea data:
  a rule fires on a fast rise (wind, waves, current) within a 2-hour window or on
  crossing a moderate/high threshold (wind, waves, rain — reusing
  `swim_suitability.dart`'s thresholds), or on the weather code moving from
  clear/partly-cloudy into overcast/rain/thunderstorm (clouds). Adjacent triggered
  hours are merged into one alert window. The current rule only covers "speed rises"
  — the owner's "current turns away from shore" half needs
  `wave_shore_relation.dart`'s classifier plus a beach's shore bearing, not wired up
  here. Takes an optional `daylight` (`List<DaylightWindow>`, #229): when non-empty,
  drops any alert whose window isn't entirely inside one of the location's
  sunrise-sunset pairs; empty (the API returned none) leaves the list unfiltered.
  `buildNextHourNote` (#229) is a sibling pure function: a single heads-up comparing
  only the current hour to the next one with the same rules/thresholds, never
  daylight-filtered (so it can still show after sunset), suppressed when the hourly
  entry anchoring "now" is more than an hour stale. Both are rendered on the Home
  screen by `ForecastAlertList` (see `lib/presentation/widgets`).
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
  the Home screen's Sea section and the Ocean Current detail screen to flag a current
  or wave heading out to sea.
- `transectPoints`/`seawardTransectFor` (`lib/logic/transect.dart`) — pure geometry
  (built on `latlong2`'s `Distance.offset`) computing points running out from a start
  coordinate along a bearing. `seawardTransectFor(Beach)` builds a beach's nearshore
  depth transect (#216): its OSM geometry's centroid, out along
  `seawardBearingFromGeometry`, at `defaultTransectDistancesMeters` (0/100/200/300/400
  m). Returns `null` — never a guessed direction — when the beach has no geometry or
  no derivable seaward bearing. Used by `BathymetryService`.
- `classifyShallowEntry` (`lib/logic/shallow_entry.dart`) — classifies a `DepthProfile`
  (#216) into a `ShallowEntrySteepness` (gentle/moderate/steep/unknown), a rough
  non-swimmer indication of how quickly a beach's seabed drops away: read from the
  depth at a fixed 100m reference distance (`unknown` when that sample or a second
  valid sample is missing, never extrapolated). Also computes
  `firstShallowExitDistanceMeters`/`firstDeepDistanceMeters` — the first transect
  distance exceeding `shallowLimitMeters` (1.2m)/`deepLimitMeters` (2.5m).
- `shallowEntryStatusLabel`/`shallowEntryStatusColor`/`formatShallowEntrySummary`
  (`lib/logic/shallow_entry_status.dart`) — status word/color for a
  `ShallowEntrySteepness` (#217), in the same style as `wind_status.dart`, plus a
  formatted summary string for the water-depth tile/detail screen's headline value
  (e.g. "<= 1.2 m for 180 m"), falling back to "No data" for `unknown`.
- `adviseOnShoes` (`lib/logic/beach_gear_advisor.dart`) — advises `advised`/
  `notNeeded`/`unknown` on bringing shoes/slippers, from a beach's OSM `surface` tag.
  Framed as advice, never as a fact.
- `uvBandFor`/`uvBandLabel`/`uvProtectionHint`/`uvBandColor` (`lib/logic/uv_band.dart`)
  — classifies a UV index reading into the five WHO/EPA bands (low 0-2, moderate 3-5,
  high 6-7, very high 8-10, extreme 11+), with a label, a one-line sun-protection hint,
  and (#215) a status color per band. Used by the UV index detail screen's chart bands
  and (via `uvBandColor`) the Home UV index stat tile's status chip.
- `rainChanceWindows`/`rainChanceSummary` (`lib/logic/rain_windows.dart`) — groups an
  hourly rain-chance series into contiguous windows at/above a threshold (the
  `moderateRainChancePercent` constant from `swim_suitability.dart`, so the two never
  disagree) and renders them as a plain-language sentence, e.g. "Rain likely between
  14:00 and 17:00.", or "No rain expected today." when there are none. A `null` hour
  breaks a window's continuity without ever being treated as 0%. Used by the rain
  chance detail screen.
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
- `ConditionAlertDispatcher` (`lib/logic/providers/condition_alert_dispatcher.dart`) —
  not a `ChangeNotifier` itself, but a listener built alongside the other providers
  (see `main.dart`) that watches `WeatherProvider`/`MarineProvider`, scores a
  `SwimVerdict` via `scoreSwimSuitability` on every update, and calls
  `NotificationService.show` whenever `ConditionAlertService.shouldAlert` fires.
  Tracks the last-seen coordinates itself so a location switch (map tap or search
  pick) resets the verdict baseline instead of looking like a transition; the
  baseline and the alerts-enabled toggle (`setAlertsEnabled`, no settings-screen UI
  yet) are persisted via `SharedPreferences`.
- `DepthProvider` (`lib/logic/providers/depth_provider.dart`) — a `ChangeNotifier`
  driving the Home water-depth tile/detail screen (#217): `fetchForBeach(beach)`
  fetches (or reuses `DepthCache`'s cached result for) a `DepthProfile` for whichever
  beach Home currently keys its depth tile off of (the nearest fetched beach, or an
  explicit Search pick), mirroring `MarineProvider`'s "last request wins" pattern — a
  no-op if called again for the same beach, and a request token guards a superseded
  fetch's result from overwriting a newer one. `null` (no beach to key a transect off
  of) clears `profile` to `DepthProfile.unavailable()` with no network call.

### `lib/presentation/widgets`

Reusable widgets built against `docs/design.md`:

- `StatTile` (`stat_tile.dart`) — icon + label + a large value with its unit as a
  visually secondary run (#215, via `Text.rich`/separate `TextSpan`s, with a
  per-metric separator so a percent unit attaches with no space) + an optional short
  colored status chip (`statusLabel`/`statusColor`, e.g. "Calm", "High" — must be
  supplied together) + an optional muted trend indicator (`trendDirection`/
  `trendDelta`, also must be supplied together; omitted entirely for a metric with no
  meaningful delta, e.g. water depth's spatial reading). Used in the Home screen's 2×2
  stat grid. Optionally `onTap` (used by every stat tile to open its own detail
  screen).
- `HourlyForecastItem` (`hourly_forecast_item.dart`) — time label + colored weather
  icon (day/night variant chosen from the entry's own `time`, not the device clock) +
  bold temperature, used in the Home screen's scrollable hourly row.
- `SearchField` (`search_field.dart`) — the rounded "paper" search input.
- `LocationMapCard` (`location_map_card.dart`) — the rounded "paper" map card: a real
  `FlutterMap` (OpenStreetMap tiles), a docked bottom location bar. Owns its own
  `MapController` (#238), so a `center`/`selectedBeach` change from outside actually
  moves the camera (previously `MapOptions.initialCenter` only applied on first
  build) — fitting to the beach's geometry bounds when it has 2+ points, otherwise
  centering at a zoom that keeps amenity markers visible. `selectedBeach`'s
  polygon/line gets a distinct white, thicker border among the gold overlays. When
  given a `NearbyBeachesProvider`, the map becomes interactive: tapping it calls
  `pickLocation`, draws a 20km search-radius circle around the pick, and renders the
  resulting beaches as gold polygons/lines (capped at 40 overlays, nearest-first) via
  `PolygonLayer`/`PolylineLayer`, and (via `onLocationPicked`) reports the pick up to
  the caller. At zoom >= 12 (`kAmenityMarkersMinZoom`), each visible beach's amenities
  are drawn as `AmenityMarker` pins (hidden below that zoom to avoid visual noise),
  with an `AmenityLegend` toggle row and a tap-to-select info card showing the
  amenity's name/kind and distance from the pick. When given a `PlaceSearchProvider`,
  a search icon in the location bar expands into a live place-name search (loading/
  empty/error/loaded); selecting a result recenters the map and reports the pick via
  `onLocationPicked` with the place's real name, exactly as a map tap would (issue
  #158). Includes an `OsmAttribution` credit in the bottom-left corner.
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
  speed and current direction, read from `MarineProvider.currentData`. The wave
  height, water temperature and current speed/direction tiles each open their own
  detail screen (`buildDetailRoute`) when tapped; only the wave-direction tile has no
  tap target. When a `seawardBearingDegrees` is supplied (the nearest beach's shore
  bearing, from `wave_shore_relation.dart`), the direction tiles also show a
  toward/away/along-shore label, with "away from shore" shown as a bold warning.
  Renders nothing when no sea data has loaded yet; any individual missing field shows
  "No data".
- `CloudBackdrop` (`cloud_backdrop.dart`) — a faint, deterministic (no `Random()`, no
  animation) blurred-cloud texture painted behind the Home header with
  `CustomPainter`, replacing the mockup's missing photographic asset. Wrapped in
  `IgnorePointer` (never intercepts taps) and `RepaintBoundary` (isolated from the
  scrolling content below it).
- `BeachResultCard` (`beach_result_card.dart`) — the Search screen's result-sheet row
  (also reused, with a custom `onTap` and fully-rounded `borderRadius`, #238, for
  Home's compact post-pick info row): beach name/subtitle, a weather icon/temperature,
  a favorite-toggle heart (when a callback is supplied), and — once any beach info is
  supplied — a two-column block of
  plain-text info lines (entry fee, wave height, water temperature, shoe advice, car
  park, beach club, café). Unit-aware via `UnitSystem`. Every field renders "No data"/
  "Unknown" rather than inventing a value when the source has none.
- `MetricDetailScaffold` (`metric_detail_scaffold.dart`) — the shared layout for every
  per-metric detail screen (pressure, UV index, rain chance, wind, wave height, water
  temperature, current, water depth — all implemented, see the screens below): a back
  button + title, a hero value with optional unit/trend line, a chart slot, a min/now/
  max summary row, and an explanation paragraph.
- `HourlyMetricChart` (`hourly_metric_chart.dart`) — a reusable hourly line chart
  (`CustomPaint`-based, no charting package) for the metric detail screens: a value
  scale on the y-axis and hourly time labels on the x-axis, a "Now" marker, optional
  horizontal threshold lines, an optional filled area band, optional fixed colored
  value-range bands (`HourlyChartValueBand`, painted as full-width background strips
  behind everything else — e.g. the UV index screen's risk bands), and gaps (never a
  fabricated zero) wherever an hour's value is `null`.
- `DepthProfileChart`/`DepthProfileChartPainter` (`depth_profile_chart.dart`) — the
  water-depth detail screen's chart (#217): x = distance from shore, y = depth drawn
  increasing *downward* (matching a real seabed cross-section, the opposite of
  `HourlyMetricChart`'s convention), with reference lines at `shallowLimitMeters`/
  `deepLimitMeters`. A `null` `DepthSample.depthMeters` (land/NoData) is a gap in the
  line, never a fabricated `0`. `CustomPaint`-based like `HourlyMetricChart`, no
  charting package.
- `ForecastAlertList` (`forecast_alert_list.dart`) — the Home screen's list of
  upcoming `ForecastAlert`s (from `buildForecastAlerts`), sitting between the
  suggestion pill and the stat grid: one row per alert (a type icon colored by
  severity, the alert's one-line message, a compact time-window label — prefixed with
  a day label, e.g. "Tomorrow", when the alert isn't on today's calendar date, #229),
  sorted most-severe-first via `sortAlertsBySeverity`. An optional `nextHourNote`
  (#229, from `buildNextHourNote`) renders first as a visually distinct "Next hour"
  row (a tinted icon circle, no time-window line) — it can be shown even when
  `alerts` is empty (e.g. after sunset, since it is never daylight-filtered). Renders
  nothing when both are empty/null, leaving no gap.

### `lib/presentation/theme`

- `verdict_palette.dart` — `paletteForVerdict(SwimSuitabilityLevel)`, the pure mapping
  from a swim verdict to its `VerdictPalette` (gradient + foreground color + icon) used
  by `SwimSuggestionPill`.

### `lib/presentation/navigation`

- `detail_routes.dart` — `buildDetailRoute(DetailMetric metric, ...)` builds the
  `MaterialPageRoute` (named `/detail/<metric>`) for a tapped Home/Sea-section stat
  tile. Every `DetailMetric` value (`pressure`, `uvIndex`, `rainChance`, `wind`,
  `waveHeight`, `waterTemperature`, `current`, `depth`) is wired to its own screen.
  Most read the `hourly` (`WeatherHourly`) series; `waveHeight`/`waterTemperature`/
  `current` instead read `seaHourly` (`SeaCondition.hourly`, marine data); `current`
  additionally takes `currentDirectionValue` and `seawardBearingDegrees` for its
  drift-out warning. `depth` (#217) instead takes `depthProfile`, `beach` and
  `currentWaveHeightMeters` — it has no hourly series at all. `unitSystem` carries the
  display-unit preference to every metric that has a unit.

### `lib/presentation/screens`

- `HomeScreen` (`lib/presentation/screens/home_screen.dart`) — the real dashboard for
  a **selected location**: a header (place name, live temperature), a condition row
  (description, high/low), `LocationMapCard` (with its own search icon and overflow
  menu — "Beaches" opens `SearchScreen`, "Units" the metric/imperial sheet, when a
  `UnitPreferencesProvider` is supplied), `SwimSuggestionPill`, `ForecastAlertList`
  (built fresh on every build from `buildForecastAlerts` on the same hourly data;
  hidden entirely when there are no upcoming alerts), the `SeaConditionsRow`
  (once marine data has loaded), the 2×2 `StatTile` grid (wind speed, rain chance,
  water depth — #217, replacing the original pressure tile — and UV index; each
  tappable to its own detail screen — wind/rain/UV from `WeatherProvider`, water depth
  from `DepthProvider`), and the hourly forecast row (trimmed to the next 24 entries from
  "now"). A `CloudBackdrop` sits behind the header in both the loaded and
  loading/error layouts. The selected location starts at a fixed Çeşme default, is
  replaced by whatever the user taps on the map or picks via its search icon, and is
  persisted via `SharedPreferences` and restored on the next app start; every fetch
  (weather, marine, nearby beaches) and the header/place name follow it, never a fixed
  city once a pick has happened. Shows a full-screen loading spinner or error message
  (driven by `MarineProvider`) before the first successful load; pull-to-refresh
  re-fetches both `MarineProvider` and `WeatherProvider` for the selected location
  without tearing down the screen. Also derives the nearest beach to the selected
  location (by real distance — `NearbyBeachesProvider.beaches` is in Overpass
  element-id order, not distance order), or uses a beach explicitly picked from
  Search (#238, via `SearchScreen`'s `Navigator.pop<Beach>`) in preference to it — that
  beach's seaward bearing feeds `SeaConditionsRow`'s shore-relation labels, and the
  same beach (`isSameBeach`-compared) is what `DepthProvider.fetchForBeach` is called
  with for the water-depth tile. A beach picked from Search is rendered as a compact
  `BeachResultCard`-based info row below the map.
- `SearchScreen` (`lib/presentation/screens/search_screen.dart`) — composed from
  `SearchField` + a `BeachResultCard` list. Backed by `NearbyBeachesProvider.beaches`
  when supplied, else `staticBeaches`. Tapping a beach card pops the screen with that
  `Beach` (#238, `Navigator.pop<Beach>`), which `HomeScreen` treats exactly like a map
  pick. Filters the list by name/city substring as the
  user types, and (when a `FavoritesProvider` is supplied) to favorites-only via a
  header star toggle. When a `PlaceSearchProvider` is supplied, typing also shows a
  "Places" section (any place by name, not just nearby/static beaches) above the beach
  list; tapping a place re-centers `NearbyBeachesProvider` on it. Shows
  `NearbyBeachesProvider`'s loading/error states. Supports pull-to-refresh via an
  injected `onRefresh` callback.
- `PressureDetailScreen` (`lib/presentation/screens/detail/pressure_detail_screen.dart`)
  — the day's hourly sea-level pressure as an `HourlyMetricChart` with a "Now" marker
  and a low-pressure threshold line, a min/max/now summary, and a rising/steady/
  falling trend (`classifyPressureTrend`, comparing "now" to 3 hours earlier). Since
  #217 replaced the Home pressure tile with the water-depth tile below, this screen
  and its `DetailMetric.pressure` route still exist (and are still tested) but are no
  longer reachable from the stat grid.
- `DepthDetailScreen` (`detail/depth_detail_screen.dart`) — the water-depth / shallow-
  entry detail screen (#217): a hero value from `formatShallowEntrySummary`, a status
  chip from `shallowEntryStatusLabel`/`shallowEntryStatusColor`, a `DepthProfileChart`,
  a min/now/max row repurposed for the spatial profile (shallowest/the 100m reference
  depth/deepest valid reading, rather than a time series), a context list (lifeguard
  presence, current wave height, and the Ocean Current screen's drift-out warning
  when the current is heading offshore above its threshold — each item renders only
  when its data exists), and an EMODnet attribution line. The attribution text follows
  EMODnet's terms of use (EU-owned, CC BY 4.0, not for navigation). Pushed from `HomeScreen`'s water-depth `StatTile`.
- `UvIndexDetailScreen` (`detail/uv_index_detail_screen.dart`) — the day's hourly UV
  index as an `HourlyMetricChart` with the five `uv_band.dart` risk bands colored in
  via `valueBands`, a "Now" marker, a min/max/now summary, and `uvProtectionHint` for
  the current band. Pushed from the Home UV index `StatTile`.
- `WindDetailScreen` (`detail/wind_detail_screen.dart`) — the day's hourly wind speed
  and gusts (a second chart, shown only when at least one hour has gust data) with the
  20/40 km/h calm/moderate/strong thresholds imported from `swim_suitability.dart`.
  Pushed from the Home wind speed `StatTile`.
- `RainChanceDetailScreen` (`detail/rain_chance_detail_screen.dart`) — the day's hourly
  rain probability with the 40%/70% thresholds from `swim_suitability.dart` and a
  plain-language summary of the day's rain window(s) from `rain_windows.dart`. Pushed
  from the Home rain chance `StatTile`.
- `WaveHeightDetailScreen` (`detail/wave_height_detail_screen.dart`) — the day's hourly
  wave height (from `SeaCondition.hourly`) with the 0.6 m/1.2 m choppy/rough
  thresholds from `swim_suitability.dart`, plus wave period and direction per hour
  underneath. Shows "No data for this location." instead of an empty chart when the
  whole series is null. Pushed from `SeaConditionsRow`'s wave height tile.
- `WaterTemperatureDetailScreen` (`detail/water_temperature_detail_screen.dart`) — the
  day's hourly sea surface temperature with four comfort bands (below 16°C cold,
  16-20°C cool, 20-24°C pleasant, above 24°C warm) and a comfort hint; same "no data"
  handling as the wave height screen. Pushed from `SeaConditionsRow`'s water
  temperature tile.
- `CurrentDetailScreen` (`detail/current_detail_screen.dart`) — the day's hourly ocean
  current speed as a chart plus a per-hour direction arrow strip, and a prominent
  drift-out warning banner when the current flows away from shore (via
  `wave_shore_relation.dart`'s `classifyDirection`) at or above 2.0 km/h
  (`driftOutWarningSpeedKmh`, from NOAA swimmer-safety guidance). With no beach
  geometry or direction data, the status line says so instead of inventing a shore
  relation; names Open-Meteo's ocean current grid as coarse/often empty near shore
  when there's no data at all. Pushed from `SeaConditionsRow`'s current speed/
  direction tiles.

Every screen above shares `MetricDetailScaffold`/`HourlyMetricChart` (see
`lib/presentation/widgets`) and is reached only via `buildDetailRoute`
(`lib/presentation/navigation/detail_routes.dart`).

### `lib/main.dart`

- `main()` — initializes Flutter bindings, loads `SharedPreferences`, creates one
  shared `http.Client`, builds a `NearbyBeachesProvider` (`OverpassService` +
  `BeachCache` + `MarineBatchService`), a `UnitPreferencesProvider`, a
  `PlaceSearchProvider` (`GeocodingService`), and a `DepthProvider` (#217:
  `BathymetryService` + `DepthCache`); also builds the `MarineProvider`/
  `WeatherProvider` instances here (rather than leaving it to `MarineApp`'s default)
  so it can start a `NotificationService` and a `ConditionAlertDispatcher` listening
  to those same instances before `runApp`, then runs `MarineApp` with all of them.
- `MarineApp` — the root widget. Creates `MarineProvider`/`WeatherProvider` via
  `MultiProvider`/`ChangeNotifierProvider` and hosts `HomeScreen` inside a
  `MaterialApp`, forwarding the `UnitPreferencesProvider`/`NearbyBeachesProvider`/
  `PlaceSearchProvider` passed into `main()`. Every optional provider defaults to
  `null`, so existing widget tests that construct `MarineApp` without them still
  render the pre-wiring layout.

## State flow

On mount, `HomeScreen` restores a previously-picked location from `SharedPreferences`
(falling back to the fixed Çeşme default on a first run or a restore failure), then
calls `WeatherProvider.fetchData` and `NearbyBeachesProvider.pickLocation` for that
selected location (post-frame, to avoid notifying an ancestor mid-build).
`WeatherProvider`/`MarineProvider` are `ChangeNotifier`s updated through their
repository → service → Open-Meteo API chain; `HomeScreen` listens to both (plus
`UnitPreferencesProvider` and `NearbyBeachesProvider`, the latter so the Sea section's
shore-relation bearing appears once beaches resolve) and rebuilds on change.
`MarineProvider.fetchData` is **not** called on initial load — only on pull-to-refresh
or a fresh location pick — so `SwimSuggestionPill`'s wave-height input and
`SeaConditionsRow` are typically absent until one of those happens; `MarineProvider` is
otherwise used for the initial loading/error shell.

Tapping the map (or picking a place via the map card's own search icon) calls
`HomeScreen._handleLocationPicked`: it updates the selected location/place name
immediately, re-fetches `WeatherProvider`/`MarineProvider` for the new point, and
persists the pick via `SharedPreferences` so it survives an app restart.
`NearbyBeachesProvider.pickLocation` (debounced) is called directly by
`LocationMapCard`'s own tap handler and resolves beaches via `BeachCache` →
`OverpassService` → the Overpass API, maps them with `mapOverpassToBeaches`, then
enriches them with a single `MarineBatchService` call; it notifies `LocationMapCard`
(which redraws the beach/amenity overlay) and, once the user opens `SearchScreen`
(via the map card's overflow menu → "Beaches"), that screen too.
`PlaceSearchProvider.search` (debounced) resolves place matches via `GeocodingService`,
used by both the map card's own search icon and `SearchScreen`'s "Places" section;
selecting a result calls `NearbyBeachesProvider.pickLocation`/`onLocationPicked` with
its coordinates instead of a raw map tap. `FavoritesProvider` and
`UnitPreferencesProvider` are each created once SharedPreferences is available and
persist across restarts.

Tapping any Home stat tile or Sea-section tile pushes a route from `buildDetailRoute`,
passing that metric's hourly series and current value from the already-loaded
`WeatherCondition`/`SeaCondition` — no separate fetch.

`ConditionAlertDispatcher` (started in `main()` before `runApp`) listens to the same
`WeatherProvider`/`MarineProvider` instances independently of the widget tree: on
every update it scores a `SwimVerdict` and, through `NotificationService`, fires a
local notification whenever `ConditionAlertService` says the verdict just turned
favorable for the currently selected location.

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
- **EMODnet Bathymetry WMS** (`ows.emodnet-bathymetry.eu/wms`, `GetFeatureInfo` on the
  `emodnet:mean` layer) — nearshore depth samples for the water-depth tile
  (#216/#217), queried by `BathymetryService`, cached 90 days by `DepthCache`.
  Credited on the depth detail screen.

## Tests

- `flutter test` — unit tests for models (`test/data/models/`, including
  `depth_profile_test.dart`/`beach_amenity_test.dart`), mappers, services
  (`test/data/services/`, including `bathymetry_service_test.dart`/
  `depth_cache_test.dart`), repositories (`test/data/`, including
  `notification_service_test.dart`'s fake `LocalNotificationsPlugin`), pure logic
  (`test/logic/`, including `swim_suitability_test.dart`,
  `condition_alert_service_test.dart`, `forecast_alerts_test.dart` (covering both
  `buildForecastAlerts`'s daylight filter and `buildNextHourNote`, #229),
  `pressure_trend_test.dart`, `wave_shore_relation_test.dart`,
  `beach_gear_advisor_test.dart`, `unit_preferences_test.dart`, `uv_band_test.dart`,
  `rain_windows_test.dart`, `transect_test.dart`, `shallow_entry_test.dart`,
  `shallow_entry_status_test.dart`, `wind_status_test.dart`, `rain_status_test.dart`),
  provider tests (`test/logic/providers/`, including
  `NearbyBeachesProvider`/`PlaceSearchProvider`/`FavoritesProvider`/
  `UnitPreferencesProvider`/`MarineProvider`/`WeatherProvider`/
  `ConditionAlertDispatcher`/`DepthProvider`), widget tests for every
  presentational widget (including `depth_profile_chart_test.dart`) and for
  `SearchScreen` and all eight metric detail screens (`test/presentation/`, including
  `test/presentation/screens/detail/`, e.g. `depth_detail_screen_test.dart`), plus
  `test/widget_test.dart` rendering `HomeScreen` with a fake tile provider, and
  `test/tools/test_summary_test.dart` (the CI test-summary tool itself, below). API/
  service tests fake `http.Client` so none hit the network. Shared fixtures/fakes/
  builders live in `test/helpers/` (see `docs/testing.md` for the full conventions:
  layout, naming, `mocktail` usage, and which edge cases are mandatory).
- `flutter test integration_test` — `integration_test/app_test.dart` boots the real
  `MarineApp` widget tree with a fake tile provider and a fixture `http.Client`
  (covering Overpass and the marine batch endpoint) and checks: the app boots with
  `MarineProvider` clean; Home-to-Search navigation (map card overflow → "Beaches" →
  `SearchScreen`, back chevron → `HomeScreen`); the full nearby-beaches flow (pick on
  boot → real `BeachResultCard` fields from the fixture data); the pick-a-location flow
  (map tap changes the data shown and survives a simulated restart); the map card's own
  search-icon flow; the search-to-map flow (#214: tapping a beach card in Search
  returns to Home with it selected/highlighted); the water-depth flow (#217: picking
  a beach fetches its nearshore profile and the detail screen shows it); the forecast
  daylight-filter/next-hour-note flow (#229); and a detail-flow test per metric (tap a
  stat tile → its detail screen → back). CI runs this on Linux under a virtual
  display: `xvfb-run -a flutter test integration_test -d linux --reporter expanded`.
- `tools/run_tests.sh` (used by both CI and local development) runs `flutter test
  --coverage --concurrency=4 --reporter json` and pipes it through
  `tools/test_summary.dart`
  (parsing/rendering logic in `tools/test_summary_lib.dart`), which prints one `Test
  summary: SUCCESS/FAILURE` line per module (a depth-two directory under `test/`) with
  failure details, and writes `build/reports/junit.xml` (JUnit XML) and
  `build/reports/summary.md`. `tools/check_coverage.sh` then parses
  `coverage/lcov.info` and fails if total line coverage drops below the baseline in
  `tools/coverage_baseline.txt`. CI (`analyze-and-test` job) runs both, uploads the
  reports/coverage as workflow artifacts, and appends the summary to the job's step
  summary.
- A checkstyle CI step runs `dart format --set-exit-if-changed` and a stricter
  `analysis_options.yaml` lint set as a gate on every pull request, alongside
  `flutter analyze`/`flutter test`/the integration test run.
- The `functional-verify` GitHub Actions workflow (each pull request's acceptance
  criteria as an additional automated check) is currently paused — defined but not
  run on pull requests — to reduce token usage.
