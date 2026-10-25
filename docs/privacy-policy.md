# BeachIQ Privacy Policy

_Last updated: 2026-10-25_

BeachIQ shows swim conditions (waves, wind, water temperature, depth, nearby beaches) for a place
you choose. This policy explains what the app does with data. BeachIQ has **no user accounts, no
advertising and no analytics or tracking SDKs**.

## What stays on your device
- The place you last selected, your favourites, and cached beach/weather lookups are stored
  locally on your phone (app storage). They are never uploaded to a BeachIQ server — BeachIQ has
  no server.
- Alert settings and the "conditions turned favorable" notification are handled locally on your
  device. Android may run a periodic background check for this; it only calls the public data
  services listed below.

## Location
- BeachIQ asks for **approximate (coarse) location** only when you tap "Use my location".
  It never asks for precise or background location. You can also pick a place on the map or by
  search without granting any permission.
- To show a place name for a position, the app uses your phone's built-in geocoder. On Android this
  is provided by the operating system / Google Play services, which may send the coordinates to
  Google; see Google's privacy policy.

## Data sent to third-party services
To show conditions, the app sends the coordinates of the place you selected (or the text you
search for) directly from your phone to these public services. They also see your IP address, as
with any internet request. BeachIQ does not control or receive copies of these requests.

| Service | Used for | What is sent |
|---|---|---|
| Open-Meteo (open-meteo.com) | weather, marine forecast, place search | coordinates; search text |
| Overpass API / OpenStreetMap (overpass-api.de and a mirror) | nearby beaches and facilities | coordinates |
| EMODnet Bathymetry (ows.emodnet-bathymetry.eu) | water depth and the seabed map | coordinates, or the map area around the beach you open |
| OpenStreetMap tile servers (tile.openstreetmap.org) | map images | map tile positions you view |

## Notifications
On Android 13+ the app asks permission to show notifications. You can decline; the app works
without them.

## Children
BeachIQ is not directed at children and collects no personal information from anyone.

## Not safety advice
Conditions shown are estimates from public data and are **not a guarantee of safety**. Always
follow local lifeguard flags and warnings. Depth data is approximate and not for navigation.

## Changes and contact
If this policy changes, the new version is published at the same address with an updated date.
Questions: open an issue at https://github.com/huseyinsaht/BeachIQ/issues.
