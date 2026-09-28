# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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

### Changed

- `MarineProvider` is now created and provided app-wide via `ChangeNotifierProvider` in
  `main.dart`, ahead of any screen consuming it (#36)
- Removed a duplicate, dead nested `BeachIQ/BeachIQ/` project tree (133 files) from the
  repository (#37)

### Fixed

- `MarineRepository` now throws a clear exception instead of crashing when the marine
  API response is missing or has a malformed `current` field (#35)
- The independent Claude PR review workflow's authentication (an OIDC token fetch
  failure; switched to an OAuth token) (#49)
