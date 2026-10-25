# Beach surface and the first-10 m estimate

Issue #392. Measuring every beach is impossible, so for the ~worldwide majority of beaches nobody has measured
(see [`measured-depth.md`](measured-depth.md)) the Water depth screen shows two things it can honestly derive.

## 1. Beach surface (OpenStreetMap)

`Beach.surface` (OSM `surface`) is parsed by `lib/logic/beach_surface.dart`:

| OSM value | Shown as |
|---|---|
| `sand` | Sand |
| `pebbles`, `pebblestone`, `shingle` | Pebbles |
| `gravel`, `fine_gravel` | Gravel |
| `rock`, `rocks` | Rock |
| anything else / missing | nothing ("No data" on the beach info card) |

It is shown on the beach info card (Home sheet and Search results: "Surface") and on the Water depth screen
("Beach surface: Sand (OpenStreetMap)"). It is never guessed.

## 2. Estimate for the first 10 m

`lib/logic/nearshore_depth_estimate.dart`, shown by `NearshoreEstimateCard` with an amber **ESTIMATE** badge and the
caveat *"Estimated from the beach surface and the ~115 m depth data, not measured. Steps, sandbars and drop-offs are
not visible in that data, so the water can be deeper than this."*

Inputs: the OSM surface and the EMODnet depth ~100 m from the beach point (`classificationReferenceDistanceMeters`).

| Case | Output |
|---|---|
| **Sand**, 100 m depth `d` known and `0.32 d < 1.2 m` | "About 10 m from the water's edge the depth is probably about `0.10 d` to `0.32 d`" (low end rounded down, high end up, to 0.1 m / ft; "up to ..." when the low end is under 0.1) |
| **Sand**, `0.32 d >= 1.2 m` | no numbers: "The water may be waist-deep or more within 10 m of the water's edge." |
| **Pebbles, gravel, rock** | no numbers: "<Surface> beaches are usually steeper than sandy ones: the bottom can drop away quickly within the first few metres. No depth estimate." |
| unknown surface, or sand without a usable 100 m depth | nothing |
| beach with an on-site measurement (#390) | the measurement only; no estimate |

### Where the factors come from (provisional)

- `0.10 d` is the depth at 10 m on a **straight line** from the water's edge (0 m) to the 100 m depth. A beach is
  normally at least as steep near the water as that line, so this is the shallow end of the range.
- `0.32 d` is the depth at 10 m on a `depth ~ distance^0.5` curve (`(10/100)^0.5`), a profile much steeper near the
  shore than the usual equilibrium profile (`depth ~ distance^(2/3)`, factor 0.22). It is the conservative end.
- `1.2 m` is roughly waist-to-chest depth on an adult.
- Sand only: beach-face slope rises with grain size (Bascom 1951 and later work), but the relation is weak for
  gravel and varies with wave energy, so coarse beaches get a warning, not numbers.

**These numbers are provisional.** They have not been checked against measurements, and the 100 m depth itself comes
from a ~115 m grid measured from the OSM beach point rather than the true water's edge. Treat the output as a hint.

## Validating the factors

Measure a small sample of sandy beaches (not for coverage: for validation, ~20-30 beaches across wave exposures) with
the guide in `measured-depth.md`, then for each beach compare the measured depth at 10 m with the estimated range from
that beach's 100 m depth:

- if the measured value falls inside the range for (almost) all of them, keep the factors;
- if some fall above the range, raise `steepFactor` (or lower `deepWarningMeters`), or drop the estimate;
- if the range is so wide it says nothing, show only the qualitative text.

Later improvements: satellite-derived bathymetry (Sentinel-2, ~10 m cells, ~1-1.7 m error in published Aegean
studies) once validated against the same sample, and user-reported depths.
