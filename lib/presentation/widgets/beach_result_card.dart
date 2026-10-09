import 'package:flutter/material.dart';

import '../../data/models/beach.dart';
import '../../data/models/depth_profile.dart';
import '../../logic/beach_gear_advisor.dart';
import '../../logic/shallow_entry.dart';
import '../../logic/shallow_entry_status.dart';
import '../../logic/shallow_entry_verdict.dart';
import '../../logic/unit_preferences.dart';

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

/// Renders a marine-forecast wave height, or "No data" when no marine data
/// is available for this beach. [unitSystem]'s metric output is identical
/// to [formatWaveHeight]'s own metric string ("X.Y m"), so this delegates
/// straight to it for both systems.
String _waveHeightText(double? meters, UnitSystem unitSystem) {
  if (meters == null) return _noData;
  return formatWaveHeight(meters, unitSystem);
}

/// Renders a sea surface temperature, or "No data" when no marine data is
/// available for this beach. Metric keeps today's exact bare-degree style
/// (no unit letter, unlike [formatTemperature]'s "°C"); imperial converts
/// via [celsiusToFahrenheit] and appends "F" so the active system stays
/// legible.
String _waterTemperatureText(double? celsius, UnitSystem unitSystem) {
  if (celsius == null) return _noData;
  if (unitSystem == UnitSystem.imperial) {
    return '${celsiusToFahrenheit(celsius).round()}°F';
  }
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
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.unitSystem = UnitSystem.metric,
    this.onTap,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(32)),
    this.showDepthSummary = false,
    this.isDepthLoading = false,
    this.depthProfile,
    this.onDepthTap,
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

  /// Whether this beach is currently marked as a favorite. Ignored (no
  /// icon shown) when [onFavoriteToggle] is null.
  final bool isFavorite;

  /// Called when the favorite icon is tapped. Null (the default) hides
  /// the icon entirely, so existing callers render exactly as before.
  final VoidCallback? onFavoriteToggle;

  /// The unit system [waveHeightMeters]/[waterTemperatureCelsius] render
  /// in. Defaults to [UnitSystem.metric], matching every existing caller's
  /// output exactly.
  final UnitSystem unitSystem;

  /// Called when the card itself (anywhere outside the favorite heart's own
  /// tap target) is tapped — e.g. to show this beach on the Home map. Null
  /// (the default) renders a plain, non-interactive card, unchanged from
  /// before.
  final VoidCallback? onTap;

  /// The card's corner rounding. Defaults to the bottom-sheet-style
  /// top-only radius `SearchScreen`'s result sheet needs; a caller that
  /// shows this card elsewhere (e.g. `HomeScreen`'s compact selected-beach
  /// row, #214, not anchored to a screen edge) can pass a fully rounded
  /// shape instead.
  final BorderRadius borderRadius;

  /// Shows a one/two-line water-depth summary under the result row (issue
  /// #257) -- never shown unless a caller explicitly opts in, so
  /// [SearchScreen]'s result list (which never fetches a depth profile per
  /// result) renders exactly as before. Only `HomeScreen`'s selected-beach
  /// info row passes `true`.
  final bool showDepthSummary;

  /// Whether the depth fetch for this beach is still in flight -- shows a
  /// small loading placeholder instead of guessing a verdict. Ignored when
  /// [showDepthSummary] is `false`.
  final bool isDepthLoading;

  /// The selected beach's depth profile, or `null` when there is none yet
  /// (and [isDepthLoading] is `false`) -- renders "Depth: no data", never a
  /// guessed verdict. Ignored when [showDepthSummary] is `false`.
  final DepthProfile? depthProfile;

  /// Called when the depth summary row is tapped, to open the full
  /// water-depth detail screen (issue #256) -- the one place the full
  /// [depthApproximationCaveat] is shown, so the summary itself only needs
  /// [depthApproximationCaveatShort]. Ignored when [showDepthSummary] is
  /// `false`.
  final VoidCallback? onDepthTap;

  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);
  static const _iconSun = Color(0xFFFFC94D);
  static const _dividerColor = Color(0xFFE7E8EC);
  static const _favoriteActive = Color(0xFFE05B6B);

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
      _BeachInfoLine(
        'Wave height',
        _waveHeightText(waveHeightMeters, unitSystem),
      ),
      _BeachInfoLine(
        'Water temp',
        _waterTemperatureText(waterTemperatureCelsius, unitSystem),
      ),
    ];
    final rightLines = <_BeachInfoLine>[
      _BeachInfoLine('Shoes', _shoeAdviceText(shoeAdvice)),
      _BeachInfoLine('Car park', _presenceText(hasParking)),
      _BeachInfoLine('Beach club', _presenceText(hasBeachResort)),
      _BeachInfoLine('Cafe', _presenceText(hasCafe)),
    ];

    return Container(
      // The outer Container (rather than Material/InkWell directly) stays
      // the single ancestor "box" of this card's content — matching
      // docs/design.md's "not chips or pills" direction for the info lines
      // inside it, and what beach_result_card_test.dart's "no Container
      // wraps an individual info line" check asserts. ClipRRect clips
      // InkWell's ripple to the same rounded corners; Material's
      // `transparency` type means it paints no background of its own,
      // leaving this Container's `color` as the one visible surface.
      decoration: BoxDecoration(
        color: _surfacePaper,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: _textOnPaper,
                      ),
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
                      if (onFavoriteToggle != null)
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: isFavorite
                                ? _favoriteActive
                                : _textSecondary,
                          ),
                          onPressed: onFavoriteToggle,
                          tooltip: isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          // Default IconButton padding/constraints give a 48x48
                          // tap target (Material's minimum), rather than shrinking
                          // it down to the icon's own visual size.
                        ),
                    ],
                  ),
                  if (showDepthSummary) ...[
                    const SizedBox(height: 12),
                    _DepthSummaryRow(
                      isLoading: isDepthLoading,
                      profile: depthProfile,
                      unitSystem: unitSystem,
                      onTap: onDepthTap,
                    ),
                  ],
                  if (_hasBeachInfo) ...[
                    const SizedBox(height: 16),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: _dividerColor,
                    ),
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
            ),
          ),
        ),
      ),
    );
  }
}

