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
- Screen title: bold, ~20pt, white. On Search this is literally "Search"; on Home (issue #253, superseding
  the mockup's "My Location" placeholder below) it is the selected location's real place name.
- Section labels ("Hourly forecast", "Beaches Near"): regular, ~13pt, `text.secondary`, often paired
  with a small leading icon.
- Home stat-grid tile values (all nine tiles, issue #251 — semi-bold rather than the hero
  temperature's full bold, since nine compact tiles read better slightly lighter than four large
  ones did): semi-bold, ~22pt, white, with the unit as a separate, visually smaller/secondary run
  right next to it (~13pt, `text.secondary`), never concatenated into the same string. Sized down
  from issue #215's earlier ~26–28pt once the grid grew from four tiles to nine same-size ones (issue
  #251, Vaen's 2026-10-06 feedback that the old grid had become too tall) — that earlier figure itself
  deviated from this doc's original ~16–18pt, which read too small on a phone screen (Vaen's
  2026-10-03 feedback). Metric detail screens (below) are unchanged — they already show a 44pt hero
  value.
- Card labels: regular, ~12pt, `text.secondary`.

## Screen: Home / location detail

Every value on this screen — the header subtitle, hero temperature, condition row, map card, smart
suggestion pill, Sea section, stat grid and hourly row — belongs to one **selected location** (issue
#157), never a fixed city: whatever point the user last tapped on the map, picked via "Use my location"
(#254), or restored from `SharedPreferences` on app start. Çeşme (38.3220, 26.3260) is only the
**first-run default**, shown until the user has ever picked a point; after that, the selected location
(and its persisted copy) always wins. Tapping a new point on the map card re-fetches weather, marine data
and nearby beaches for it and updates the header/place name immediately — there is no separate "confirm"
step. The place name shown is a real name when the location came from a search result; a bare map tap or
a device-location pick (#254) instead shows formatted coordinates (`"38.3220°N, 26.3260°E"`) immediately,
then upgrades to a real reverse-geocoded city name (`ReverseGeocodingService`, e.g. "Çeşme, İzmir") a
moment later if/when that lookup succeeds — coordinates remain the permanent fallback whenever it fails
or isn't available.

> **Layout decision (Vaen, 2026-10-08): map-first with a bottom sheet ("option A").** This supersedes the
> stacked, scrolling layout described in the numbered list below; the list still describes each
> element's content and behavior, but the *placement* changes as follows. Mockup:
> `docs/assets/home-map-first-mockup.png` (schematic — not a real screen; sizes and spacing are
> adjustable, only the structure is decided).
>
> - The **map fills the whole screen** behind everything (no fixed 200 dp card). The search field floats
>   at the top (the former search icon/expanding `SearchField` of #158 becomes this always-visible
>   field); map controls (my location #254, zoom) float on the right edge. The overflow menu entries
>   (Beaches, Use my location, Units, Alerts, Compare beaches) stay reachable from the search field's
>   trailing menu.
> - A **draggable bottom sheet** (rounded top corners, grab handle) holds the selected location. Collapsed
>   it shows: place name + coordinates/distance subtitle, current temperature, the verdict pill, the single
>   next-hour note (see "Forecast screen" below), and the three **Sea** metrics (wave height, water temp, water depth) with
>   status words, plus a "swipe up for all details" hint. Expanded it shows the full Current, Air groups
>   and the hourly forecast as in the current Home screen.
> - Tapping the map still selects a point exactly as before; the sheet updates in place and stays in its
>   current state. Amenity markers, the legend chips and beach overlays are unchanged and must stay
>   usable above the collapsed sheet.
> - **Selected-beach info row** (issue #214, extended by #257) — once a beach has been picked from
>   Search, the expanded sheet also shows its `BeachResultCard` (place name, temperature, entry fee,
>   wave height, water temperature, shoe advice, parking/beach club/cafe), fully rounded rather than
>   the Search result sheet's top-only radius. It carries a **water-depth / non-swimmer summary**: a
>   small waves icon plus the #256 verdict sentence (gentle/moderate/steep, colored the same green/
>   orange/red, or "Depth: no data"/"Depth: checking…" while unknown/loading — never a guessed verdict),
>   and, when known, a second line combining the stand-up distance with a shortened approximation
>   caveat (`depthApproximationCaveatShort`). Tapping the summary opens the same water-depth detail
>   screen the Home stat tile does, where the full caveat is shown. `SearchScreen`'s own result list
>   never fetches a depth profile per result, so it never shows this summary.
> - Unchanged: header content rules (#253), verdict palette, 3x3 stat grouping (#251), Water depth
>   cross-section and verdict (#256).
>
> **Forecast screen (Vaen decision, 2026-10-08): one note on Home, everything else in a detail screen.**
> Supersedes the Home placement of items 5 (alert list) and 9 (7-14 day outlook) below; their content and
> thresholds are unchanged.
>
> - Home (collapsed and expanded sheet) shows **at most one note**: the **next-hour note**
>   (`buildNextHourNote`, with its "Next hour" label). It is **not** replaced by an alert when absent: no
>   next-hour note means no note and no gap. It is a short sentence that **wraps instead of being
>   ellipsized**. The per-type daylight alert rows (`ForecastAlertList` rows) and the 7-14 day outlook list no
>   longer appear on Home.
> - A new **Forecast screen** is opened from a single row on Home ("Forecast and 7-14 day outlook  >") and by tapping the
>   next-hour note. It has two sections: **Alerts** (all day-prefixed alerts from `buildForecastAlerts`, severity
>   sorted, full text, wrapped, no ellipsis; "No alerts" when empty) and **7-14 day outlook**
>   (`DailyOutlookList`, full verdict message wrapped, high/low). Same dark background and section-label style as
>   the Metric detail screen, with a back button; it reads the selected location's data and updates with it.
> - The "conditions turned favorable" notification (#267) and the alert thresholds are unchanged.

Top to bottom:

1. **Header row** — location label stack on the left: the selected location's real place name, bold,
   as the primary label (issue #253, Vaen's 2026-10-06 feedback — the mockup's "My Location" placeholder
   is never shown as a fixed label, since it would misname whatever point is actually selected; the real
   device-location action added by #254 lives in the map card's overflow menu instead, see below), with a
   `text.secondary` coordinates subtitle underneath only when it says something the place name doesn't
   already (a bare map tap/device-location pick starts out with its place name being its own formatted
   coordinates, before any reverse-geocode upgrade — #254 — so a second identical line would be
   redundant; once that upgrade lands, the coordinates line adds real information again and reappears).
   Current temperature large on the right, both on `bg.base`.
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
   `SearchScreen`, the beach list/favorites/filter), when available, "Use my location" (issue
   #254: device location via `geolocator`, hidden entirely when no `DeviceLocationService` is
   supplied), when available, "Units", and, when available, "Alerts" (issue #267: a switch for the
   "conditions turned favorable" notification, backed by `ConditionAlertDispatcher.alertsEnabled`/
   `setAlertsEnabled`, hidden entirely when no `ConditionAlertDispatcher` is supplied). "Use my
   location" is the *only* thing on this screen
   that can ever show a location-permission prompt — it never happens on app start or any other
   pick. On success the device position is selected exactly like a map pick (header, weather,
   marine data, nearby beaches, persistence); on a denied permission or an unavailable/disabled
   location service, the previous pick stays and a short `SnackBar` explains why, rather than
   inventing a position or showing an error screen.
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

   **Safety disclaimer** (issue #271) — a small trailing info icon (`Icons.info_outline`, same
   foreground color as the pill's text/icon) opens a bottom sheet: title "A guide, not a guarantee" and
   `swimSafetyDisclaimer` (`lib/logic/swim_safety_disclaimer.dart`), stating the verdict is a model
   estimate, not a safety guarantee, and that local flags/lifeguards take precedence. Never uses the
   word "safe", mirroring `depthApproximationCaveat`'s wording rule.
5. **Home: alert list** (issue #169, extended by #229) — not in the mockup; this extends it. Sits
   directly under the smart suggestion pill and above the Sea section/stat grid. Two kinds of row,
   `ForecastAlertList`:
   - **Daylight alerts** — one row per upcoming `ForecastAlert` from
     `lib/logic/forecast_alerts.dart`'s `buildForecastAlerts`, fed the selected location's real
     `WeatherProvider`/`MarineProvider` hourly series plus its `WeatherCondition.daylightWindows`
     (Open-Meteo's daily `sunrise`/`sunset`, local time). An alert is only shown when its whole
     window falls inside the location's sunrise-sunset window for that day — a night-time window
     (e.g. 00:00 or 04:00) is dropped, and once today's sunset has passed only a later day's window
     can still match. When the API returns no sunrise/sunset at all, the list falls back to the
     unfiltered behaviour instead of showing nothing. Each row: a small type icon (wind, waves,
     clouds, rain or current), the alert's one-line message, and a compact time-window label
     underneath (e.g. "09:00 - 10:00", prefixed "Tomorrow · " or a weekday abbreviation when the
     alert is not on today's calendar date, so two alerts sharing an hour on different days never
     read as duplicates). The icon's color follows severity, not type: amber (`#FFB74D`) for
     `moderate`, `color.warning`'s red (`#EF5350`) for `high` — the same red the Sea section's
     away-from-shore label uses, since both mean "pay attention". Sorted most severe first, with an
     earlier time window breaking a tie between two alerts of the same severity.
   - **Next-hour note** (`lib/logic/forecast_alerts.dart`'s `buildNextHourNote`) — at most one row,
     always first and visually distinct (a "Next hour" label above the message, its icon inside a
     soft tinted circle instead of bare), comparing only the current hour to the next one with the
     same rules/thresholds as the alerts above. Based on the current time, not daylight, so it still
     shows after sunset even when the daylight alert list below it is empty. No time-window label
     underneath — it is always "right now -> the next hour", so one would be redundant.
   The whole list (`ForecastAlertList`) renders nothing — no spacer, no gap — when there are no
   daylight alerts AND no next-hour note, exactly like the Sea section's own "no data yet"
   treatment. Muted, list-style rows, no card background or border, matching the rest of Home's "no
   tile background" direction. Tapping a row does nothing yet (optional per the issue) — this is a
   heads-up list, not a notification: pushing these as device notifications is explicitly out of
   scope (see the follow-up note in `lib/logic/condition_alert_service.dart`).
6. **Stat grid** (issues #163/#215/#217, superseded by the owner's 2026-10-06 decision on issue
   #251) — not in the mockup as such a grid at all (the mockup has no wave/current fields, and shows
   wind speed/rain chance/pressure/UV index as a visually larger 2×2 block); this is the current,
   final shape of that combined area, sitting under the smart suggestion pill (and the forecast alert
   list, when present). **One 3×3 grid of nine same-size tiles**, in three labelled rows of three —
   Sea (wave height, water temperature, water depth), Current (current speed, current direction, wave
   direction), Air (wind speed, rain chance, UV index) — chosen so the owner's "the wave height/water
   temperature row is fine, the rest is too big" feedback resolves by matching *everything* to that
   compact size, not by enlarging the sea tiles. Each group has a small uppercase `text.secondary`
   heading (a leading icon + the group name, matching the "Hourly forecast" label's styling) above its
   row of three tiles, with a thin low-opacity divider line between groups (no divider after the last
   one) — `StatTileGroup`. **No tile background** on any of the nine, same as every earlier version of
   this grid. A tile's three equal-width columns come from an `Expanded` row (`StatTileGroup`); a
   tile's own *height* is left to grow with its content (e.g. a wrapped status line) rather than being
   forced to a fixed aspect ratio, so the grid still reads as "one size" without an artificial cap that
   would either clip the one safety-relevant warning this grid shows or waste space on every other
   tile to make room for it.

   **Tile content** (`StatTile`) — icon + `text.secondary` label on one line; then the value, bold/
   semi-bold and ~22pt, with its unit as a separate, visually smaller/secondary run right next to it
   (never concatenated into the same string — see "Typography"); then, only for a metric with a
   defined status, a short colored status word/phrase under the value (a small dot + text, in
   green/orange/red or a metric's own band color). A metric with **no** defined status (wave height,
   water temperature, current speed, wave direction) shows no third line at all, rather than an empty
   one. Direction tiles (current direction, wave direction) show a rotated arrow icon (clockwise from
   "up", by compass bearing) instead of a plain one, paired with a cardinal-label value, e.g. `"toward
   SE"`/`"from NW"` — see the doc comments on `SeaCondition.waveDirection`/`.currentDirection` for the
   "coming from" vs. "flowing toward" bearing conventions those two use (do not render them the same
   way). **No trend row** on any of the nine Home tiles (every earlier version of this grid had one on
   wind speed/rain chance/UV index) — none of the nine values has a meaningful "delta since last hour"
   that a Home tile, rather than its own detail screen, should surface; `MetricDetailScaffold`'s own
   trend line (where a metric has one, e.g. pressure) is unaffected. Every tile keeps today's
   tappability, opening its own detail screen (below) exactly as before.

   **Status words** come from the existing helpers issues #215/#217 already built, never new
   thresholds invented for this grid: wind speed (Calm/Moderate/Strong, `lib/logic/wind_status.dart`,
   reusing `swim_suitability.dart`'s own moderate/high thresholds), rain chance (Low/Medium/High,
   `lib/logic/rain_status.dart`, same thresholds), UV index (its band — Low/Moderate/High/Very
   high/Extreme, `lib/logic/uv_band.dart`, the same color the UV index detail screen's chart bands
   use) and water depth (its steepness — Gentle/Moderate/Steep, `lib/logic/shallow_entry_status.dart`,
   issue #217's `BathymetryService`/`classifyShallowEntry` — see that issue's own notes below on its
   value format/"No data" fallback, still unchanged by #251 beyond moving into the Sea group).
   `MetricDetailScaffold` shows the same word/color under its hero value on the matching detail
   screen, so Home and the detail screen never disagree. The **current-direction** tile's own "status"
   is the Sea-section shore relation (issue #164): when the nearest fetched beach (by real distance to
   the selected point, not list order) has usable OSM geometry and amenities, it shows a short line —
   "(towards shore)" / "(away from shore — stay close!)" / "(along shore)" — with the away-from-shore
   case bold and in `color.warning`, wrapping onto further lines rather than being clipped, since it
   signals drift-out/rip-current risk; the derivation (`lib/logic/wave_shore_relation.dart`'s
   `seawardBearingFromGeometry`) is a best-effort heuristic (land-side amenities as an anchor), not a
   guaranteed fact, so no geometry/amenities (or a derivation that can't determine a direction) means
   no relation line at all — a cardinal-only value, never an invented one. The **wave-direction** tile
   deliberately shows no relation line of its own (a 2026-10-06 simplification of the pre-#251 design,
   which showed one on both direction tiles) — it has no defined status at all, like wave height/water
   temperature/current speed.

   **Loading/error/"No data" handling** (issue #213, extended by #228) stays per-section, not merged
   into one state for the whole grid: the Air group (wind speed/rain chance/UV index) and the Sea
   group's water-depth tile are independent of `MarineProvider` and keep rendering their own real data
   (or "No data") regardless of a marine fetch's state. Wave height/water temperature/current
   speed/current direction/wave direction — the five tiles actually driven by
   `MarineProvider.currentData` — fall back to "No data" on their own null-safe formatters exactly like
   every other null field in this grid, with a slim loading note (while a fetch for a freshly picked
   location is in flight) or a visible inline error (`"Unable to load marine data."` plus the real
   error, in `color.warning`, never a silent blank gap) shown just above the grid for that window.
8. **Hourly forecast** — section label with a small clock icon, then a horizontally scrollable row of
   items (time label, weather icon, bold temperature), starting with "Now". Icons are colored by WMO
   weather-code group (`styleForWeatherIcon`): clear `icon.sun` `#FFC94D`, cloudy/overcast/fog blue-grey,
   rain/snow blue, thunderstorm violet with a small yellow bolt accent. Clear/partly-cloudy hours show a
   moon instead of the sun icon at night, decided per entry from its own hour (a fixed 06:00-20:00
   bucket, not a sunrise/sunset calculation).
9. **7-14 day outlook** (issue #273) — below the hourly row, the same section-label style (small
   calendar icon + `text.secondary` label) introduces a plain vertical list, one row per forecast
   day: a weekday label ("Today" for the first row), the swim-verdict icon/color (`paletteForVerdict`
   — the same good/caution/poor/unknown mapping as the smart suggestion pill), the verdict's one-line
   message, and the day's high/low temperature. A thin low-opacity divider separates rows, no card
   background, matching the hourly row and stat grid. The whole section is hidden (no gap) when there
   is no daily data yet, same "hide rather than show empty" rule as `ForecastAlertList`. A candidate
   Pro feature per the market-analysis notes, built ungated for now (no entitlement system exists yet,
   same stance as Compare beaches).

## Screen: Metric detail

Not in the mockup — the mockup only covers Home/location-detail and Search (see the top of this
doc). Each of the nine Home stat-grid tiles (wind speed, rain chance, water depth, UV index, wave
height, water temperature, current speed, current direction; wave direction is the one tile with no
detail screen of its own) opens its own detail screen
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
   **Water depth (issue #217, extended by #256) deviates here**: it has no hourly/time series at all, so
   its chart slot is a stack of several pieces instead, top to bottom:
   - **Non-swimmer verdict line** (issue #256) — one short, bold, plain-language sentence judging the
     beach for non-swimmers, derived only from the existing gentle/moderate/steep/unknown classification
     (`classifyShallowEntry`, `lib/logic/shallow_entry.dart`) — never a new threshold:
     gentle = "Shallow for a long way out. Easier for non-swimmers." (green, matching the gentle status
     color), moderate = "Gets deep fairly quickly. Non-swimmers should stay close to shore." (orange),
     steep = "Drops away quickly. Not suitable for non-swimmers." (red), unknown = "Not enough depth
     data for this beach." (`text.secondary`). Always immediately followed, same size position, by a
     fixed caveat in `text.secondary`: "Approximate (~115 m data). Not a safety guarantee. Waves,
     currents, sandbars and sudden drop-offs are not captured." Both strings live in
     `lib/logic/shallow_entry_verdict.dart` (`shallowEntryVerdictLine`/`depthApproximationCaveat`) —
     small pure functions, reusable by a later screen (issue #257) — never duplicated wording. This
     copy is **owner-reviewable** (safety-adjacent): see the PR that introduced it for the explicit
     call-out.
   - **`DepthCrossSection`** (issue #256, `lib/presentation/widgets/depth_cross_section.dart`) — a
     side-view graphic: water surface on top, the seabed drawn from the transect's real samples, the
     water column tinted in three horizontal bands reusing the exact same colors as the Home tile's
     gentle/moderate/steep status (green `<= shallowLimitMeters` "stand-up", orange
     `shallowLimitMeters`-`deepLimitMeters` "getting deep", red `>= deepLimitMeters` "over your head"),
     and up to `maxPersonSilhouettes` (3) simple standing-person silhouettes scaled to
     `referenceAdultHeightMeters` (1.7 m) so depth reads at human scale without needing to read a
     number — a shallow figure's head/shoulders show above the water line, a figure at a sample deeper
     than 1.7 m renders fully submerged (dimmed) to read as "over your head". Honesty about the ~115 m
     grid's limits: only real, non-null `DepthSample`s are ever used to place a seabed point or a
     person figure (never an invented position), and the seabed line connecting real points is drawn
     **dashed throughout** — even the segment between two measured points is an inferred approximation,
     never a surveyed continuous reading, so a solid line would overstate the data's precision. An empty
     sample list (or a profile with no usable data at all) falls back to the same "No data" placeholder
     `DepthProfileChart` already uses. The graphic also carries a `Semantics` image label (built from the
     verdict + distance labels below) so its content reaches assistive technology too, not just sighted
     users.
   - **Distance labels** (issue #256, part 4) — plain-language text under the graphic, from
     `lib/logic/shallow_entry_verdict.dart`'s `standUpDistanceLabel`/`deepFromDistanceLabel`, reading
     `ShallowEntryClassification.firstShallowExitDistanceMeters`/`.firstDeepDistanceMeters`: "Stand-up
     water until about X m" and "Deep (2.5 m+) from about Y m" (or a "whole measured distance" variant
     when a threshold is never crossed within the transect). If the profile's first *valid* sample is
     already deeper than `shallowLimitMeters` (`hasNoShallowZone`), the stand-up label is replaced with
     "No shallow stand-up zone in this data (it may exist closer to shore than the data can show)."
     instead of ever inventing a shallow start — this message, and the verdict/caveat above, never use
     the word "safe".
   - **Context row** — unchanged from issue #217: plain info facts (lifeguard presence, current wave
     height, and, only when it applies, the issue #164 drift-out warning), kept directly under the
     verdict/graphic/labels block above (issue #256, part 5) since non-swimmer suitability depends on
     these facts just as much.
   - **`DepthProfileChart`** — the original distance-vs-depth profile (x = distance from shore, y =
     depth, drawn increasing *downward*, with horizontal lines at `shallow_entry.dart`'s
     `shallowLimitMeters`/`deepLimitMeters`) is kept, now sitting below the cross-section as the exact
     numeric reading for anyone who wants it, rather than being replaced by it.

   The explanation paragraph (below) also carries an EMODnet attribution line. The Min/Max/Now summary
   row is repurposed to the shallowest/deepest valid reading along the transect and the reading at the
   classification's own 100 m reference distance, since there is no literal "now" for a spatial reading.
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

## Screen: Compare beaches (issue #274)

Not in the mockup — a candidate Pro feature, built plain/ungated for now (no entitlement system
exists yet). Reached from the Home map card's overflow ("...") menu, a "Compare beaches" entry
(`Icons.compare_arrows`) always present: tapping it with fewer than two nearby beaches fetched shows
a `SnackBar` explaining why, rather than opening an empty screen.

1. **Selection sheet** — a bottom sheet listing the currently fetched nearby beaches (favorites
   marked with a filled amber star via a throwaway `FavoritesProvider`, sorted first), each a
   `CheckboxListTile`. Checking a 4th beach while 3 are already checked is a no-op — never more than
   3 at once. A full-width "Compare" button at the bottom, disabled until at least 2 are checked.
2. **Comparison screen** (`CompareBeachesScreen`) — an `AppBar` titled "Compare beaches" and a
   `Table`: one column per beach (name as the bold header), one row per metric — Wave height, Wind,
   Water temp, Depth, Swim score. Wave height/water temp come from the already-batched
   `NearbyBeachesProvider.seaConditionFor` (no extra request); wind is fetched per beach via a
   dedicated `WeatherRepository` (`HomeScreen.compareWeatherRepository`, separate from the single
   selected location's own); Depth reuses #256's `classifyShallowEntry`/`shallowEntryStatusLabel`
   (Gentle/Moderate/Steep) via a dedicated `BathymetryService`
   (`HomeScreen.compareBathymetryService`); Swim score reuses the Home pill's own
   `scoreSwimSuitability`, shown as a short word (Good/Caution/Poor), not the full sentence. Any
   metric with nothing to show (no repository/service supplied, or a fetch failed) renders "No
   data", matching this doc's existing "never invent a value" rule everywhere else.

## Components implied by this design

Reusable widgets worth extracting rather than rebuilding per-screen:

- `StatTile` — icon + label + value/unit + an optional status word/color, used 9× (issue #251) across
  the stat grid's three groups; no trend row (the Home tiles dropped it, detail screens keep their
  own).
- `StatTileGroup` — one labelled row of the stat grid (issue #251): a small uppercase heading over
  exactly three equal-width `StatTile`s.
- `ForecastAlertList` — the alert list's vertical stack of severity-icon + message + time-window
  rows, sorted most severe first and rendering nothing when empty.
- `HourlyForecastItem` — time + icon + temperature, used in the scrollable hourly row.
- `DailyOutlookList` — the 7-14 day outlook's vertical rows (day label + swim-verdict icon/message +
  high/low temperature), built from `buildDailyOutlook`.
- `LocationMapCard` — the white map card with the docked location bar; renders a real map with the
  beach overlay (gold polygons/lines).
- `SearchField` — the rounded paper search input, reusable on any screen that needs city search.
- `BeachResultCard` — the paper bottom-sheet result row + a two-column block of plain text info
  lines (no chip boxes) for the nearby beach, plus an optional water-depth summary row (issue #257,
  Home's selected-beach info row only — see "Layout decision" above).

## Out of scope for this doc

Exact spacing/padding values, icon asset sourcing, and animation/transition behavior aren't captured
here — measure them from the exported images in `docs/assets/`. The mockup's cloud texture is a
photographic asset that is not in the repo; Home draws a procedural `CloudBackdrop` approximation
instead (see "Visual direction" above) rather than shipping a new image asset. Search's mid-screen
cloud is not yet implemented.
