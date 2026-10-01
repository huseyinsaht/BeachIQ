# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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
