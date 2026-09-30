/// Whether shoes/slippers are advisable at a beach, based on its ground
/// surface. This is always presented as advice, never as a fact: OSM's
/// `surface` tag does not tell us how sharp or hot the ground actually is.
enum ShoeAdvice { advised, notNeeded, unknown }

const _surfacesNeedingShoes = {
  'pebbles',
  'pebblestone',
  'gravel',
  'rock',
};

const _surfacesNotNeedingShoes = {'sand'};

/// Advises whether shoes/slippers are worth bringing, from a beach's OSM
/// `surface` tag. Returns [ShoeAdvice.unknown] whenever [surface] is
/// missing or not a recognized value, rather than guessing.
ShoeAdvice adviseOnShoes(String? surface) {
  if (surface == null || surface.isEmpty) return ShoeAdvice.unknown;

  final normalized = surface.toLowerCase();
  if (_surfacesNeedingShoes.contains(normalized)) return ShoeAdvice.advised;
  if (_surfacesNotNeedingShoes.contains(normalized)) {
    return ShoeAdvice.notNeeded;
  }
  return ShoeAdvice.unknown;
}
