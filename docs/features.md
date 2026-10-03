# Features

## Today

**Home screen** — a live dashboard for a **selected location** (wherever the user last
picked on the map or by search; Çeşme, İzmir is only the first-run default, and the
pick survives an app restart):

- Current temperature, condition description and daily high/low, from the Open-Meteo
  Forecast API.
- An interactive map card: tap anywhere to re-center on that location, a 20km
  search-radius circle, nearby beaches drawn as gold outlines (from live OpenStreetMap
  data), and — once zoomed in — colored pins for nearby toilets, showers, changing
  rooms, parking, cafés and beach clubs, with a toggleable legend and a
  tap-for-details card. A search icon in the map card expands into a live place-name
  search; picking a result re-centers everything exactly as a map tap would. The map
  card's overflow menu opens "Beaches" (the Search screen) and, when available,
  "Units".
- A faint, decorative cloud texture behind the header.
- A "smart suggestion" pill giving a one-line swim verdict (good/caution/poor), colored
  green/orange/red-orange to match, from wave height, wind speed and rain chance —
  though the wave-height input is only filled in after a pull-to-refresh or a fresh
  location pick (see `docs/architecture.md` § State flow).
- A "Sea" section (once marine data has loaded) showing wave height, water
  temperature, wave direction and current speed/direction — when the nearest beach's
  shoreline can be derived from OpenStreetMap data, the direction readings also say
  whether the water is moving toward, away from, or along the shore, with a visible
  warning when it's moving away (drift-out/rip-current risk).
- A 2×2 stat grid (wind speed, rain chance, pressure, UV index) and a scrollable hourly
  forecast row (with colored, time-of-day-aware weather icons), both bound to real
  data.
- **Every stat tile and every Sea-section tile (except wave direction) opens its own
  detail screen**: an hourly chart, a min/max/now summary, and metric-specific context
  — Pressure's rising/steady/falling trend; UV index's five colored risk bands and a
  protection hint; Wind's speed-and-gusts chart with calm/moderate/strong thresholds;
  Rain chance's plain-language "likely between X and Y" summary; Wave height's period
  and direction alongside the swim thresholds; Water temperature's four comfort bands
  and hint; Ocean current's per-hour direction strip and a drift-out warning banner
  when the current is heading out to sea.
- Pull-to-refresh re-fetches weather and marine data for the currently selected
  location.
- A metric/imperial unit toggle (via the map card's overflow menu), persisted across
  restarts.

**Search screen** — real nearby beaches, not a placeholder list:

- Beaches near the picked location (from OpenStreetMap via the Overpass API), each
  shown as a result card with name, area, wave height, water temperature, entry fee
  (free/paid/unknown), shoes/slippers advice, and nearby car park/beach club/café —
  any field the data source has no answer for is shown as "No data"/"Unknown" rather
  than invented.
- A "Places" section: typing searches real places by name anywhere (via Open-Meteo's
  geocoding API), not just the current results; picking one re-centers the map and
  beach list on it.
- A name/city text filter over the beach results.
- Favorite beaches: a heart toggle on each result and a header star button to show
  favorites only, persisted across restarts.
- The same metric/imperial toggle as Home, and pull-to-refresh.
- Beach results are cached on-device (by map grid cell) so repeat visits to the same
  area don't always re-query Overpass, and fall back to a static placeholder list if
  offline with nothing cached.

**Cross-cutting**

- OpenStreetMap attribution is shown on the map, as required by OSM's license.

## Built, but not yet user-facing

- `ConditionAlertService` can decide *when* a "conditions turned favorable" alert
  should fire (on a caution/poor/unknown → good transition), but nothing in the app
  schedules a background check or shows an actual notification yet — there is no
  alerts feature a user can turn on.
- `buildForecastAlerts` can produce wind/wave/cloud/rain/current heads-up alerts
  ("wind picks up between 10:00 and 11:00", etc.) from the hourly forecast, but
  nothing in the app shows these to the user yet — no screen or notification surfaces
  them.
- `BeachRepository`/`staticBeaches` (10 hardcoded Turkish beaches) still exist as the
  Search screen's fallback when no live provider is supplied (e.g. tests), but the
  shipped app always supplies one.

## Planned

From the roadmap on `README.md`:

- Google Play launch
- Condition alerts (the underlying trigger logic exists — see above — but no delivery
  mechanism, permission handling, or background scheduling has been built)

The core wave-height dashboard and nearby beach search from the original roadmap are
now implemented, as described above.
