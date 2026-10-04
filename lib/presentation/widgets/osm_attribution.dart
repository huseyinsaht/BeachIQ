import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The OpenStreetMap copyright/attribution page, per OSM's attribution
/// guidelines: https://www.openstreetmap.org/copyright
final Uri osmCopyrightUri = Uri.parse(
  'https://www.openstreetmap.org/copyright',
);

/// A small, always-visible "© OpenStreetMap contributors" credit, required
/// by OSM's ODbL license on any map using OSM data or tiles.
///
/// Tapping the text opens [osmCopyrightUri]. Compact by design so it can sit
/// in a map card's corner without obscuring content, and legible against
/// both light map tiles and the app's dark background.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency beyond launching the copyright URL.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key, this.onLaunch});

  /// Overridable so widget tests can avoid hitting the real platform
  /// channel. Defaults to [launchUrl].
  final Future<bool> Function(Uri url)? onLaunch;

  static const _background = Color(0x99000000);
  static const _textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => (onLaunch ?? launchUrl)(osmCopyrightUri),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              color: _textColor,
              fontSize: 10,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
