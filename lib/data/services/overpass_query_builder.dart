/// Builds the Overpass QL query string for finding beaches and their nearby
/// amenities within [radiusMeters] of the given point.
///
/// Pure function: no network, no I/O.
String buildNearbyBeachesQuery(double lat, double lon, {int radiusMeters = 20000}) {
  final latStr = lat.toStringAsFixed(6);
  final lonStr = lon.toStringAsFixed(6);

  return '[out:json][timeout:25];\n'
      'nwr[natural=beach](around:$radiusMeters,$latStr,$lonStr)->.b;\n'
      '.b out geom;\n'
      '(\n'
      '  nwr(around.b:150)[amenity~"^(shower|toilets|changing_room|parking|cafe)\$"];\n'
      '  nwr(around.b:150)[emergency=lifeguard];\n'
      '  nwr(around.b:150)[leisure=beach_resort];\n'
      ');\n'
      'out center tags;\n';
}