/// The optional water-depth / non-swimmer summary row (issue #257): a
/// small icon, a one-line plain-language verdict (reusing
/// [shallowEntryVerdictLine]'s exact wording, never a new paraphrase), and
/// a secondary line combining the stand-up distance (when known) and the
/// shortened approximation caveat. Tapping it opens the full water-depth
/// detail screen, where [depthApproximationCaveat] is shown in full.
class _DepthSummaryRow extends StatelessWidget {
  const _DepthSummaryRow({
    required this.isLoading,
    required this.profile,
    required this.unitSystem,
    required this.onTap,
  });

  final bool isLoading;
  final DepthProfile? profile;
  final UnitSystem unitSystem;
  final VoidCallback? onTap;

  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final classification = profile == null
        ? null
        : classifyShallowEntry(profile!);
    final steepness = classification?.steepness;

    String verdictText;
    Color verdictColor;
    String? secondaryText;
    if (isLoading) {
      verdictText = 'Depth: checking…';
      verdictColor = _textSecondary;
    } else if (classification == null ||
        steepness == ShallowEntrySteepness.unknown) {
      verdictText = 'Depth: no data';
      verdictColor = _textSecondary;
    } else {
      verdictText = shallowEntryVerdictLine(steepness!);
      verdictColor = shallowEntryStatusColor(steepness) ?? _textOnPaper;
      final distanceLabel = standUpDistanceLabel(
        classification,
        profile!,
        unitSystem,
      );
      secondaryText = distanceLabel == null
          ? depthApproximationCaveatShort
          : '$distanceLabel · $depthApproximationCaveatShort';
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.waves, size: 18, color: verdictColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      verdictText,
                      style: TextStyle(
                        color: verdictColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (secondaryText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryText,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
