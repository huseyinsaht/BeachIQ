import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The light ("paper"), rounded map card with a coastline highlight and a
/// docked location bar (pin icon + place name + overflow menu) at its
/// bottom edge, per docs/design.md § "Screen: Home / location detail".
///
/// Pure presentational widget beyond the map itself — no repository or
/// provider dependency.
class LocationMapCard extends StatelessWidget {
  const LocationMapCard({
    super.key,
    required this.center,
    required this.placeName,
    this.tileProvider,
    this.onOverflowPressed,
  });

  final LatLng center;
  final String placeName;

  /// Overridable so widget tests can avoid hitting the real tile network.
  final TileProvider? tileProvider;

  final VoidCallback? onOverflowPressed;

  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: _surfacePaper,
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 13.0),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: "io.beachiq.app",
                    tileProvider: tileProvider ?? NetworkTileProvider(),
                  ),
                ],
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
                        placeName,
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
                      onPressed: onOverflowPressed,
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
}
