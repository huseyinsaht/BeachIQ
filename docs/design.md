# BeachIQ UI design reference

Source of truth: the team's Penpot mockup (two screens — home / location detail, and search). The
exported images are in this repo and **take precedence over the prose below** whenever they disagree:

- [`docs/assets/mockup-home.png`](assets/mockup-home.png) — Home / location detail
- [`docs/assets/mockup-search.png`](assets/mockup-search.png) — Search
- [`docs/assets/mockup-full.png`](assets/mockup-full.png) — both screens side by side

This doc distills the mockup into a reference other PRs (human or automated) can build against without
needing Penpot access. Colors below are read off the exported images and are **approximate**.

This maps to the "PHASE 4 — UI: Beach List and Detail Screen" board items (issues #16–21) and should
guide the earlier phases' screens too once they get a UI pass.

## Reading the mockup: what is a design and what is placeholder

The mockup was built from a weather-app template. Do **not** copy these literally:

- **Serif text** (stat labels/values, "Hourly forecast", hourly items, the search-sheet info lines) is
  a font-fallback artifact of the export. The real typeface is the geometric sans used in "My Location",
  "Search", "Cesme, Izmir" and "Altinkum Beach" (Poppins-like). Use one sans family everywhere.
- **Placeholder data:** "Seongnam-si" (a Korean city from the template; the real location is
  "Cesme, Izmir"), the pill text "bassd scha" and its black-square icon, pressure "720 hpa" (not a
  plausible sea-level value), and hourly temperatures that jump around (10°, 8°, 5°, 12°, 9°, 12°).
- **The info lines in the search sheet are German/Austrian notes-to-self, not copy.** They mean:
  `eintritt preis` = entry price, `welle höhe` = wave height, `slope` = beach/seabed slope,
  `google comment` = reviews, `autopark` = car park, `beach club`, `cafe`, and
  `ob ma a schuhe brauchen` = "do I need shoes / slippers?". The set of facts is intentional, the
  wording is not. See "Beach info lines" below for the real data behind each.

## Visual direction

Dark-mode weather/beach app. Deep navy vertical gradient background on both screens (darker at the
top, slightly lighter and bluer toward the bottom) with a faint **cloud backdrop** in the top-right
behind the status bar/header (a second, very faint cloud floats mid-screen on Search). On Home this is
`CloudBackdrop` (`lib/presentation/widgets/cloud_backdrop.dart`): a few large, heavily blurred,
low-opacity (~0.08-0.15) white ellipses painted procedurally with `CustomPainter` — see "Out of scope
for this doc" below.
White primary text, muted blue-gray secondary text, and light "paper" surfaces (map card, search field,
result sheet) with navy-indigo text. Generous corner radii (~24px). No hard borders; the stat grid and
hourly row have **no card background at all** — they sit directly on the gradient.

### Color tokens (approximate — verify against Penpot)

| Token | Hex | Use |
|---|---|---|
| `bg.base` | `#0D1220` | Screen background |
| `bg.gradientBottom` | `#2A3145` | Bottom of the background gradient |
| `surface.pill` | `#D9DBDF` → `#F2F3F5` | Smart suggestion pill, `unknown` verdict only (see below) |
| `surface.pill.good` | `#1B5E20` → `#2E7D32` | Smart suggestion pill, `good` verdict (white text/icon) |
| `surface.pill.caution` | `#92400E` → `#B45309` | Smart suggestion pill, `caution` verdict (white text/icon) |
| `surface.pill.poor` | `#7F1D1D` → `#9A3412` | Smart suggestion pill, `poor` verdict (white text/icon) |
| `surface.paper` | `#FFFFFF` | Map card, search field, search-result sheet |
| `map.water` | `#A8D3E0` | Sea on the map |
| `map.land` | `#EDEBE6` | Land on the map |
| `map.beach` | `#C9A227` | Beach highlight on the map (see below) |
| `text.primary` | `#FFFFFF` | Headlines, temperatures, values |
| `text.onPaper` | `#2E3057` | Text on light surfaces (place name, beach name, temperature) |
| `text.secondary` | `#8B93A6` | Subtitles, labels, unit text |
| `icon.sun` | `#FFC94D` | Sun glyph in weather icons |
| `color.warning` | `#EF5350` | Away-from-shore shore-relation label (Sea section, see below) |

### Typography

- Large temperature / hero number: bold, ~40–48pt, white.
- Screen title ("My Location", "Search"): bold, ~20pt, white.
- Section labels ("Hourly forecast", "Beaches Near"): regular, ~13pt, `text.secondary`, often paired
  with a small leading icon.
- Home stat-grid card values (wind speed, rain chance, pressure, UV index — issue #215): bold, ~26–28pt,
  white, with the unit as a separate, visually smaller/secondary run right next to it (~14pt,
  `text.secondary`), never concatenated into the same string. Deviates from this doc's earlier
  ~16–18pt figure, which read too small on a phone screen (Vaen's 2026-10-03 feedback); metric detail
  screens (below) are unchanged — they already show a 44pt hero value.
- Card labels: regular, ~12pt, `text.secondary`.

## Screen: Home / location detail

Every value on this screen — the header subtitle, hero temperature, condition row, map card, smart
suggestion pill, Sea section, stat grid and hourly row — belongs to one **selected location** (issue
#157), never a fixed city: whatever point the user last tapped on the map, restored from
`SharedPreferences` on app start. Çeşme (38.3220, 26.3260) is only the **first-run default**, shown
until the user has ever picked a point; after that, the selected location (and its persisted copy)
always wins. Tapping a new point on the map card re-fetches weather, marine data and nearby beaches for
it and updates the header/place name immediately — there is no separate "confirm" step. The place name
shown is a real name when the location came from a search result, otherwise (a bare map tap)
formatted coordinates (`"38.3220°N, 26.3260°E"`), since reverse geocoding isn't available
(`GeocodingService`, #156, only supports forward name search).

Top to bottom:

1. **Header row** — location label stack on the left ("My Location" bold + city/district subtitle in
   `text.secondary`), current temperature large on the right, both on `bg.base`.
2. **Condition row** — condition text ("Partly Cloudy") left, high/low ("H:29° L:15°") right, both
   `text.secondary`, small size.
3. **Map card** (`surface.paper`, rounded ~24px) — a **real OpenStreetMap-style map** (light land,
   light-blue sea, roads and building footprints) — not a stylized or teal-coastline illustration. The
   mockup centers on Çeşme and **highlights beaches as gold polygons/lines along the shore**
   (`map.beach`); this is the same beach overlay as the Overpass Turbo `natural=beach` styling, so the
   app must draw beach geometry on the map. A location bar is docked to the card's bottom edge
   (same white surface): small grey "Location" label, place name bold in `text.onPaper`, and an
   overflow ("...") menu on the right. There is no pin glyph in the home version of the bar.
   **Search icon** (issue #158) — a search icon sits in the bar, before the overflow menu; tapping it
   expands the bar into a real `SearchField` with live geocoding results underneath (loading/empty/
   error/loaded, the same states `SearchScreen`'s own "Places" section uses), replacing the mockup's
   separate standalone search entry below the map card. Selecting a result recenters the map exactly
   as a map tap would. The overflow menu itself now opens a small sheet with "Beaches" (→
   `SearchScreen`, the beach list/favorites/filter) and, when available, "Units".
   **Amenity markers** (issue #172) — each beach's real toilets/showers/changing rooms/parking/cafes/
   beach clubs/lifeguard posts (`Beach.amenities`, from #171) are drawn as Google-Maps-style pins: a
   filled colored circle with a white glyph and a soft drop shadow (food & drink orange `#F57C00`;
   toilets/showers/changing rooms blue `#1A73E8`; parking blue-grey `#5F6368` with a "P"; beach club
   teal `#00897B`; lifeguard red `#D93025`). A legend row of toggle chips (top-left of the map, one
   chip per kind actually present — never the full set) shows/hides a kind's markers. Below
   `kAmenityMarkersMinZoom` markers are hidden entirely rather than drawn as an unreadable cluster of
   overlapping pins; at or above it each pin also shows a short white, shadowed label underneath it
   (its name, or its kind when OSM has no name). Tapping a marker grows it slightly and shows a small
   card with its name (or kind, when OSM has no name) and distance from the current pick. Markers never
   intercept the map's own
   pan/zoom or the radius circle's tap-to-pick.
4. **Smart suggestion pill** — a single full-width rounded pill, one short line + leading icon, verdict
   text. The mockup shows a single light-grey pill; this deliberately extends it: the background
   gradient, foreground color and icon follow the swim verdict's level (`VerdictPalette`) — good =
   green (`surface.pill.good`), caution = orange (`surface.pill.caution`), poor = red-orange
   (`surface.pill.poor`), unknown = the mockup's neutral grey (`surface.pill`, dark `text.onPaper`).
   Every variant keeps >= 4.5:1 text/icon contrast against its gradient. A verdict change animates the
   pill's colors rather than snapping. The Home screen's own `bg.base`/`bg.gradientBottom` background is
   unrelated and never changes with the verdict. Muted, not a primary CTA.
5. **Home: alert list** (issue #169) — not in the mockup; this extends it. Sits directly under the
   smart suggestion pill and above the Sea section/stat grid: one row per upcoming
   `ForecastAlert` (`lib/logic/forecast_alerts.dart`'s `buildForecastAlerts`, fed the selected
   location's real `WeatherProvider`/`MarineProvider` hourly series), each a small type icon (wind,
   waves, clouds, rain or current), the alert's one-line message, and a compact time-window label
   underneath (e.g. "09:00 - 10:00"). The icon's color follows severity, not type: amber
   (`#FFB74D`) for `moderate`, `color.warning`'s red (`#EF5350`) for `high` — the same red the Sea
   section's away-from-shore label uses, since both mean "pay attention". Alerts are sorted most
   severe first, with an earlier time window breaking a tie between two alerts of the same
   severity. The whole list (`ForecastAlertList`) renders nothing — no spacer, no gap — when there
   are no upcoming alerts, exactly like the Sea section's own "no data yet" treatment. Muted,
   list-style rows, no card background or border, matching the rest of Home's "no tile background"
   direction. Tapping a row does nothing yet (optional per the issue) — this is a heads-up list,
   not a notification: pushing these as device notifications is explicitly out of scope (see the
   follow-up note in `lib/logic/condition_alert_service.dart`).
6. **Sea section** (issue #163) — not in the mockup (it has no wave/current fields at all); this
   extends it. Sits under the smart suggestion pill and above the stat grid: a "Sea" section label
   (small wave icon, matching the "Hourly forecast" label's styling) over a horizontally scrollable
   row of five tiles — wave height, water temperature, wave direction, current speed, current
   direction — in the stat grid's icon/label/value style but with no trend row (none of these values
   have a meaningful delta the rest of the app already surfaces). Only rendered once
   `MarineProvider.currentData` is loaded; any null field inside it shows "No data", never `0`.
   Direction tiles pair a rotated arrow (clockwise from "up", by compass bearing) with a cardinal
   label, and the two direction fields use **different conventions** — do not render them the same
   way: wave/wind direction is meteorological "coming from" (bearing is where the wave originates, so
   the tile reads e.g. "from NW" and its arrow is rotated to the *opposite* bearing, i.e. where the
   wave is actually heading), while ocean current direction is oceanographic "flowing toward" (bearing
   already is where the current is heading, so the tile reads e.g. "toward SE" and its arrow is
   rotated straight to that bearing). See the doc comments on `SeaCondition.waveDirection` /
   `.currentDirection` for the authoritative explanation. When the nearest fetched beach (by real
   distance to the selected point, not list order) has usable OSM geometry and amenities (issue #164),
   the current-direction tile (primary) and wave-direction tile (secondary) each show a small
   shore-relation line under the value — "(towards shore)" / "(away from shore — stay close!)" /
   "(along shore)" — with the away-from-shore case in `color.warning` and bold, wrapping onto extra
   lines rather than being clipped, since it signals drift-out / rip-current risk. The derivation
   (`lib/logic/wave_shore_relation.dart`'s `seawardBearingFromGeometry`) is a best-effort heuristic
   (land-side amenities as an anchor), not a guaranteed fact; when no geometry/amenities are
   available, or the derivation itself cannot determine a direction, the tiles show cardinal-only
   labels and never an invented relation.
7. **Stat grid** — 2×2 grid, **no tile background**: wind speed, rain chance, water depth, UV index
   (issue #217 replaces the mockup's pressure tile with water depth — see below). Each tile: small line
   icon at the left, `text.secondary`-style label above a large value (with its unit as a secondary run
   — see "Typography"), and, for wind speed/rain chance/UV index, a small trend indicator (▴/▾ + delta)
   at the bottom-right of the tile. UV uses a decimal comma in the mockup (locale formatting).
   **Status word (issue #215)** — not in the mockup; this extends it. Wind speed (Calm/Moderate/Strong,
   `lib/logic/wind_status.dart`, reusing `swim_suitability.dart`'s own moderate/high thresholds), rain
   chance (Low/Medium/High, `lib/logic/rain_status.dart`, same thresholds), UV index (its band —
   Low/Moderate/High/Very high/Extreme, `lib/logic/uv_band.dart`) and water depth (its steepness —
   Gentle/Moderate/Steep, `lib/logic/shallow_entry_status.dart`) each show a short colored status word
   under the value: a small dot plus the word, in green/orange/red (wind, rain, water depth) or the UV
   band's own color (the same color the UV index detail screen's chart bands use). `MetricDetailScaffold`
   shows the same word/color under its hero value on the matching detail screen, so Home and the detail
   screen never disagree.
   **Water depth (issue #217)** — not in the mockup; this extends it, replacing the mockup's pressure
   tile (which has no defined status word of its own — `pressure_trend.dart` only exposes a
   rising/steady/falling trend, not a color). A rough, approximate, non-swimmer "how gentle is this
   beach?" indication, built on issue #216's `BathymetryService`/`classifyShallowEntry`: the tile's value
   reads how far out from shore the water stays shallow (at or under `shallow_entry.dart`'s
   `shallowLimitMeters`), e.g. "<= 1.2 m for 180 m" (unit per the metric/imperial preference), with the
   Gentle/Moderate/Steep status word below it. Shows "No data" (never a fabricated number) whenever the
   selected beach has no usable geometry/transect, every sample request failed, or the location is
   outside EMODnet's coverage. Tapping it opens its own detail screen (below) exactly like every other
   stat tile; it has **no trend indicator** — a nearshore depth profile is a spatial reading with no time
   dimension, so `StatTile`'s trend row is omitted entirely rather than showing an invented delta. The
   pressure tile/its detail screen/route stay in the codebase, just unreachable from this grid — see
   `lib/presentation/navigation/detail_routes.dart`'s own doc comment.
8. **Hourly forecast** — section label with a small clock icon, then a horizontally scrollable row of
   items (time label, weather icon, bold temperature), starting with "Now". Icons are colored by WMO
   weather-code group (`styleForWeatherIcon`): clear `icon.sun` `#FFC94D`, cloudy/overcast/fog blue-grey,
   rain/snow blue, thunderstorm violet with a small yellow bolt accent. Clear/partly-cloudy hours show a
   moon instead of the sun icon at night, decided per entry from its own hour (a fixed 06:00-20:00
   bucket, not a sunrise/sunset calculation).

## Screen: Metric detail

Not in the mockup — the mockup only covers Home/location-detail and Search (see the top of this
doc). Each Home stat tile (wind speed, rain chance, water depth, UV index) opens its own detail screen
when tapped, on its own route, with a back button to Home (issue #165 and the per-metric issues that
follow it: #178 UV index, #179 rain chance, #166 wind, #167 wave height, #180 water temperature, #181
current, #217 water depth).

All of these screens share one layout (`MetricDetailScaffold`, not a shared screen — each metric still
gets its own screen file/route) on the same `bg.base`/`bg.gradientBottom` gradient as Home, so they read
as part of the same app:

1. **Header row** — back button (`chevron_left`, same as Search's) + the metric name, `text.primary`.
2. **Hero value** — the current reading, large and bold like Home's hero temperature, with its unit
   underneath in `text.secondary`, then (issue #215, where the metric has a defined status — wind,
   rain chance, UV index) the same short colored status word/dot its Home stat tile shows, then (where
   the metric has one) a short trend line, e.g. Pressure's "Rising — ...".
3. **Chart slot** — an `HourlyMetricChart`: the day's hourly series as a line (with an optional filled
   band and threshold lines), a "Now" marker, and gaps instead of zeros for any `null` hour.
   **Water depth (issue #217) deviates here**: it has no hourly/time series at all, so its chart slot is
   `DepthProfileChart` instead — a distance-vs-depth profile (x = distance from shore, y = depth, drawn
   increasing *downward*, with horizontal lines at `shallow_entry.dart`'s `shallowLimitMeters`/
   `deepLimitMeters`) — followed by a context row of plain info facts (lifeguard presence, current wave
   height, and, only when it applies, the issue #164 drift-out warning), and its explanation paragraph
   (below) also carries an EMODnet attribution line. Its Min/Max/Now summary row (next) is repurposed to
   the shallowest/deepest valid reading along the transect and the reading at the classification's own
   100 m reference distance, since there is no literal "now" for a spatial reading.
4. **Min/Max/Now summary row** — three short columns under the chart, label above value, matching the
   stat-grid's label/value styling.
5. **Explanation paragraph** — one short `text.secondary` paragraph on what the metric means for the
   weather (e.g. what rising vs. falling pressure implies).

## Screen: Search

1. **Header row** — back chevron left, "Search" title centered, overflow ("...") menu right.
2. **Search field** — full-width rounded pill, white (`surface.paper`), leading search icon,
   placeholder "Enter cities" in `text.secondary`. It sits on a slightly lighter translucent header
   band over the cloud texture.
3. **Result sheet** — a white card anchored to the bottom (bottom-sheet style, ~32px top radius),
   containing:
   - a result row: filled pin icon + **beach name** in bold (the mockup shows "Altinkum Beach", with
     "Cesme, Izmir" as the grey subtitle), and a colored weather icon + temperature (`text.onPaper`)
     on the right, then a thin divider;
   - a "Beaches Near" section label in `text.secondary`;
   - two columns of plain text info lines for the beach. These are **not chips or pills**: no
     background, border or box, just short text lines stacked in two columns (see "Beach info
     lines" below).

### Beach info lines (facts the mockup asks for, and where each would come from)

| Mockup line | Meaning | Data source |
|---|---|---|
| eintritt preis | Entry price | OSM `fee=yes/no` only (no price in OSM) → show Paid / Free / Unknown |
| welle höhe | Wave height | Open-Meteo Marine API (can be null very close to shore → "no data") |
| slope | Beach / seabed slope | No free source identified — open question, do not invent a value |
| google comment | Reviews | Google Places (API key + billing) → owner decision, out of scope for now |
| autopark | Car park nearby | OSM `amenity=parking` near the beach |
| beach club | Beach club nearby | OSM `leisure=beach_resort` near the beach |
| cafe | Café nearby | OSM `amenity=cafe` near the beach |
| ob ma a schuhe brauchen | Shoes / slippers advised? | Heuristic from OSM `surface` (pebbles/gravel/rock → advised, sand → not needed, missing → unknown); label it as advice, not fact |

Left column in the mockup: price, wave height, slope, reviews. Right column: car park, beach club,
café, shoes. Water temperature is not in the mockup but was requested for the beach info; add it to
the marine group.

## Components implied by this design

Reusable widgets worth extracting rather than rebuilding per-screen:

- `StatTile` — icon + label + value/unit + an optional status word/color + trend, used 4× in the stat
  grid.
- `ForecastAlertList` — the alert list's vertical stack of severity-icon + message + time-window
  rows, sorted most severe first and rendering nothing when empty.
- `SeaConditionsRow` — the Sea section's horizontally scrollable row of 5 tiles (wave height, water
  temperature, wave direction, current speed, current direction), in `StatTile`'s visual style but
  without its trend row.
- `HourlyForecastItem` — time + icon + temperature, used in the scrollable hourly row.
- `LocationMapCard` — the white map card with the docked location bar; renders a real map with the
  beach overlay (gold polygons/lines).
- `SearchField` — the rounded paper search input, reusable on any screen that needs city search.
- `BeachResultCard` — the paper bottom-sheet result row + a two-column block of plain text info
  lines (no chip boxes) for the nearby beach.

## Out of scope for this doc

Exact spacing/padding values, icon asset sourcing, and animation/transition behavior aren't captured
here — measure them from the exported images in `docs/assets/`. The mockup's cloud texture is a
photographic asset that is not in the repo; Home draws a procedural `CloudBackdrop` approximation
instead (see "Visual direction" above) rather than shipping a new image asset. Search's mid-screen
cloud is not yet implemented.
