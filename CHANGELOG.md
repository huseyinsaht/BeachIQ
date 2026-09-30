# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `OsmAttribution`, a small "© OpenStreetMap contributors" credit required by OSM's
  ODbL license wherever OSM data or tiles are shown (#109)
- `MarineBatchService`, fetching wave height and sea surface temperature for many beach
  coordinates in a single batched Open-Meteo Marine API request, with a 1-hour
  in-memory cache (#110)
- `OverpassService`, querying the Overpass API for nearby beaches and amenities, with a
  fallback mirror endpoint, retry/backoff on rate limiting, and de-duplication of
  concurrent identical queries (#111)
- `BeachResultCard`, the Search screen's result card showing a beach's entry fee, wave
  height, water temperature, shoe advice, and nearby amenities (#112)
- `mapOverpassToBeaches`, turning a raw Overpass response into `Beach` objects —
  merging adjoining OSM ways into a single beach and attaching nearby amenities within
  150m — and new OSM-derived fields (surface, fee, amenities, geometry) on the `Beach`
  model (#113)
- `BeachCache`, a persistent, stale-while-revalidate cache of OSM beach results keyed
  by grid cell, falling back to the static beach list when offline (#114)
- `BeachGearAdvisor` (`adviseOnShoes`), advising whether shoes/slippers are worth
  bringing based on a beach's ground surface (#116)
- `NearbyBeachesProvider`, combining cached OSM beaches with batched marine data for a
  picked map location, debounced against rapid repeated picks (#118)
- Swim suitability scoring (`scoreSwimSuitability`) and the `SwimSuggestionPill`
  widget, turning wave height/wind speed/rain chance into a good/caution/poor verdict
  (#121)
- `ConditionAlertService`, deciding when a "conditions turned favorable" swim alert
  should fire, given a before/after suitability verdict (#124)
- Tap-to-pick location on `LocationMapCard`, drawing a 20km search radius circle and
  gold beach-geometry overlays for the picked point's nearby beaches (#127)
- Loading and error states for the Home and Search screens (#128)
- Home → Search navigation: tapping the Home search field opens the Search screen
  (#129)
- An integration test covering the full nearby-beaches flow: pick a location on the
  map, list real OSM beaches, and show their real marine/amenity fields on a result
  card (#130)
- Pull-to-refresh on the Home and Search screens (#131)
- Unit tests for `MarineProvider` and `WeatherProvider` (#133)

### Changed

- Composed the Search screen from `SearchField` and `BeachResultCard`, rendering the
  static placeholder beach list (#117)
- Upgraded `flutter_map` to 8.3.2 and `latlong2` to 0.10.x (#119)
- Composed the Home screen from `StatTile`, `HourlyForecastItem`, and `LocationMapCard`
  (#120)
- Extended `WeatherCondition` with rain chance, pressure, UV index, and hourly/daily
  forecast fields (#125)
- Bound `BeachResultCard` to real OSM/marine/gear-advisor fields in the nearby-beaches
  pipeline (exercised by the integration test; not yet wired into a shipped screen)
  (#126)
- Bound the Home screen to real `WeatherProvider` data (temperature, wind speed, rain
  chance, pressure, UV index, hourly forecast) and to `MarineProvider`'s loading/error
  state (#132)

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
