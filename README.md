<div align="center">

# 🌊 BeachIQ

**Know before you go.**
Real-time wave height and swim conditions — right in your pocket.

[![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-coming%20soon-yellow?style=for-the-badge)]()

<!-- Once live, swap the badge above for a Play Store button, e.g.: -->
<!-- [![Get it on Google Play](https://img.shields.io/badge/Google%20Play-Get%20BeachIQ-414141?style=for-the-badge&logo=google-play&logoColor=white)](YOUR_PLAY_STORE_LINK) -->

</div>

---

## 🏄 Why BeachIQ?

Ever shown up to the beach only to find the waves are flat — or way too rough?
BeachIQ tells you what to expect *before* you leave the house, so every trip to the water is the right call.

## ✨ What you get

- 🌊 **Live wave height** — no more guessing
- 📍 **Nearby spots** — find the best conditions close to you
- 📊 **One glance, all you need** — clean dashboard, no clutter
- 🔔 *(coming soon)* Alerts when conditions turn perfect

## 📱 See it in action

<p align="center">
  <i>Screenshots coming soon</i>
</p>

## 📥 Get BeachIQ

<!-- Add once published -->
BeachIQ is launching on **Google Play** — stay tuned!

## 🗺️ What's next

- [x] Core wave-height dashboard
- [x] Nearby beach search
- [ ] Google Play launch
- [ ] Condition alerts

---

<div align="center">
<sub>Built with Flutter 💙</sub>
</div>


---

## 🛠️ For developers

### APIs used

BeachIQ pulls data from two free, keyless [Open-Meteo](https://open-meteo.com/) endpoints — no API
key or account is required for local development.

#### Open-Meteo Weather Forecast API

- Base URL: `https://api.open-meteo.com/v1/forecast`
- Used by: `lib/data/services/weather_api_service.dart` via `lib/data/repositories/weather_repository.dart`
- Provides: current weather (temperature, wind speed, weather code) for a given latitude/longitude —
  see `lib/data/models/weather_condition.dart`.

#### Open-Meteo Marine Weather API

- Base URL: `https://marine-api.open-meteo.com/v1/marine`
- Used by: `lib/data/services/api_service.dart` via `lib/data/repositories/marine_repository.dart`
- Provides: sea state (wave height, wave direction, wave period, sea surface temperature) for a given
  latitude/longitude — see `lib/data/models/sea_condition.dart`.

Both services take an injectable `http.Client`, so tests fake the client instead of hitting the
network (see `test/data/services/`).

BeachIQ also queries the [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) (OSM data)
for nearby beaches; `lib/data/services/overpass_query_builder.dart` builds that query.

### Folder structure

```
lib/
  data/
    models/          # Plain data classes (Beach, Place, SeaCondition, WeatherCondition, ...)
    repositories/    # Fetch + adapt service responses for the UI/providers
    services/        # Thin HTTP clients (Open-Meteo, Overpass, geocoding) and local caches
    mappers/         # Adapt raw OSM/Overpass data into app models
    static_beaches.dart
  logic/
    providers/       # ChangeNotifier providers exposing weather/marine/beach state to the UI
    (top-level files) # Pure logic helpers (swim suitability, unit prefs, alerts, chart axes, ...)
  presentation/
    navigation/      # Route definitions for the per-metric detail screens
    screens/         # Top-level screens (Home, Search)
    screens/detail/  # Per-metric detail screens (pressure, wind, UV, wave height, ...)
    theme/           # Shared design tokens (color palettes)
    widgets/         # Reusable UI building blocks (stat tiles, charts, map card, ...)
  main.dart          # App entry point and dependency/provider wiring

test/                # Unit/widget tests, mirroring the lib/ folder structure
integration_test/    # End-to-end integration tests
docs/                # Design reference (docs/design.md) and mockup assets
```

### Setup

1. Install a Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`'s
   `environment.sdk` (currently `^3.8.1`).
2. Fetch dependencies:
   ```
   flutter pub get
   ```
3. Run static analysis and tests:
   ```
   dart analyze
   flutter test
   ```
4. Run the app:
   ```
   flutter run
   ```

No API keys or `.env` file are needed — both Open-Meteo endpoints above are public and keyless.
