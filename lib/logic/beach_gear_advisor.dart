import 'beach_surface.dart';

/// Whether shoes/slippers are advisable at a beach, based on its ground
/// surface. This is always presented as advice, never as a fact: OSM's
/// `surface` tag does not tell us how sharp or hot the ground actually is.
enum ShoeAdvice { advised, notNeeded, unknown }

/// Advises whether shoes/slippers are worth bringing, from a beach's OSM
/// `surface` tag. Returns [ShoeAdvice.unknown] whenever [surface] is
/// missing or not a recognized value, rather than guessing. Goes through
/// [parseBeachSurface] so every OSM alias it recognizes (e.g. "shingle" for
/// pebbles, "fine_gravel" for gravel, "rocks" for rock) gets the same advice
/// as its canonical value, instead of this function keeping its own,
/// divergent list of surface strings.
ShoeAdvice adviseOnShoes(String? surface) {
  final parsed = parseBeachSurface(surface);
  if (parsed == null) return ShoeAdvice.unknown;
  switch (parsed) {
    case BeachSurface.sand:
      return ShoeAdvice.notNeeded;
    case BeachSurface.pebbles:
    case BeachSurface.gravel:
    case BeachSurface.rock:
      return ShoeAdvice.advised;
  }
}
