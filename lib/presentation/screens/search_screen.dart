import 'package:flutter/material.dart';

import '../../data/models/beach.dart';
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
/// provider dependency of its own; [isLoading]/[error] let a caller (e.g. a
/// future `NearbyBeachesProvider` integration) drive the loading/error
/// states instead of the results list. The search field filters the
/// (placeholder or future real) results list by name or city as the user
/// types, in addition to forwarding to [onSearchChanged]/[onSearchSubmitted].
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.isLoading = false,
    this.error,
    this.onRefresh,
  });

  /// Forwarded to [SearchField]'s `onChanged`, alongside the local
  /// name/city filtering this screen now does on its own.
  final ValueChanged<String>? onSearchChanged;

  /// Forwarded to [SearchField]'s `onSubmitted`.
  final ValueChanged<String>? onSearchSubmitted;

  /// Called on a pull-to-refresh gesture over the result sheet, mirroring
  /// a caller's `NearbyBeachesProvider` re-fetch. Null (the default) makes
  /// the gesture a no-op, so today's [staticBeaches] placeholder callers
  /// render exactly as before.
  final Future<void> Function()? onRefresh;

  /// Whether a search/nearby-beaches request is in flight, mirroring
  /// `NearbyBeachesProvider.isLoading`. Defaults to false, so today's
  /// [staticBeaches] placeholder callers render exactly as before.
  final bool isLoading;

  /// A user-readable error message to show instead of the results list,
  /// mirroring `NearbyBeachesProvider.error`. Null (the default) renders
  /// normally.
  final String? error;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8B93A6);

  String _query = '';

  /// The placeholder beach list, filtered by [_query] against each beach's
  /// name or city (case-insensitive substring match). An empty query (the
  /// default) matches everything, so this renders identically to the
  /// unfiltered list until the user types.
  List<Beach> get _filteredBeaches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return staticBeaches;
    return staticBeaches
        .where(
          (beach) =>
              beach.name.toLowerCase().contains(query) ||
              beach.city.toLowerCase().contains(query),
        )
        .toList();
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
    widget.onSearchChanged?.call(value);
  }

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
                  onChanged: _handleSearchChanged,
                  onSubmitted: widget.onSearchSubmitted,
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
                      Expanded(child: _buildResults()),
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

  /// The bottom-sheet body: a loading spinner, an error message, a
  /// "no matches" message, or the (placeholder) results list, matching
  /// [SearchScreen.isLoading]/[SearchScreen.error] and [_query].
  Widget _buildResults() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = widget.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load beaches.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    final beaches = _filteredBeaches;
    if (beaches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No beaches match "${_query.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: beaches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final beach = beaches[index];
        return BeachResultCard(
          placeName: beach.name,
          areaSubtitle: beach.city,
          temperature: '--°',
        );
      },
    );

    // Only wrap in a RefreshIndicator when there is something for it to
    // actually do — otherwise a pull gesture would show a spinner that
    // resolves into a no-op.
    final refresh = widget.onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(onRefresh: refresh, child: list);
  }
}
