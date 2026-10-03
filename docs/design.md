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
top, slightly lighter and bluer toward the bottom) with a decorative photographic **cloud texture** in
the top-right behind the status bar/header (a second, very faint cloud floats mid-screen on Search).
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
- Card values (wind speed, pressure, etc.): bold, ~16–18pt, white.
- Card labels / units: regular, ~12pt, `text.secondary`.

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
5. **Sea section** (issue #163) — not in the mockup (it has no wave/current fields at all); this
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
6. **Stat grid** — 2×2 grid, **no tile background**: wind speed, rain chance, pressure, UV index. Each
   tile: small line icon at the left, `text.secondary`-style label above a bold white value, and a small
   trend indicator (▴/▾ + delta) at the bottom-right of the tile. Use sea-level pressure in hPa
   (~1000–1030), not the mockup's 720. UV uses a decimal comma in the mockup (locale formatting).
7. **Hourly forecast** — section label with a small clock icon, then a horizontally scrollable row of
   items (time label, weather icon, bold temperature), starting with "Now". Icons are colored by WMO
   weather-code group (`styleForWeatherIcon`): clear `icon.sun` `#FFC94D`, cloudy/overcast/fog blue-grey,
   rain/snow blue, thunderstorm violet with a small yellow bolt accent. Clear/partly-cloudy hours show a
   moon instead of the sun icon at night, decided per entry from its own hour (a fixed 06:00-20:00
   bucket, not a sunrise/sunset calculation).

## Screen: Metric detail

Not in the mockup — the mockup only covers Home/location-detail and Search (see the top of this
doc). Each Home stat tile (wind speed, rain chance, pressure, UV index) opens its own detail screen
when tapped, on its own route, with a back button to Home (issue #165 and the per-metric issues that
follow it: #178 UV index, #179 rain chance, #166 wind, #167 wave height, #180 water temperature, #181
current).

All of these screens share one layout (`MetricDetailScaffold`, not a shared screen — each metric still
gets its own screen file/route) on the same `bg.base`/`bg.gradientBottom` gradient as Home, so they read
as part of the same app:

1. **Header row** — back button (`chevron_left`, same as Search's) + the metric name, `text.primary`.
2. **Hero value** — the current reading, large and bold like Home's hero temperature, with its unit
   underneath in `text.secondary` and (where the metric has one) a short trend line, e.g. Pressure's
   "Rising — ...".
3. **Chart slot** — an `HourlyMetricChart`: the day's hourly series as a line (with an optional filled
   band and threshold lines), a "Now" marker, and gaps instead of zeros for any `null` hour.
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

- `StatTile` — icon + label + value + trend, used 4× in the stat grid.
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
here — measure them from the exported images in `docs/assets/`. The cloud texture is a photographic
asset that is not in the repo; until it is supplied, use the gradient alone.
