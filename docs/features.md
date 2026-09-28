# Features

## Today

- A single home screen showing a live map (OpenStreetMap tiles via `flutter_map`),
  centered on the Turkish Aegean coast.

That is currently the entire user-visible surface of the app.

## Built, but not yet visible in the app

These exist in code (with tests) but nothing in the UI shows them yet:

- Sea condition data (wave height, wave direction, wave period, sea surface
  temperature) can be fetched from the Open-Meteo Marine API through
  `MarineRepository` / `MarineProvider`, but no screen calls it yet.
- A `WeatherCondition` model can parse temperature, wind speed, and weather-code data,
  but nothing fetches or displays it yet.
- A static list of 10 Turkish beaches exists in code, but isn't shown on any screen.

## Planned

From the roadmap on `README.md` (`main` branch):

- Core wave-height dashboard
- Nearby beach search
- Google Play launch
- Condition alerts

`docs/design.md` describes the intended home/location-detail and search screens (map
card, stat grid, hourly forecast, beach search results) that these planned features
would live in — none of that UI exists yet.
