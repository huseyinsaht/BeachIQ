import 'package:flutter/material.dart';

import '../../data/models/beach.dart';
import '../../data/static_beaches.dart';
import '../../logic/providers/favorites_provider.dart';
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
///
/// When [favoritesProvider] is supplied, each result gets a favorite-toggle
/// heart icon and a star button appears in the header to switch the list to
/// favorites only. Null (the default) hides both, so existing callers render
/// exactly as before.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.favoritesProvider,
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

  /// Drives the per-result favorite heart icon and the header's
  /// favorites-only toggle. Null (the default) hides both.
  final FavoritesProvider? favoritesProvider;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8B93A6);
  static const _favoriteActive = Color(0xFFE05B6B);

  String _query = '';
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    widget.favoritesProvider?.addListener(_onFavoritesChanged);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoritesProvider != widget.favoritesProvider) {
      oldWidget.favoritesProvider?.removeListener(_onFavoritesChanged);
      widget.favoritesProvider?.addListener(_onFavoritesChanged);
    }
  }

  @override
  void dispose() {
    widget.favoritesProvider?.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  /// Rebuilds so each result's heart icon (and, while filtering to
  /// favorites only, the list itself) reflects the latest favorites.
  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  /// The placeholder beach list, filtered by [_query] against each beach's
  /// name or city (case-insensitive substring match), and further narrowed
  /// to favorites only when [_showFavoritesOnly] is set. An empty query
  /// (the default) matches everything, so this renders identically to the
  /// unfiltered list until the user types.
  List<Beach> get _filteredBeaches {
    final query = _query.trim().toLowerCase();
    var beaches = query.isEmpty
        ? staticBeaches
        : staticBeaches
              .where(
                (beach) =>
                    beach.name.toLowerCase().contains(query) ||
                    beach.city.toLowerCase().contains(query),
              )
              .toList();

    final favoritesProvider = widget.favoritesProvider;
    if (_showFavoritesOnly && favoritesProvider != null) {
      beaches = favoritesProvider.favoritesAmong(beaches);
    }
    return beaches;
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
    widget.onSearchChanged?.call(value);
  }

  void _toggleShowFavoritesOnly() {
    setState(() => _showFavoritesOnly = !_showFavoritesOnly);
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = widget.favoritesProvider;
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
                    if (favoritesProvider != null)
                      IconButton(
                        icon: Icon(
                          _showFavoritesOnly ? Icons.star : Icons.star_border,
                          color: _showFavoritesOnly
                              ? _favoriteActive
                              : _textPrimary,
                        ),
                        onPressed: _toggleShowFavoritesOnly,
                        tooltip: _showFavoritesOnly
                            ? 'Show all beaches'
                            : 'Show favorites only',
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
                      Text(
                        _showFavoritesOnly ? 'Favorites' : 'Beaches Near',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
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
  /// "no matches"/"no favorites" message, or the (placeholder) results
  /// list, matching [SearchScreen.isLoading]/[SearchScreen.error], [_query]
  /// and [_showFavoritesOnly].
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
      final message = _showFavoritesOnly
          ? 'No favorite beaches yet.'
          : 'No beaches match "${_query.trim()}".';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    final favoritesProvider = widget.favoritesProvider;
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
          isFavorite: favoritesProvider?.isFavorite(beach) ?? false,
          onFavoriteToggle: favoritesProvider == null
              ? null
              : () => favoritesProvider.toggleFavorite(beach),
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
