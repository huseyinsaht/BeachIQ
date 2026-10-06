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
  search; picking a result re-centers everything exactly as a map tap would. Tapping a
  beach card in the Search screen returns to Home with that beach selected: the map
  re-centers on it, highlights it with a distinct white border among the gold
  outlines, and a compact info row for it appears below the map. The map card's
  overflow menu opens "Beaches" (the Search screen) and, when available, "Units".
- A faint, decorative cloud texture behind the header.
- A "smart suggestion" pill giving a one-line swim verdict (good/caution/poor), colored
  green/orange/red-orange to match, from wave height, wind speed and rain chance —
  though the wave-height input is only filled in after a pull-to-refresh or a fresh
  location pick (see `docs/architecture.md` § State flow).
- An upcoming-alerts list between the suggestion pill and the stat grid: heads-up,
  one-line warnings (wind, waves, incoming current, clouds, rain) for a fast rise or
  threshold crossing later in the day, colored by severity and sorted most-severe
  first, restricted to daylight hours at the selected location — shown only when
  there's something to flag. A visually distinct "Next hour" row above it always
  flags an imminent change in the next hour, even after sunset (unlike the rest of
  the list, it isn't limited to daylight).
- A real notification when conditions turn favorable: if the swim verdict for the
  selected location flips from caution/poor/unknown to good while the app is running,
  a local notification is shown (after a one-time permission prompt). There is no
  settings screen yet to turn this off, and it only fires while the app is open —
  there's no background/scheduled check.
- A "Sea" section (once marine data has loaded) showing wave height, water
  temperature, wave direction and current speed/direction — when the nearest beach's
  shoreline can be derived from OpenStreetMap data, the direction readings also say
  whether the water is moving toward, away from, or along the shore, with a visible
  warning when it's moving away (drift-out/rip-current risk).
- A 2×2 stat grid — wind speed, rain chance, water depth, and UV index — and a
  scrollable hourly forecast row (with colored, time-of-day-aware weather icons), both
  bound to real data. Wind speed, rain chance and water depth each show a short
  colored status word (e.g. "Calm", "High", "Gentle") alongside their value.
- **Every stat tile and every Sea-section tile (except wave direction) opens its own
  detail screen**: a min/max/now summary and metric-specific context, most with an
  hourly chart (a value scale and time-of-day labels on its axes) —
  UV index's five colored risk bands and a protection hint; Wind's speed-and-gusts
  chart with calm/moderate/strong thresholds; Rain chance's plain-language "likely
  between X and Y" summary; Wave height's period and direction alongside the swim
  thresholds; Water temperature's four comfort bands and hint; Ocean current's
  per-hour direction strip and a drift-out warning banner when the current is heading
  out to sea. Water depth's detail screen has no hourly chart — instead, a
  distance-vs-depth profile showing roughly how far out the water stays comfortably
  shallow before the seabed drops away (gentle/moderate/steep), plus lifeguard
  presence, current wave height and a drift-out warning as context — an approximate,
  non-swimmer indication from a coarse offshore depth dataset, never a safety
  guarantee.
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

- `BeachRepository`/`staticBeaches` (10 hardcoded Turkish beaches) still exist as the
  Search screen's fallback when no live provider is supplied (e.g. tests), but the
  shipped app always supplies one.
- The pressure tile and its detail screen (rising/steady/falling trend) are still in
  the code and tested, but no longer reachable from the Home screen — the stat grid's
  fourth slot now shows water depth instead (see "Today" above).

## Planned

From the roadmap on `README.md`:

- Google Play launch
- A settings screen to turn condition alerts off, and background/scheduled delivery
  so the "conditions turned favorable" notification can fire while the app isn't
  open (today it only fires while the app is running — see "Today" above)

The core wave-height dashboard and nearby beach search from the original roadmap are
now implemented, as described above.
