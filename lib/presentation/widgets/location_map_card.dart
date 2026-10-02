import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/beach.dart';
import '../../data/models/beach_amenity.dart';
import '../../logic/providers/nearby_beaches_provider.dart';
import 'amenity_legend.dart';
import 'amenity_marker.dart';
import 'osm_attribution.dart';

/// Radius, in meters, of the "nearby beaches" search circle drawn around a
/// picked map location. Matches the radius [NearbyBeachesProvider]'s
/// underlying Overpass query searches (see `overpass_query_builder.dart`).
const double kNearbyBeachesRadiusMeters = 20000;

/// Minimum zoom level enforced on the map. Zooming out further would make a
/// 20 km radius pick visually meaningless (the circle would shrink to a
/// speck, or the map would show an area far larger than any single pick
/// could sensibly describe).
const double kLocationMapMinZoom = 8.0;

/// Maximum number of individual beach geometry overlays (polygons/lines)
/// drawn at once. A pick can return many beaches; rendering an unbounded
/// number of overlapping shapes would turn into visual noise, so this caps
/// how many get their own overlay. This is a deliberately simple form of
/// "clustering": the closest [kMaxRenderedBeachOverlays] results (nearby
/// beaches are already returned nearest-first) keep their individual
/// outline, the rest are left off the map.
const int kMaxRenderedBeachOverlays = 40;

/// The gold highlight color used for beach geometry overlays, per
/// docs/assets/mockup-home.png.
const Color _goldHighlight = Color(0xFFC9A227);
const Color _goldFill = Color(0x33C9A227);

const Distance _distance = Distance();

/// The map's starting zoom level (also [_LocationMapCardState]'s initial
/// `_currentZoom`, before any real `onPositionChanged` event arrives).
const double _initialZoom = 13.0;

/// Minimum zoom at/above which amenity markers are drawn at all — this
/// issue's "cluster or hide at low zoom" requirement, implemented as the
/// simpler of the two (hide): below this, a 20 km radius pick can return
/// far more amenities than are visually readable as individual pins.
const double kAmenityMarkersMinZoom = 12.0;

/// Pure so it's directly unit-testable without a widget/map in play.
bool shouldShowAmenityMarkers(double zoom) => zoom >= kAmenityMarkersMinZoom;

/// The light ("paper"), rounded map card with a coastline highlight and a
/// docked location bar (pin icon + place name + overflow menu) at its
/// bottom edge, per docs/design.md § "Screen: Home / location detail".
///
/// When [nearbyBeachesProvider] is supplied, the map is also interactive:
/// tapping it calls [NearbyBeachesProvider.pickLocation] with the tapped
/// point, and the provider's resulting beaches are drawn as gold polygons
/// (or lines, for open geometry) inside a 20 km radius circle around the
/// pick. Without a provider the map stays purely presentational, as before.
class LocationMapCard extends StatefulWidget {
  const LocationMapCard({
    super.key,
    required this.center,
    required this.placeName,
    this.tileProvider,
    this.onOverflowPressed,
    this.nearbyBeachesProvider,
  });

  final LatLng center;
  final String placeName;

  /// Overridable so widget tests can avoid hitting the real tile network.
  final TileProvider? tileProvider;

  final VoidCallback? onOverflowPressed;

  /// Optional so this widget stays usable purely presentationally (e.g. in
  /// contexts with no beach-picking behaviour). When provided, it drives
  /// tap-to-pick and the beach overlay.
  final NearbyBeachesProvider? nearbyBeachesProvider;

  @override
  State<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends State<LocationMapCard> {
  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);

  late LatLng _pickedPoint = widget.center;
  double _currentZoom = _initialZoom;
  final Set<AmenityKind> _hiddenAmenityKinds = {};
  BeachAmenity? _selectedAmenity;

  /// The last non-empty beach list rendered, kept around so an offline or
  /// failed fetch after an earlier successful pick still shows that
  /// earlier data instead of leaving the map blank (the failure itself is
  /// already handled upstream by [NearbyBeachesProvider]/`BeachCache`,
  /// which falls back to cached or static beaches whenever it can; this is
  /// the last line of defense for the rare case where even that comes back
  /// empty).
  List<Beach> _lastNonEmptyBeaches = const [];

