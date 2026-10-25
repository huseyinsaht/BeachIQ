/// The kinds of beach ground the app distinguishes, from OpenStreetMap's
/// `surface` tag.
enum BeachSurface { sand, pebbles, gravel, rock }

const _sand = {'sand'};
const _pebbles = {'pebbles', 'pebblestone', 'shingle'};
const _gravel = {'gravel', 'fine_gravel'};
const _rock = {'rock', 'rocks'};

/// Parses an OSM `surface` value. Returns `null` for a missing or any
/// unrecognised value (grass, dirt, concrete, a list of several values, ...)
/// rather than guessing.
BeachSurface? parseBeachSurface(String? osmSurface) {
  if (osmSurface == null) return null;
  final value = osmSurface.trim().toLowerCase();
  if (_sand.contains(value)) return BeachSurface.sand;
  if (_pebbles.contains(value)) return BeachSurface.pebbles;
  if (_gravel.contains(value)) return BeachSurface.gravel;
  if (_rock.contains(value)) return BeachSurface.rock;
  return null;
}

/// A short English label for [surface] ("Sand", "Pebbles", ...).
String beachSurfaceLabel(BeachSurface surface) {
  switch (surface) {
    case BeachSurface.sand:
      return 'Sand';
    case BeachSurface.pebbles:
      return 'Pebbles';
    case BeachSurface.gravel:
      return 'Gravel';
    case BeachSurface.rock:
      return 'Rock';
  }
}

/// The label for an OSM `surface` value, or `null` when it is missing or
/// not recognised (callers show "No data" or nothing).
String? beachSurfaceLabelFor(String? osmSurface) {
  final surface = parseBeachSurface(osmSurface);
  return surface == null ? null : beachSurfaceLabel(surface);
}
