# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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
