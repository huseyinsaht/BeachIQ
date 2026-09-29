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
- Current weather (temperature, wind speed, weather code) can be fetched from the
  Open-Meteo Forecast API through `WeatherRepository` / `WeatherProvider`, mirroring
  the marine data path, but `WeatherProvider` isn't created anywhere in `main.dart` yet.
- A static list of 10 Turkish beaches exists in code (`BeachRepository`), but isn't
  shown on any screen.
- A query builder (`buildNearbyBeachesQuery`) can build the Overpass QL query for
  finding beaches and nearby amenities (showers, toilets, parking, cafés, lifeguards,
  beach resorts) around a point, but nothing calls the Overpass API with it yet.
- Four of the reusable screen components from `docs/design.md` exist as standalone
  widgets with their own tests — `StatTile`, `HourlyForecastItem`, `SearchField`,
  `LocationMapCard` — but none of them are placed on `HomeScreen` or any other screen.

## Planned

From the roadmap on `README.md` (`main` branch):

- Core wave-height dashboard
- Nearby beach search
- Google Play launch
- Condition alerts

`docs/design.md` describes the intended home/location-detail and search screens (map
card, stat grid, hourly forecast, beach search results) that these planned features
would live in. Four of the five reusable components it calls for now exist in code (see
above) but aren't assembled into either screen yet; `BeachResultCard` (the search
result sheet) doesn't exist yet either.
