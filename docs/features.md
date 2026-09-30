# Features

## Today

The app has two real screens, Home and Search, reachable by navigation:

- **Home** shows live current weather for a fixed location (Çeşme, İzmir): temperature,
  condition description, today's high/low, and a 2×2 stat grid (wind speed, rain
  chance, pressure, UV index) — all fetched from the Open-Meteo Forecast API. An
  hourly forecast row scrolls through the upcoming hours (trimmed to start at the
  current hour, capped to 24 entries). Pull-to-refresh re-fetches the data without
  tearing down the screen.
- A rounded map card on Home shows the location on OpenStreetMap tiles, with the
  required "© OpenStreetMap contributors" attribution.
- Tapping the search field on Home opens **Search**, a full screen with its own search
  input and a scrollable list of result cards under "Beaches Near". The back chevron
  returns to Home. The result list is currently the static 10-beach placeholder list
  (name, city; temperature and beach-info fields are not filled in), not live nearby
  results.
- A "conditions look good" suggestion pill is shown on Home, but its text is currently
  a fixed string, not computed from real conditions (see below).
- The stat grid's trend arrows/deltas (e.g. "↑ 2 km/h") are fixed placeholder values,
  not derived from historical data.

## Built, but not yet visible in the app

These exist in code, are unit/widget-tested, and (for the nearby-beaches pipeline)
proven end-to-end in `integration_test/app_test.dart` — but nothing in the shipped app
screens uses them yet:

- **Nearby beach search via OpenStreetMap.** Tapping a location on a map can already
  (in code) query the Overpass API for real beaches and amenities within 20km, merge
  adjoining OSM ways into single beaches, attach nearby showers/toilets/changing
  rooms/parking/cafés/lifeguards/beach clubs, cache results per grid cell (with an
  offline fallback to the static beach list), and enrich the results with batched wave
  height and sea surface temperature. `LocationMapCard` already knows how to draw the
  resulting beaches as gold overlays when given a `NearbyBeachesProvider` — but
  `HomeScreen` doesn't pass it one, and `SearchScreen` doesn't consume one either, so
  none of this reaches the real Home or Search screens today.
- **Wave/sea condition data.** `MarineProvider` fetches wave height, wave direction,
  wave period and sea surface temperature from the Open-Meteo Marine API on every
  Home-screen load, but only its loading/error state is used — the actual values are
  never shown on screen.
- **Swim suitability scoring.** `scoreSwimSuitability` can turn wave height, wind speed
  and rain chance into a good/caution/poor verdict with a one-line message, and
  `SwimSuggestionPill` can render it — but Home's suggestion pill still shows a fixed
  string instead of this real computation.
- **Beach gear advice.** `adviseOnShoes` can turn a beach's OSM ground-surface tag into
  shoes-advised/not-needed/unknown advice; `BeachResultCard` has a slot for it, but
  nothing currently computes and passes a value in the shipped app.
- **Condition alerts (first slice only).** `ConditionAlertService` can decide *when* a
  "conditions just became favorable" alert should fire, given a before/after swim
  verdict. This is decision logic only — there is no actual notification permission
  request, scheduling, or delivery mechanism yet, and nothing calls it from the app.

## Planned

From the roadmap on `README.md`:

- Core wave-height dashboard
- Nearby beach search
- Google Play launch
- Condition alerts

`docs/design.md` describes the intended Home/location-detail and Search screens. All
five of its reusable components (`StatTile`, `HourlyForecastItem`, `SearchField`,
`LocationMapCard`, `BeachResultCard`) now exist and are used on a real screen; what
remains for these roadmap items is largely wiring already-built logic and data
(`NearbyBeachesProvider`, `scoreSwimSuitability`, `MarineProvider`'s fetched data,
`adviseOnShoes`) into the Home and Search screens, plus the alert-delivery mechanism
`ConditionAlertService` doesn't yet cover.
