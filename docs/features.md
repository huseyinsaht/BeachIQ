# Features

## Today

**Home screen** — a live dashboard for a fixed location (Çeşme, İzmir):

- Current temperature, condition description and daily high/low, from the Open-Meteo
  Forecast API.
- An interactive map card: tap anywhere to search that location, a 20km search-radius
  circle, and nearby beaches drawn as gold outlines (from live OpenStreetMap data).
- A "smart suggestion" pill giving a one-line swim verdict (good/caution/poor) from
  wave height, wind speed and rain chance — though the wave-height input is only
  filled in after a pull-to-refresh (see `docs/architecture.md` § State flow).
- A 2×2 stat grid (wind speed, rain chance, pressure, UV index) and a scrollable hourly
  forecast row, both bound to real data.
- A tappable search entry that opens the Search screen; pull-to-refresh re-fetches
  weather and marine data.
- A metric/imperial unit toggle (via the map card's overflow menu), persisted across
  restarts.

**Search screen** — real nearby beaches, not a placeholder list:

- Beaches near the picked location (from OpenStreetMap via the Overpass API), each
  shown as a result card with name, area, wave height, water temperature, entry fee
  (free/paid/unknown), shoes/slippers advice, and nearby car park/beach club/café —
  any field the data source has no answer for is shown as "No data"/"Unknown" rather
  than invented.
- A name/city text filter over the results.
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
