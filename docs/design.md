# BeachIQ UI design reference

Source of truth: the team's Penpot mockup (two screens — home / location detail, and city search). This
doc distills that mockup into a reference other PRs (human or automated) can build against without
needing Penpot access. Colors below are read off the mockup screenshots and are **approximate** — if a
PR needs exact values, pull them from the Penpot file's color styles instead of these hex codes.

This maps to the "PHASE 4 — UI: Beach List and Detail Screen" board items (issues #16–21) and should
guide the earlier phases' screens too once they get a UI pass.

## Visual direction

Dark-mode weather/beach app. Deep navy background throughout, white primary text, muted blue-gray
secondary text, light "paper" cards floating on top for map and search-result content, a single teal
accent for water/coastline. Generous corner radii (~20–24px) on every card. No hard borders — depth
comes from flat color contrast, not shadows or outlines.

### Color tokens (approximate — verify against Penpot)

| Token | Hex | Use |
|---|---|---|
| `bg.base` | `#0D1220` | Screen background |
| `surface.card` | `#171D2E` | Stat cards, pill buttons |
| `surface.paper` | `#F5F6F8` | Map card, search-result sheet (light card on dark bg) |
| `accent.water` | `#2FB6C4` | Coastline highlight on the map, primary CTA accents |
| `text.primary` | `#FFFFFF` | Headlines, temperatures, values |
| `text.onPaper` | `#12151C` | Text on light cards (location name, beach name) |
| `text.secondary` | `#8B93A6` | Subtitles, labels, unit text |
| `icon.sun` | `#FFC94D` | Sun glyph in weather icons |

### Typography

- Large temperature / hero number: bold, ~40–48pt, white.
- Screen title ("My Location", "Search"): bold, ~20pt, white.
- Section labels ("Hourly forecast", "Beaches Near"): regular, ~13pt, `text.secondary`, often paired
  with a small leading icon.
- Card values (wind speed, pressure, etc.): bold, ~16–18pt, white.
- Card labels / units: regular, ~12pt, `text.secondary`.

## Screen: Home / location detail

Top to bottom:

1. **Header row** — location label stack on the left ("My Location" bold + city/district subtitle in
   `text.secondary`), current temperature large on the right, both on `bg.base`.
2. **Condition row** — condition text ("Partly Cloudy") left, high/low ("H:29° L:15°") right, both
   `text.secondary`, small size.
3. **Map card** (`surface.paper`, rounded ~24px) — a static/stylized light map with the coastline
   traced in `accent.water`. A location bar is docked to the card's bottom edge, same card surface,
   showing a pin icon + place name (bold, `text.onPaper`) and an overflow ("...") menu on the right.
4. **Smart suggestion pill** — a single full-width rounded pill in `surface.card` with a leading icon
   and short text (e.g. a "best time to swim" style suggestion). Secondary/muted, not a primary CTA.
5. **Stat grid** — 2×2 grid of `surface.card` tiles: wind speed, rain chance, pressure, UV index. Each
   tile: small icon top-left, `text.secondary` label, bold white value, and a small trend indicator
   (up/down arrow + delta) in `text.secondary` or a muted accent color.
6. **Hourly forecast** — section label with a small clock icon, then a horizontally scrollable row of
   items (time label, weather icon, bold temperature), starting with "Now".

## Screen: Search

1. **Header row** — back chevron left, "Search" title centered, overflow ("...") menu right.
2. **Search field** — full-width rounded pill, `surface.paper` (light on dark), leading search icon,
   placeholder "Enter cities" in `text.secondary`.
3. **Result sheet** — a `surface.paper` card anchored near the bottom of the screen (bottom-sheet
   style), containing:
   - a result row: pin icon + place name (bold) + area subtitle (`text.secondary`), with a weather
     icon + temperature on the right:
   - a "Beaches Near" section label, `text.secondary`;
   - a small two-column grid of short info chips for the nearby beach (entry price, wave height,
     slope, amenities, reviews, etc.) — treat the exact chip labels in the mockup as placeholder
     content, not final copy; pick real fields from the beach/marine data model instead.

## Components implied by this design

Reusable widgets worth extracting rather than rebuilding per-screen:

- `StatTile` — icon + label + value + trend, used 4× in the stat grid.
- `HourlyForecastItem` — time + icon + temperature, used in the scrollable hourly row.
- `LocationMapCard` — the paper-colored map card with the docked location bar.
- `SearchField` — the rounded paper search input, reusable on any screen that needs city search.
- `BeachResultCard` — the paper bottom-sheet result row + nearby-beach info chip grid.

## Out of scope for this doc

Exact spacing/padding values, icon asset sourcing, and animation/transition behavior aren't captured
here — pull those from the Penpot file directly when building a specific screen.
