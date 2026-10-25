# Measured nearshore depth (first 10 m)

No open dataset resolves the first ~10 m from the water's edge (EMODnet is a ~115 m grid, satellite
depth has a ~1-1.7 m error), so the only **certain** depth information is an on-site measurement.
BeachIQ shows measured values only for beaches that have an entry in
[`assets/measured_depths.json`](../assets/measured_depths.json) (issue #390). Everything else keeps the
"approximate (~115 m)" wording; the app never estimates 0-10 m.

## How to measure a beach (about 20 minutes, two people)

You need: a weighted rope or measuring tape with a mark every metre (a 10 m surveyor's tape works), a
graduated pole or a marked stick (at least 2 m), a phone for the time and GPS position, and something to
write on.

1. Pick a calm day and a quiet part of the beach. Note the **date and time** and the sea state (calm /
   small waves). Water level and waves change the numbers, so the date is part of the result.
2. Stand where the water meets the sand (the "water's edge"). Plant a marker there. This is **0 m**; write
   down what you used as the reference (for example "water edge at 14:00").
3. Lay the rope straight out from the marker, perpendicular to the shore, into the water.
4. At **1, 2, 3, 5, 7 and 10 m** (any subset, in increasing order) hold the pole upright on the bottom and
   read the water depth at the pole in **centimetres**. Do not stand in water deeper than your comfort or
   that is unsafe; stop at the last distance you can measure safely and leave the rest out.
5. Repeat the line in two more places along the beach, 20-30 m apart. If the lines differ, enter the one with
   the **deepest readings** (the cautious assumption for non-swimmers) and describe the differences in `note`
   (for example "steep step at 4 m near the rocks on the right side").
6. Take a phone GPS reading at the marker for `latitude` / `longitude`.
7. Optional but valuable: photograph the line with the rope visible.

Safety: never measure in rough water or alone, and never enter water you are not comfortable in.

## File format

`assets/measured_depths.json` is `{"version": 1, "beaches": [ ... ]}`. One entry per beach:

```json
{
  "beachName": "Ilica Beach",
  "latitude": 38.2870,
  "longitude": 26.3730,
  "radiusMeters": 150,
  "measuredOn": "2026-10-25",
  "measuredBy": "Vaen",
  "method": "Marked rope and depth pole",
  "reference": "Water edge at 14:00",
  "note": "Steep step at 4 m near the rocks on the right side.",
  "points": [
    { "distanceMeters": 1, "depthCm": 20 },
    { "distanceMeters": 3, "depthCm": 45 },
    { "distanceMeters": 5, "depthCm": 80 },
    { "distanceMeters": 10, "depthCm": 135 }
  ]
}
```

| Field | Rule |
|---|---|
| `beachName` | required, shown nowhere except in tests/logs; use the beach's usual name |
| `latitude`, `longitude` | required; the entry applies to beaches within `radiusMeters` of this point |
| `radiusMeters` | optional, 25-1000, default 150 |
| `measuredOn` | required, `YYYY-MM-DD` |
| `measuredBy`, `method` | required, shown on screen ("Measured on 25 Oct 2026 by Vaen. Marked rope and depth pole.") |
| `reference` | optional, where 0 m is; default "Water's edge at the time of measurement" |
| `note` | optional, one short sentence shown under the readings |
| `points` | required, 1-12 readings, `distanceMeters` an integer 1-10 and strictly increasing, `depthCm` an integer 0-2000 |

An invalid entry is **dropped** (never half-shown); the test `test/data/measured_depths_asset_test.dart`
fails if any entry in the shipped file is invalid, so run `flutter test` after editing the file.

## What the app shows

On the Water depth detail screen, directly under the verdict, a "Near the shore" block with a green
**MEASURED** badge, the date, who and how, one chip per reading (distance and depth, in m/cm or ft), what the
distances are measured from, the optional note and the caveat *"Depths change with waves, the season and the
water level on the day. A measurement is a guide for that day, not a safety guarantee."* The approximate
~115 m profile and verdict below it are unchanged.

## Later

Measuring cannot cover the world, so unmeasured beaches get a clearly labelled **estimate** instead (see
[`nearshore-estimate.md`](nearshore-estimate.md)). A handful of measured sandy beaches is the validation sample for that
estimate's factors. User-submitted measurements are a possible v2.
