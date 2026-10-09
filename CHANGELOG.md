# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- A "Forecast" screen reachable from Home's expanded bottom sheet (or by tapping the
  next-hour note): every upcoming alert (severity sorted, full text) and the full 7-14
  day outlook, both shown in full instead of truncated. Home itself now shows at most
  one note — the single next-hour heads-up — instead of the full per-type alert list
  and inline outlook (#292)
- The selected-beach info row on Home now shows a one-line depth / non-swimmer verdict
  (reusing the water-depth tile's exact wording and color bands) with the stand-up
  distance and a shortened caveat when known; tapping it opens the same water-depth
  detail screen as the stat tile (#294)
- Additional test coverage for `DepthProvider`'s dispose-while-fetch-in-flight guard,
  matching the existing `MarineProvider`/`WeatherProvider` coverage (#296)

### Changed

- Home is now a map-first layout: the map fills the whole screen behind a floating
  search field and floating zoom/"my location" controls, with the selected location's
  details (place name, temperature, suggestion pill, next-hour note, stat tiles,
  hourly row) in a draggable bottom sheet that can be collapsed to just the essentials
  or expanded for everything else (#291)
- Upgraded to Flutter 3.47.6, Gradle 9.1, Android Gradle Plugin 9.0.1, Kotlin 2.3.20
  and NDK 28.2.13676358 (#286, #287)
- Refreshed `pubspec.lock` to pick up newer transitive dependency versions already
  allowed by `pubspec.yaml` (e.g. `geolocator`, `shared_preferences`, `url_launcher`);
  no application code changed (#290)

### Fixed

- `BeachResultCard`'s info rows (used on Search results and Home's selected-beach
  card) no longer overflow horizontally at a narrow width with a large text scale
  (#295)

## [2026.10.9] - 2026-10-07

### Added

- "Use my location": an opt-in device-location pick (`DeviceLocationService`,
  wrapping the `geolocator` plugin's coarse/city-level fix) in the map card's
  overflow menu — the only action that can ever show a location-permission prompt,
  never on app launch. A successful pick is reverse-geocoded in the background to a
  short place name (`ReverseGeocodingService`, cached 30 days by
  `ReverseGeocodeCache`); a failure keeps the previous location and shows a short
  message instead (#262)
- Water depth detail screen: a bold plain-language non-swimmer verdict sentence
  (e.g. "Gets deep fairly quickly. Non-swimmers should stay close to shore.") and a
  human-scale side-view cross-section graphic — depth-tinted water bands, a dashed
  seabed line through the real measured points, and a couple of standing-person
  silhouettes for scale — shown above the existing numeric depth-vs-distance chart
  (#261)
- Additional test coverage for the `unableToDetermine` location-permission case in
  `DeviceLocationService` (#263)
- An "Alerts" toggle in the Home map card's overflow menu (alongside "Units") turns
  the "conditions turned favorable" notification on or off; on by default (#268)
- A swim-safety disclaimer, one tap away via an info icon on the Home screen's
  suggestion pill: makes clear the suggestion is a model estimate from forecast data,
  not a safety guarantee, and that local flags/lifeguard instructions take precedence
  (#277)
- A "Compare beaches" screen, opened from the map card's overflow menu: pick 2-3 of
  the currently fetched nearby or favorited beaches to compare wave height, wind,
  water temperature, water depth and swim score side by side (#278)
- A "7-14 day outlook" section on the Home screen, below the hourly forecast row: one
  row per forecast day with its own swim verdict (reusing the suggestion pill's
  thresholds) and that day's high/low temperature (#279)
- Additional test coverage for `ConditionAlertDispatcher.stop()` (#281)

### Changed

- Home's 2×2 stat grid and its separate "Sea" section are merged into a single 3×3
  grid of nine equally-sized tiles in three labelled groups — Sea (wave height,
  water temperature, water depth), Current (current speed/direction, wave
  direction), Air (wind speed, rain chance, UV index) (#259)
- Home's header now shows the selected location's real place name as its primary
  title instead of a hard-coded "My Location" label, with the coordinates shown
  underneath only when they add information the name doesn't already (#260)
- The EMODnet Bathymetry attribution line on the water-depth detail screen now
  follows EMODnet's own terms of use (CC BY 4.0, EU ownership, not for navigation)
  and names the underlying dataset (EMODnet Digital Bathymetry DTM 2024, completed
  with GEBCO 2024/IBCAO V4 where survey data is missing) (#248)
- Pinned the Android NDK to 27.0.12077973, which several plugins
  (`flutter_local_notifications`, `path_provider_android`,
  `shared_preferences_android`, `url_launcher_android`) require, stopping a
  build-time warning (#249)

### Fixed

- `BathymetryService` now queries EMODnet Bathymetry's real OGC WMS endpoint
  (`ows.emodnet-bathymetry.eu/wms`, the `emodnet:mean` layer) instead of a WMTS tile
  host that answered every request with an HTTP 403 — the water-depth tile had been
  showing "No data" for every location (#255)
- A forecast alert whose window falls on a later calendar day (e.g. an evening
  session where only tomorrow's transition is left) is now prefixed with "tomorrow"
  or a weekday name instead of reading as a bare, already-past-looking hour (#258)
- Flaky Home integration tests: the boot/navigation tests now inject fixture
  `WeatherProvider`/`MarineProvider` instances instead of depending on a real,
  possibly-still-pending network fetch (#250)
- The 7-14 day outlook's wider forecast window (`forecast_days=14`) was leaking into
  the near-term-only upcoming-alerts list and "next hour" note, which could flag a
  threshold crossing many days out as an imminent change; both are now capped back to
  the next ~24 hours (#280)

## [2026.10.8] - 2026-10-06

### Added

- Tapping a beach in the Search screen now shows it on the Home map: the camera frames
  it, it's highlighted among the other beach outlines, and a compact info row appears
  below the map without leaving Search (#238)
- A nearshore depth-profile data layer (`BathymetryService`, querying EMODnet's public
  bathymetry WMS) and a non-swimmer "shallow entry" steepness classification
  (gentle/moderate/steep), cached on-device for 90 days — groundwork for the Home
  water-depth tile below, no UI yet on its own (#239)
- Home's stat tiles (wind speed, rain chance, pressure, UV index) now show a larger
  value with its unit as a separate, smaller run, plus a short colored status word
  (e.g. "Calm", "High") for wind speed and rain chance (#240)
- Home's pressure tile is replaced by a water depth / shallow-entry tile and its own
  detail screen: how far out the water stays comfortably shallow before the seabed
  drops away, with a depth-vs-distance chart, an EMODnet attribution line, and
  lifeguard/wave-height/drift-out context — an approximate, non-swimmer indication,
  never a safety guarantee (#241)
- Home's forecast alerts are now limited to daylight hours (using the location's
  sunrise/sunset), and a new "Next hour" row above the list always flags an imminent
  wind/wave/current/cloud/rain change, even after sunset (#242)
- Additional unit tests for the `BeachAmenity` model, bringing it in line with this
  repo's one-test-file-per-model convention (#244)

### Fixed

- `buildNextHourNote` no longer builds a "Next hour" alert from an hourly reading that
  is over an hour stale, which could mislabel an already-passed change as upcoming
  (#243)

## [2026.10.7] - 2026-10-05

### Added

- Home screen: an upcoming forecast-alerts list (`ForecastAlertList`) between the
  suggestion pill and the stat grid, built from `buildForecastAlerts`'s wind/wave/
  current/cloud/rain rules on the already-loaded hourly data — a type icon and
  one-line message per alert, colored and sorted most-severe-first, shown for nothing
  when there are no upcoming alerts (#223)
- Real notification delivery for the "conditions turned favorable" alert:
  `NotificationService` (wrapping `flutter_local_notifications`) and
  `ConditionAlertDispatcher`, listening to `WeatherProvider`/`MarineProvider` and
  firing a local notification whenever `ConditionAlertService` says the swim verdict
  just turned good at the selected location. Requests the platform notification
  permission on startup; the alerts-enabled toggle is persisted but still has no
  settings-screen UI to flip it, and delivery only happens while the app is running
  (#227)
- Detail-screen charts (`HourlyMetricChart`) now draw a value scale on the y-axis and
  hourly time labels on the x-axis alongside the existing line/threshold/band drawing
  (#224)
- A checkstyle CI gate: `dart format --set-exit-if-changed` plus a stricter
  `analysis_options.yaml` lint set, enforced on every pull request (#226)
- Additional edge-case tests for `MarineBatchService.fetchBatch` (#233)

### Changed

- The `functional-verify` CI workflow is paused (no longer run on pull requests) to
  reduce token usage (#230)
- Claude's automated PR review is now skipped on release PRs (`develop` → `main`)
  (#232)

### Fixed

- Picking a new map location now updates the Home screen reliably: an in-flight
  `WeatherProvider`/`MarineProvider` fetch for a since-abandoned pick can no longer
  overwrite the data for the latest one, so the last tap always wins even under rapid
  repeated picks (#228)

## [2026.10.6] - 2026-10-03

### Added

- UV index detail screen (`UvIndexDetailScreen`): the day's hourly UV index as a
  chart with the five WHO/EPA risk bands (low/moderate/high/very high/extreme) and
  a one-line sun-protection hint for the current band; `HourlyMetricChart` gained a
  generic `valueBands` feature (fixed colored value-range strips) to support it (#198)
- Wave height detail screen (`WaveHeightDetailScreen`), opened from the Sea
  section's wave height tile: hourly wave height with the 0.6 m/1.2 m swim
  thresholds, plus wave period and direction per hour (#204)
- Wind speed detail screen (`WindDetailScreen`): hourly wind speed and gusts with
  the 20/40 km/h swim thresholds (#207)
- Water temperature detail screen (`WaterTemperatureDetailScreen`), opened from the
  Sea section: hourly sea surface temperature with four comfort bands (cold/cool/
  pleasant/warm) and a comfort hint (#208)
- Rain chance detail screen (`RainChanceDetailScreen`) and `lib/logic/rain_windows.dart`
  (`rainChanceWindows`/`rainChanceSummary`): hourly rain probability with a
  plain-language summary of the likely rain window(s) for the day (#209)
- Ocean current detail screen (`CurrentDetailScreen`), opened from the Sea
  section's current speed/direction tiles: hourly current speed, a per-hour
  direction arrow strip, and a drift-out warning banner when the current flows
  away from shore at or above 2.0 km/h (#210)
- Every Home stat tile and Sea section tile now opens its own detail screen —
  `DetailMetric` (`lib/presentation/navigation/detail_routes.dart`) covers all
  seven metrics (pressure, UV index, rain chance, wind, wave height, water
  temperature, current); none throw "not implemented" any more
- A procedural `CloudBackdrop` widget: a faint, deterministic blurred-cloud
  texture painted behind the Home header, replacing the missing photographic
  mockup asset (#206)
- A search icon in the map card's location bar (#211): expands into a live
  place-name search (reusing `PlaceSearchProvider`); selecting a result recenters
  the map exactly as a map tap would. The map card's overflow menu is now a small
  sheet with "Beaches" (→ the Search screen) and, when available, "Units"
- `tools/run_tests.sh`/`tools/test_summary.dart`: CI and local test runs now print
  a per-module `Test summary: SUCCESS/FAILURE` line, write JUnit XML
  (`build/reports/junit.xml`) and a Markdown summary; `tools/check_coverage.sh`
  fails CI if total line coverage drops below a tracked baseline (#203)

### Changed

- The Home screen now follows a user-picked location instead of always showing
  fixed Çeşme coordinates: tapping the map re-fetches weather/marine/nearby-beach
  data for that point and updates the header immediately, and the pick is
  persisted via `SharedPreferences` and restored on the next app start. Çeşme
  remains only the first-run default (#205)

## [2026.10.5] - 2026-10-02

### Added

- Hourly marine forecast series (wave height/direction/period, sea surface
  temperature) and nullable ocean current speed/direction on `SeaCondition`/the new
  `SeaHourly` (#190)
- Hourly wind speed, wind gusts and cloud cover on `WeatherHourly` (#184)
- `GeocodingService` (Open-Meteo's free geocoding API) and `PlaceSearchProvider`,
  searching places by name (#185)
- Search screen: a "Places" section searching real places by name via
  `PlaceSearchProvider`; selecting one re-centers the map and beach list (#192)
- Home screen: a "Sea" section under the suggestion pill showing wave height, water
  temperature, and wave/current direction and speed from `MarineProvider` (#196)
- `classifyDirection`/`seawardBearingFromGeometry`
  (`lib/logic/wave_shore_relation.dart`), classifying a current's or wave's direction
  relative to a beach's shore (toward/away/along); wired into the Home Sea section's
  direction tiles with a "stay close!" warning when drifting away from shore (#197)
- A detail-pages foundation (`lib/presentation/navigation/detail_routes.dart`,
  `MetricDetailScaffold`, `HourlyMetricChart`) and the first metric screen, Pressure:
  an hourly chart, min/max/now summary, and a rising/steady/falling trend, opened by
  tapping the Home screen's pressure stat tile (#194)
- `buildForecastAlerts` (`lib/logic/forecast_alerts.dart`): pure rules producing
  wind/wave/cloud/rain/current heads-up alerts from the hourly forecast; not yet
  surfaced anywhere in the UI (#195)
- Amenity markers on the map (toilets, showers, changing rooms, parking, cafés, beach
  clubs), a toggleable legend, and a short name/kind label shown at close zoom (#199)
- A `functional-verify` CI workflow that runs each pull request's acceptance criteria
  as an additional automated check (#173)
- Shared test helpers (`FakeHttpClient`, model builders, `pumpApp`) and
  `docs/testing.md` documenting this repo's test conventions (#189)

### Changed

- `HomeScreen` extracted from `main.dart` into its own file; no behavior change (#183)
- `SwimSuggestionPill`'s color now follows the swim verdict (green/orange/
  red-orange) instead of a single neutral grey (#186)
- Hourly forecast icons are now colored and use each entry's own hour (not the device
  clock) to decide day vs. night (#187)
- A beach's nearby amenities (toilets, showers, cafés, parking, beach clubs,
  lifeguards) now carry their real map position (`BeachAmenity`), not just a boolean
  flag per kind (#188)
- Refreshed `pubspec.lock` (`mgrs_dart`, `proj4dart`, `unicode` and other transitive
  dependencies); no source or dependency-constraint changes (#182)

### Fixed

- The Release workflow now accepts a non-padded release month (`YYYY.M.N`, e.g.
  `2026.10.5`) (#177)
- `ocean_current_velocity` was being converted a second time (m/s → km/h) on top of
  Open-Meteo's already-km/h value, inflating every reading; the extra conversion was
  removed (#193)

## [2026.10.4] - 2026-10-01

### Added

- `OsmAttribution` widget showing the required "© OpenStreetMap contributors" credit
  on the map, tappable to OSM's copyright page (#109)
- `MarineBatchService`, fetching wave height and sea surface temperature for many
  beach coordinates in a single batched Open-Meteo Marine request, with a 1-hour
  in-memory cache (#110)
- `OverpassService`, querying the public Overpass API for nearby beaches with a
  fallback mirror endpoint, 429/504 retry with exponential backoff, and de-duplication
  of concurrent identical requests (#111)
- `BeachResultCard` widget for the Search result sheet: beach name/subtitle, weather
  icon/temperature, and a two-column block of entry fee / wave height / water
  temperature / shoe advice / parking / beach club / cafe info lines (#112)
- `Beach` model extended with OSM-derived fields (surface, lifeguard, fee, amenities,
  geometry) and an OSM-to-`Beach` mapper that merges adjoining beach ways and attaches
  nearby amenities (#113)
- A persistent, grid-cell-keyed cache for OSM beach query results (`BeachCache`), with
  a 7-day TTL, stale-while-revalidate refresh, and a static-beach-list fallback when
  offline (#114)
- `BeachGearAdvisor`: a pure heuristic advising whether shoes/slippers are needed,
  from a beach's OSM `surface` tag (#116)
- The Search screen composed from `SearchField` and `BeachResultCard`, replacing the
  placeholder screen shell (#117)
- `NearbyBeachesProvider`, combining cached/live OSM beach results for a picked
  location with batched marine data (#118)
- The Home screen composed from `StatTile`, `HourlyForecastItem`, and
  `LocationMapCard` into the real dashboard layout (#120)
- Swim suitability scoring (wave height, wind speed, rain chance) and the
  `SwimSuggestionPill` widget showing a one-line verdict (#121)
- `ConditionAlertService`: pure logic deciding when a "conditions turned favorable"
  alert should fire on a swim-suitability transition; not yet wired to any
  notification delivery (#124)
- `WeatherCondition` extended with rain chance, pressure, UV index, an hourly forecast
  list, and daily high/low temperature, parsed from Open-Meteo's hourly/daily fields
  (#125)
- Tap-to-pick location, a 20km search-radius circle, and a gold beach-geometry overlay
  on `LocationMapCard` (#127)
- Loading and error states on the Home and Search screens (#128)
- Navigation from the Home screen's search entry to the Search screen (#129)
- An integration test covering pick location → nearby beaches listed → result card
  showing real fields (#130)
- Pull-to-refresh on the Home and Search screens (#131)
- Unit tests for `MarineProvider` and `WeatherProvider` (#133)
- A name/city search filter on the Search screen's results (#140)
- Unit preferences: a metric/imperial toggle (`UnitSystem`) persisted via
  `SharedPreferences`, with a `UnitPreferencesProvider` (#141)
- Favorites: mark/unmark beaches and filter the Search screen to favorites only,
  persisted via `SharedPreferences` (#144)
- A test covering the Search screen's pull-to-refresh wiring to
  `NearbyBeachesProvider.pickLocation` (#149)

### Changed

- `flutter_map` upgraded to 8.3.2 and `latlong2` to 0.10.x (#119)
- `BeachResultCard`'s beach-info block is now bound to real OSM/marine/gear-advisor
  fields instead of placeholder values (#126)
- The Home screen is now bound to real `WeatherProvider`/`MarineProvider` data instead
  of static placeholders (#132)
- Unit preferences (metric/imperial) wired into the Home and Search screens'
  displayed values (#145)
- `NearbyBeachesProvider` wired into the shipped Home and Search screens, replacing
  the static placeholder beach list (#147)
- `SwimSuggestionPill` wired into the Home screen's suggestion pill using real
  swim-suitability scoring (#148)

### Fixed

- A flaky integration test caused by `WeatherProvider`/`MarineProvider` being used
  after dispose (#142)
- `BeachCache` dropping newer `Beach` fields (amenities, geometry, etc.) when
  serializing/deserializing cached entries (#146)

## [2026.10.3] - 2026-09-29

### Added

- GitHub Actions CI running `flutter analyze` and `flutter test` on every pull request
  and push to `main`/`develop`, plus a fix for the widget test that had gone stale (#31)
- `docs/design.md`, a UI design reference distilled from the team's Penpot mockup
  (dark-theme color tokens, typography, and the `StatTile` / `HourlyForecastItem` /
  `LocationMapCard` / `SearchField` / `BeachResultCard` component list) (#32)
- `sea_surface_temperature` parsed into the `SeaCondition` model (#33)
- An independent, PR-triggered Claude review workflow running alongside the built-in
  Claude Code review (#34)
- `scripts/sync-project-tasks-to-issues.sh`, turning GitHub Project board draft items
  into real issues (#38)
- `Beach` model (`name`, `city`, `latitude`, `longitude`) (#50)
- `WeatherCondition` model parsing Open-Meteo forecast fields (`temperature_2m`,
  `wind_speed_10m`, `weather_code`) (#51)
- CI quality gate on `develop`: a debug APK build, a Linux/xvfb integration test run,
  and an automated reviewer `VERDICT: PASS/BLOCK` check (#58)
- A static list of 10 Turkish beaches (name, city, coordinates) in
  `lib/data/static_beaches.dart` (#59)
- A daily automated screenshot workflow that captures the running app (#60)
- The daily screenshot workflow now also sends the screenshot to Telegram via
  `sendPhoto`, skipped gracefully if the `TELEGRAM_TOKEN` secret isn't set (#61)
- The exported Penpot mockup images in `docs/assets/` (home and search screens) (#66)
- `BeachRepository`, returning the static beach list for now so callers have a stable
  interface to swap in a real beach data source later (#90)
- `WeatherApiService` and `WeatherRepository`, fetching and parsing current
  temperature/wind speed/weather code from the Open-Meteo Forecast API, mirroring the
  existing marine service/repository pair (#91)
- `WeatherProvider`, a `ChangeNotifier` exposing weather loading/data/error state with
  the same shape as `MarineProvider`; not yet wired into `main.dart` (#94)
- Unit tests for `MarineApiService` and `WeatherApiService`, faking `http.Client` so
  neither test hits the network (#95, #96)
- `buildNearbyBeachesQuery`, a pure Overpass QL query builder that finds beaches and
  nearby amenities (showers, toilets, changing rooms, parking, cafés, lifeguards, beach
  resorts) within a radius of a point (#97)
- README sections documenting the two Open-Meteo APIs and the Overpass API used, the
  `lib/` folder structure, and local setup steps (#99)
- `StatTile`, a reusable widget for the home screen's 2×2 stat grid (icon, label, bold
  value, trend indicator) (#100)
- `HourlyForecastItem`, a reusable widget for the horizontally scrollable hourly
  forecast row (time label, icon, bold temperature) (#101)
- A Release workflow (`.github/workflows/release.yml`) that tags, creates a GitHub
  Release, and attaches a debug APK when a `Version YYYY.MM.N` PR is merged to `main` (#102)
- `SearchField`, a reusable rounded "paper" search input for city search (#103)
- `LocationMapCard`, the rounded "paper" map card with a docked location bar (pin icon,
  bold place name, overflow menu) for the home/location-detail screen (#104)

### Changed

- `MarineProvider` is now created and provided app-wide via `ChangeNotifierProvider` in
  `main.dart`, ahead of any screen consuming it (#36)
- Removed a duplicate, dead nested `BeachIQ/BeachIQ/` project tree (133 files) from the
  repository (#37)
- Refreshed `pubspec.lock` to pick up a newer transitive `logger` version; no source or
  dependency-constraint changes (#64)
- Corrected `docs/design.md` against the real Penpot export: the map card is a real
  OpenStreetMap-style map with gold beach highlights (not a stylized teal coastline),
  the stat grid/hourly row have no card background, the smart-suggestion pill is a light
  grey gradient, and the search-sheet info is two columns of plain text lines rather
  than chips (#66, #88)

### Fixed

- `MarineRepository` now throws a clear exception instead of crashing when the marine
  API response is missing or has a malformed `current` field (#35)
- The independent Claude PR review workflow's authentication (an OIDC token fetch
  failure; switched to an OAuth token) (#49)