  @override
  void didUpdateWidget(covariant LocationMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _pickedPoint = widget.center;
    }
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _pickedPoint = point;
      _selectedAmenity = null;
    });
    widget.nearbyBeachesProvider?.pickLocation(point);
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    // Only shouldShowAmenityMarkers's result actually changes this widget's
    // output, so only rebuild when that flips — otherwise every pan/zoom
    // frame would rebuild the whole map subtree (every polygon, polyline
    // and marker) for no visible difference.
    if (shouldShowAmenityMarkers(camera.zoom) !=
        shouldShowAmenityMarkers(_currentZoom)) {
      setState(() => _currentZoom = camera.zoom);
    } else {
      _currentZoom = camera.zoom;
    }
  }

  void _toggleAmenityKind(AmenityKind kind) {
    setState(() {
      if (!_hiddenAmenityKinds.remove(kind)) {
        _hiddenAmenityKinds.add(kind);
      }
    });
  }

  void _selectAmenity(BeachAmenity amenity) {
    setState(() {
      _selectedAmenity = identical(_selectedAmenity, amenity) ? null : amenity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.nearbyBeachesProvider;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: _surfacePaper,
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              child: provider == null
                  ? _buildMap(const [])
                  : AnimatedBuilder(
                      animation: provider,
                      builder: (context, _) =>
                          _buildMap(_beachesToShow(provider)),
                    ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: _surfacePaper,
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: _textOnPaper,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textOnPaper,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: _textOnPaper),
                      onPressed: widget.onOverflowPressed,
                      tooltip: 'More',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Picks which beach list to render: the provider's current beaches,
  /// unless the latest pick errored out with nothing to show, in which
  /// case the last successfully loaded (non-empty) list is kept on screen.
  List<Beach> _beachesToShow(NearbyBeachesProvider provider) {
    final beaches = provider.beaches;
    if (beaches.isNotEmpty) {
      _lastNonEmptyBeaches = beaches;
      return beaches;
    }
    if (provider.status == NearbyBeachesStatus.error) {
      return _lastNonEmptyBeaches;
    }
    return beaches;
  }

  Widget _buildMap(List<Beach> beaches) {
    final overlayBeaches = beaches.take(kMaxRenderedBeachOverlays);
    final allAmenities = [
      for (final beach in overlayBeaches) ...beach.amenities,
    ];
    final presentKinds = {for (final a in allAmenities) a.kind};
    final visibleAmenities = allAmenities
        .where((a) => !_hiddenAmenityKinds.contains(a.kind))
        .toList();
    final showMarkers = shouldShowAmenityMarkers(_currentZoom);
    // A selection goes stale (and must not keep its card/highlight on
    // screen) once its amenity is no longer actually drawn: its kind got
    // hidden via the legend, the zoom dropped below the marker threshold,
    // or a new pick replaced the beach list entirely (new BeachAmenity
    // instances, so identical() no longer matches any of them).
    final selected =
        showMarkers &&
            visibleAmenities.any((a) => identical(a, _selectedAmenity))
        ? _selectedAmenity
        : null;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: _initialZoom,
            minZoom: kLocationMapMinZoom,
            onTap: _handleTap,
            onPositionChanged: _handlePositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: "io.beachiq.app",
              tileProvider: widget.tileProvider ?? NetworkTileProvider(),
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _pickedPoint,
                  radius: kNearbyBeachesRadiusMeters,
                  useRadiusInMeter: true,
                  color: _goldFill,
                  borderStrokeWidth: 2,
                  borderColor: _goldHighlight,
                ),
              ],
            ),
            PolygonLayer(polygons: _polygonsFor(overlayBeaches)),
            PolylineLayer(polylines: _polylinesFor(overlayBeaches)),
            if (showMarkers)
              MarkerLayer(
                markers: [
                  for (final amenity in visibleAmenities)
                    Marker(
                      point: amenity.position,
                      width: amenityMarkerLabeledWidth,
                      height: amenityMarkerLabeledHeight,
                      alignment: AmenityMarker.pointAlignment,
                      child: AmenityMarker(
                        kind: amenity.kind,
                        name: amenity.name,
                        selected: identical(selected, amenity),
                        showLabel: true,
                        onTap: () => _selectAmenity(amenity),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (presentKinds.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 48,
            child: AmenityLegend(
              presentKinds: presentKinds,
              hiddenKinds: _hiddenAmenityKinds,
              onToggle: _toggleAmenityKind,
            ),
          ),
        if (selected != null)
          Positioned(
            top: presentKinds.isEmpty ? 8 : 44,
            left: 8,
            right: 48,
            child: _SelectedAmenityCard(
              amenity: selected,
              distanceMeters: _distance(_pickedPoint, selected.position),
            ),
          ),
        const Positioned(left: 8, bottom: 8, child: OsmAttribution()),
      ],
    );
  }

  /// Beach geometry with 3+ points is drawn as a filled/outlined polygon
  /// (a closed shoreline area).
  List<Polygon> _polygonsFor(Iterable<Beach> beaches) {
    return [
      for (final beach in beaches)
        if ((beach.geometry?.length ?? 0) >= 3)
          Polygon(
            points: beach.geometry!,
            color: _goldFill,
            borderColor: _goldHighlight,
            borderStrokeWidth: 2,
          ),
    ];
  }

  /// Beach geometry with exactly 2 points (an open way) is drawn as a
  /// simple gold line rather than a polygon.
  List<Polyline> _polylinesFor(Iterable<Beach> beaches) {
    return [
      for (final beach in beaches)
        if (beach.geometry?.length == 2)
          Polyline(
            points: beach.geometry!,
            color: _goldHighlight,
            strokeWidth: 3,
          ),
    ];
  }
}

/// The small label shown when a marker is tapped: the amenity's kind (and
/// name, when OSM has one) plus its distance from the current pick — "a
/// small label with the name or kind", per #172's acceptance criteria.
class _SelectedAmenityCard extends StatelessWidget {
  const _SelectedAmenityCard({
    required this.amenity,
    required this.distanceMeters,
  });

  final BeachAmenity amenity;
  final double distanceMeters;

  static const _textOnPaper = Color(0xFF2E3057);

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters.round()} m';
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              amenityIcon(amenity.kind),
              size: 16,
              color: amenityColor(amenity.kind),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                amenity.name == null
                    ? amenityLabel(amenity.kind)
                    : '${amenity.name} · ${amenityLabel(amenity.kind)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textOnPaper,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              distanceLabel,
              style: const TextStyle(color: _textOnPaper, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
