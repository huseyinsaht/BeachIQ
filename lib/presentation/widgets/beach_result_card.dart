import 'package:flutter/material.dart';

import '../../data/models/beach.dart';
import '../../logic/beach_gear_advisor.dart';

/// A single label/value line shown in [BeachResultCard]'s two-column
/// "Beaches Near" info block.
class _BeachInfoLine {
  const _BeachInfoLine(this.label, this.value);

  final String label;
  final String value;
}

const _noData = 'No data';
const _unknown = 'Unknown';

/// Renders a [BeachFee] as Paid / Free / Unknown — OSM has no price data,
/// so this is never rendered as a number. `null` (no [BeachFee] supplied at
/// all) renders the same as [BeachFee.unknown].
String _feeText(BeachFee? fee) {
  switch (fee) {
    case BeachFee.free:
      return 'Free';
    case BeachFee.paid:
      return 'Paid';
    case BeachFee.unknown:
    case null:
      return _unknown;
  }
}

/// Renders a marine-forecast wave height (meters), or "No data" when no
/// marine data is available for this beach.
String _waveHeightText(double? meters) {
  if (meters == null) return _noData;
  return '${meters.toStringAsFixed(1)} m';
}

/// Renders a sea surface temperature (Celsius), or "No data" when no marine
/// data is available for this beach.
String _waterTemperatureText(double? celsius) {
  if (celsius == null) return _noData;
  return '${celsius.toStringAsFixed(0)}°';
}

/// Renders a [ShoeAdvice] as advice text — never as a bare fact, since the
/// underlying OSM `surface` tag does not tell us how sharp or hot the
/// ground actually is. `null` (no [ShoeAdvice] supplied at all) renders the
/// same as [ShoeAdvice.unknown].
String _shoeAdviceText(ShoeAdvice? advice) {
  switch (advice) {
    case ShoeAdvice.advised:
      return 'Shoes advised';
    case ShoeAdvice.notNeeded:
      return 'Not needed';
    case ShoeAdvice.unknown:
    case null:
      return _unknown;
  }
}

/// Renders a nullable OSM amenity-nearby flag as Yes / No / Unknown. `null`
/// stands for "unknown" (no data to say either way), as distinct from a
/// confirmed absence.
String _presenceText(bool? present) {
  if (present == null) return _unknown;
  return present ? 'Yes' : 'No';
}

/// The white "paper" bottom-sheet-style search result card, per
/// docs/design.md § "Screen: Search" (Result sheet): a result row (pin icon
/// + bold place/beach name + grey area subtitle, and a colored weather icon
/// + current temperature on the right), a thin divider, a "Beaches Near"
/// section label, and a two-column block of plain text info lines for a
/// nearby beach.
///
/// Per docs/design.md's "Beach info lines" table, the info lines are **not
/// chips or pills**: no background, border or box around each line, just
/// short text stacked in two columns.
///
/// The left column shows the marine/entry facts — entry price ([Beach.fee]),
/// wave height and water temperature (from a [SeaCondition]-style marine
/// lookup) — and the right column shows nearby amenities — shoes/slippers
/// advice (from [adviseOnShoes]), car park ([Beach.hasParking]), beach club
/// ([Beach.hasBeachResort]) and cafe ([Beach.hasCafe]). A field the source
/// has no data for is rendered as "No data"/"Unknown" text — this widget
/// never invents a value, a zero, or a blank gap.
///
/// The "Beaches Near" info block itself only appears once a caller supplies
/// at least one of these values — i.e. once there is an actual nearby beach
/// to describe. Until then (e.g. a plain placeholder result, as
/// `SearchScreen` renders before the nearby-beaches feature is wired in),
/// every group parameter is left null and the card is just the result row.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency. The caller supplies the already-resolved values (typically
/// read straight off a [Beach] and a marine lookup); this widget only
/// formats and lays them out.
class BeachResultCard extends StatelessWidget {
  const BeachResultCard({
    super.key,
    required this.placeName,
    required this.areaSubtitle,
    required this.temperature,
    this.weatherIcon = Icons.wb_sunny,
    this.fee,
    this.waveHeightMeters,
    this.waterTemperatureCelsius,
    this.shoeAdvice,
    this.hasParking,
    this.hasBeachResort,
    this.hasCafe,
  });

