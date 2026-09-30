import 'package:flutter/material.dart';

import '../../data/static_beaches.dart';
import '../widgets/beach_result_card.dart';
import '../widgets/search_field.dart';

/// The Search screen, per docs/design.md § "Screen: Search": a header (back
/// chevron, centered "Search" title, overflow menu), a [SearchField], and a
/// bottom result sheet of [BeachResultCard] instances under a "Beaches Near"
/// label.
///
/// Backed by [staticBeaches] as placeholder data until the OSM nearby-beaches
/// feature supplies real results. Pure UI composition — no network or
/// provider dependency.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, this.onSearchChanged, this.onSearchSubmitted});

  /// Forwarded to [SearchField]'s `onChanged`. No filtering is wired up yet
  /// — a later issue uses this to query nearby beaches.
  final ValueChanged<String>? onSearchChanged;

  /// Forwarded to [SearchField]'s `onSubmitted`.
  final ValueChanged<String>? onSearchSubmitted;

  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgBase, _bgGradientBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: _textPrimary),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                    const Expanded(
                      child: Text(
                        'Search',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: _textPrimary),
                      onPressed: () {},
                      tooltip: 'More',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _surfacePaper,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Beaches Near',
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: staticBeaches.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final beach = staticBeaches[index];
                            return BeachResultCard(
                              placeName: beach.name,
                              areaSubtitle: beach.city,
                              temperature: '--°',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
