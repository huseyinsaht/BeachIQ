import 'package:flutter/material.dart';

/// A single label/value line shown in [BeachResultCard]'s two-column
/// "Beaches Near" info block.
class _BeachInfoLine {
  const _BeachInfoLine(this.label, this.value);

  final String label;
  final String value;
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
/// short text stacked in two columns. A later issue wires these values to
/// real data (from the Beach/SeaCondition models and OSM lookups); this
/// widget only builds the layout, so every info line is an optional
/// parameter and a missing/omitted one is simply left out — an empty or
/// partial set never crashes the layout.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class BeachResultCard extends StatelessWidget {
  const BeachResultCard({
    super.key,
    required this.placeName,
    required this.areaSubtitle,
    required this.temperature,
    this.weatherIcon = Icons.wb_sunny,
    this.entryPrice,
    this.waveHeight,
    this.waterTemperature,
    this.shoesAdvice,
    this.carPark,
    this.beachClub,
    this.cafe,
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

  // "Beaches Near" info lines. Per docs/design.md's "Beach info lines"
  // table: entry price, wave height and water temperature (the marine
  // group) sit in the left column; shoes advice, car park, beach club and
  // cafe (nearby amenities) sit in the right column. Each is optional —
  // a null value simply omits that line.
  final String? entryPrice;
  final String? waveHeight;
  final String? waterTemperature;
  final String? shoesAdvice;
  final String? carPark;
  final String? beachClub;
  final String? cafe;

  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);
  static const _iconSun = Color(0xFFFFC94D);
  static const _dividerColor = Color(0xFFE7E8EC);

  @override
  Widget build(BuildContext context) {
    final leftLines = <_BeachInfoLine>[
      if (entryPrice != null) _BeachInfoLine('Entry', entryPrice!),
      if (waveHeight != null) _BeachInfoLine('Wave height', waveHeight!),
      if (waterTemperature != null)
        _BeachInfoLine('Water temp', waterTemperature!),
    ];
    final rightLines = <_BeachInfoLine>[
      if (shoesAdvice != null) _BeachInfoLine('Shoes', shoesAdvice!),
      if (carPark != null) _BeachInfoLine('Car park', carPark!),
      if (beachClub != null) _BeachInfoLine('Beach club', beachClub!),
      if (cafe != null) _BeachInfoLine('Cafe', cafe!),
    ];
    final hasInfoLines = leftLines.isNotEmpty || rightLines.isNotEmpty;

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
          if (hasInfoLines) ...[
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
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
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
