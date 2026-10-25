import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/services/seabed_map_repository.dart';
import '../../logic/unit_preferences.dart';

const Color _textPrimary = Color(0xFFFFFFFF);
const Color _textSecondary = Color(0xFF8B93A6);
const Color _placeholderFill = Color(0xFF1E2230);

/// Honest label shown with the seabed map (issue #293).
const String seabedMapCaveat =
    'Approximate seabed, ~115 m resolution. Sandbars, drop-offs and details '
    'close to shore are not shown. Not for navigation.';

/// Attribution drawn on the map image itself (EMODnet's CC BY 4.0 terms).
const String seabedMapAttribution =
    'EMODnet Bathymetry, © European Union, CC BY 4.0. GEBCO 2024, IBCAO V4.';

/// The seabed map for the Water depth detail screen (issue #293): the
/// EMODnet shaded-relief/contour image for a ~4 km window with the beach at
/// the centre, a scale bar, the official depth legend, an honest
/// "approximate" caveat and visible attribution.
///
/// States: a same-size loading placeholder, the map, or "No seabed data"
/// when the request fails or returns nothing -- never a blank or guessed
/// picture. The image is requested once, only when this widget is built
/// (i.e. only on the detail screen, never on Home, Search or Compare).
class SeabedMapCard extends StatefulWidget {
  const SeabedMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.repository,
    this.unitSystem = UnitSystem.metric,
  });

  final double latitude;
  final double longitude;
  final SeabedMapRepository repository;
  final UnitSystem unitSystem;

  @override
  State<SeabedMapCard> createState() => _SeabedMapCardState();
}

class _SeabedData {
  const _SeabedData(this.map, this.legend);
  final Uint8List? map;
  final Uint8List? legend;
}

class _SeabedMapCardState extends State<SeabedMapCard> {
  late Future<_SeabedData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(SeabedMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.repository != widget.repository) {
      _future = _load();
    }
  }

  Future<_SeabedData> _load() async {
    final results = await Future.wait([
      widget.repository.getMap(widget.latitude, widget.longitude),
      widget.repository.getLegend(),
    ]);
    return _SeabedData(results[0], results[1]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('seabed-map-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seabed around the beach',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<_SeabedData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _Placeholder(
                child: CircularProgressIndicator(
                  key: Key('seabed-map-loading'),
                  strokeWidth: 2,
                ),
              );
            }
            final data = snapshot.data;
            final map = snapshot.hasError ? null : data?.map;
            if (map == null) {
              return const _Placeholder(
                child: Text(
                  'No seabed data',
                  key: Key('seabed-map-no-data'),
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              );
            }
            return _LoadedMap(
              map: map,
              legend: data?.legend,
              unitSystem: widget.unitSystem,
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          seabedMapCaveat,
          key: Key('seabed-map-caveat'),
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _placeholderFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _LoadedMap extends StatelessWidget {
  const _LoadedMap({
    required this.map,
    required this.legend,
    required this.unitSystem,
  });

  final Uint8List map;
  final Uint8List? legend;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final imperial = unitSystem == UnitSystem.imperial;
    // The window is 2 * half-span wide; the bar is 1 km (0.5 mi).
    const windowMeters = seabedMapHalfSpanMeters * 2;
    final barMeters = imperial ? 804.672 : 1000.0;
    final barLabel = imperial ? '0.5 mi' : '1 km';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label:
                'Seabed map, about 4 km across, centred on the beach. '
                '$seabedMapCaveat',
            image: true,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth =
                        constraints.maxWidth * barMeters / windowMeters;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          map,
                          key: const Key('seabed-map-image'),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text(
                              'No seabed data',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.location_on,
                            key: Key('seabed-map-beach-marker'),
                            color: Color(0xFFEF5350),
                            size: 28,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 22,
                          child: Column(
                            key: const Key('seabed-map-scale-bar'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                barLabel,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                width: barWidth,
                                height: 3,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            key: const Key('seabed-map-attribution'),
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: const Text(
                              seabedMapAttribution,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (legend != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Image.memory(
              legend!,
              key: const Key('seabed-map-legend'),
              fit: BoxFit.fitWidth,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}