  /// The beach/location name shown bold in the result row (e.g. "Altinkum
  /// Beach").
  final String placeName;

  /// The grey subtitle under [placeName] (e.g. "Cesme, Izmir").
  final String areaSubtitle;

  /// Preformatted current temperature text (e.g. "27°").
  final String temperature;

  /// The colored weather icon shown next to [temperature].
  final IconData weatherIcon;

  /// Whether entry to the beach is paid, free, or unknown — see
  /// [Beach.fee]. OSM has no price data, so this is never a number. Null
  /// when no beach info is being shown at all (see the class docs).
  final BeachFee? fee;

  /// Marine-forecast wave height in meters, or null when no marine data is
  /// available for this beach.
  final double? waveHeightMeters;

  /// Sea surface temperature in Celsius, or null when no marine data is
  /// available for this beach.
  final double? waterTemperatureCelsius;

  /// Advice — never a fact — on whether to bring shoes/slippers. See
  /// [adviseOnShoes]. Null when no beach info is being shown at all (see
  /// the class docs).
  final ShoeAdvice? shoeAdvice;

  /// Whether a car park ([Beach.hasParking]), beach club
  /// ([Beach.hasBeachResort]) or cafe ([Beach.hasCafe]) was found near the
  /// beach. Null means it is unknown, as distinct from a confirmed absence.
  final bool? hasParking;
  final bool? hasBeachResort;
  final bool? hasCafe;

  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);
  static const _iconSun = Color(0xFFFFC94D);
  static const _dividerColor = Color(0xFFE7E8EC);

  /// Whether the caller supplied any beach info at all — i.e. there is an
  /// actual nearby beach to describe, as distinct from a plain placeholder
  /// result row with no beach data behind it yet.
  bool get _hasBeachInfo =>
      fee != null ||
      waveHeightMeters != null ||
      waterTemperatureCelsius != null ||
      shoeAdvice != null ||
      hasParking != null ||
      hasBeachResort != null ||
      hasCafe != null;

  @override
  Widget build(BuildContext context) {
    final leftLines = <_BeachInfoLine>[
      _BeachInfoLine('Entry', _feeText(fee)),
      _BeachInfoLine('Wave height', _waveHeightText(waveHeightMeters)),
      _BeachInfoLine(
        'Water temp',
        _waterTemperatureText(waterTemperatureCelsius),
      ),
    ];
    final rightLines = <_BeachInfoLine>[
      _BeachInfoLine('Shoes', _shoeAdviceText(shoeAdvice)),
      _BeachInfoLine('Car park', _presenceText(hasParking)),
      _BeachInfoLine('Beach club', _presenceText(hasBeachResort)),
      _BeachInfoLine('Cafe', _presenceText(hasCafe)),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _surfacePaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 20, color: _textOnPaper),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textOnPaper,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      areaSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(weatherIcon, size: 20, color: _iconSun),
              const SizedBox(width: 4),
              Text(
                temperature,
                style: const TextStyle(
                  color: _textOnPaper,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (_hasBeachInfo) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            const SizedBox(height: 16),
            const Text(
              'Beaches Near',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InfoColumn(lines: leftLines)),
                const SizedBox(width: 16),
                Expanded(child: _InfoColumn(lines: rightLines)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One column of plain text info lines — no background, border or padding
/// box around a line, just the label and value text stacked vertically.
class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.lines});

  final List<_BeachInfoLine> lines;

  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${line.label}: ',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                Flexible(
                  child: Text(
                    line.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textOnPaper,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
