import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/beach.dart';
import '../../data/models/place.dart';
import '../../data/static_beaches.dart';
import '../../logic/beach_gear_advisor.dart';
import '../../logic/providers/favorites_provider.dart';
import '../../logic/providers/nearby_beaches_provider.dart';
import '../../logic/providers/place_search_provider.dart';
import '../../logic/providers/unit_preferences_provider.dart';
import '../../logic/unit_preferences.dart';
import '../widgets/beach_result_card.dart';
import '../widgets/search_field.dart';

/// The Search screen, per docs/design.md § "Screen: Search": a header (back
/// chevron, centered "Search" title, overflow menu), a [SearchField], and a
/// bottom result sheet of [BeachResultCard] instances under a "Beaches Near"
/// label.
///
/// Backed by [staticBeaches] as placeholder data until [nearbyBeachesProvider]
/// is supplied. Pure UI composition — no network dependency of its own;
/// [nearbyBeachesProvider]'s loading/error states (combined with
/// [isLoading]/[error], which a caller can still set directly) drive the
/// loading/error states instead of the results list. The search field
/// filters the (placeholder or real) results list by name or city as the
/// user types, in addition to forwarding to
/// [onSearchChanged]/[onSearchSubmitted].
///
/// When [favoritesProvider] is supplied, each result gets a favorite-toggle
/// heart icon and a star button appears in the header to switch the list to
/// favorites only. Null (the default) hides both, so existing callers render
/// exactly as before.
///
/// When [placeSearchProvider] is supplied, typing also searches real places
/// by name (any city, not limited to [staticBeaches]/the current
/// [nearbyBeachesProvider] results) and shows them in a "Places" section
/// above the beach list; selecting one re-centers [nearbyBeachesProvider].
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.favoritesProvider,
    this.unitPreferencesProvider,
    this.nearbyBeachesProvider,
    this.placeSearchProvider,
  });

  /// Forwarded to [SearchField]'s `onChanged`, alongside the local
  /// name/city filtering this screen now does on its own.
  final ValueChanged<String>? onSearchChanged;

  /// Forwarded to [SearchField]'s `onSubmitted`.
  final ValueChanged<String>? onSearchSubmitted;

  /// Called on a pull-to-refresh gesture over the result sheet. Null (the
  /// default) makes the gesture a no-op, so today's [staticBeaches]
  /// placeholder callers render exactly as before.
  final Future<void> Function()? onRefresh;

  /// Whether a search/nearby-beaches request is in flight, combined (via
  /// OR) with [nearbyBeachesProvider]'s own `isLoading` when one is
  /// supplied. Defaults to false, so today's [staticBeaches] placeholder
  /// callers render exactly as before.
  final bool isLoading;

  /// A user-readable error message to show instead of the results list,
  /// combined with [nearbyBeachesProvider]'s own `error` when one is
  /// supplied (this field wins when both are set). Null (the default)
  /// renders normally.
  final String? error;

  /// Drives the per-result favorite heart icon and the header's
  /// favorites-only toggle. Null (the default) hides both.
  final FavoritesProvider? favoritesProvider;

  /// Drives each result's wave-height/water-temperature unit formatting
  /// and the header overflow menu's unit toggle. Null (the default)
  /// renders every value in metric, unchanged from before.
  final UnitPreferencesProvider? unitPreferencesProvider;

  /// The real nearby-beaches results (and their marine data), replacing
  /// [staticBeaches] and feeding each [BeachResultCard]'s beach-info block
  /// (entry fee, wave height, water temperature, shoe advice, and nearby
  /// amenities) once supplied. Also feeds this screen's loading/error
  /// states (see [isLoading]/[error]). Null (the default) renders the
  /// static placeholder list with no beach-info block, unchanged from
  /// before.
  final NearbyBeachesProvider? nearbyBeachesProvider;

  /// Searches real places by name (any city, not just the current
  /// [nearbyBeachesProvider] results or [staticBeaches]) as the user types,
  /// shown as a "Places" section between the search field and the beach
  /// list. Selecting one calls [NearbyBeachesProvider.pickLocation] with its
  /// coordinates. Null (the default) hides the section entirely, so
  /// existing callers render exactly as before — the name/city filter over
  /// [nearbyBeachesProvider]/[staticBeaches] still works either way.
  final PlaceSearchProvider? placeSearchProvider;

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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.favoritesProvider?.addListener(_onProviderChanged);
    widget.unitPreferencesProvider?.addListener(_onProviderChanged);
    widget.nearbyBeachesProvider?.addListener(_onProviderChanged);
    widget.placeSearchProvider?.addListener(_onProviderChanged);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoritesProvider != widget.favoritesProvider) {
      oldWidget.favoritesProvider?.removeListener(_onProviderChanged);
      widget.favoritesProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.unitPreferencesProvider != widget.unitPreferencesProvider) {
      oldWidget.unitPreferencesProvider?.removeListener(_onProviderChanged);
      widget.unitPreferencesProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.nearbyBeachesProvider != widget.nearbyBeachesProvider) {
      oldWidget.nearbyBeachesProvider?.removeListener(_onProviderChanged);
      widget.nearbyBeachesProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.placeSearchProvider != widget.placeSearchProvider) {
      oldWidget.placeSearchProvider?.removeListener(_onProviderChanged);
      widget.placeSearchProvider?.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.favoritesProvider?.removeListener(_onProviderChanged);
    widget.unitPreferencesProvider?.removeListener(_onProviderChanged);
    widget.nearbyBeachesProvider?.removeListener(_onProviderChanged);
    widget.placeSearchProvider?.removeListener(_onProviderChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Rebuilds so each result's heart icon (and, while filtering to
  /// favorites only, the list itself) reflects the latest favorites, so a
  /// unit-system change re-formats the wave-height/water-temperature
  /// lines, and so a [NearbyBeachesProvider] fetch resolving refreshes the
  /// results list and loading/error states.
  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  /// The beach list — [NearbyBeachesProvider.beaches] once
  /// [SearchScreen.nearbyBeachesProvider] is supplied, else the
  /// [staticBeaches] placeholder — filtered by [_query] against each
  /// beach's name or city (case-insensitive substring match), and further
  /// narrowed to favorites only when [_showFavoritesOnly] is set. An empty
  /// query (the default) matches everything, so this renders identically
  /// to the unfiltered list until the user types.
  List<Beach> get _filteredBeaches {
    final source = widget.nearbyBeachesProvider?.beaches ?? staticBeaches;
    final query = _query.trim().toLowerCase();
    var beaches = query.isEmpty
        ? source
        : source
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
    widget.placeSearchProvider?.search(value);
    widget.onSearchChanged?.call(value);
  }

  void _toggleShowFavoritesOnly() {
    setState(() => _showFavoritesOnly = !_showFavoritesOnly);
  }

  /// Picks [place]'s coordinates for [NearbyBeachesProvider] and clears the
  /// search field/place results, so the (now re-centered) beach list shows
  /// unfiltered once it loads.
  void _selectPlace(Place place) {
    widget.nearbyBeachesProvider?.pickLocation(
      LatLng(place.latitude, place.longitude),
    );
    widget.placeSearchProvider?.search('');
    _searchController.clear();
    setState(() => _query = '');
  }

  /// A short "City, Country"-style subtitle for [place], or null when
  /// neither part of its region is known.
  String? _placeSubtitle(Place place) {
    final parts = [
      if (place.admin1 != null) place.admin1!,
      if (place.country != null) place.country!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
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
                      onPressed: () {
                        final provider = widget.unitPreferencesProvider;
                        if (provider != null) {
                          _showUnitSystemSheet(context, provider);
                        }
                      },
                      tooltip: 'More',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  controller: _searchController,
                  onChanged: _handleSearchChanged,
                  onSubmitted: widget.onSearchSubmitted,
                ),
              ),
              _buildPlaceResults(),
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

  /// The real-place search results section, shown between the search field
  /// and the beach list whenever [SearchScreen.placeSearchProvider] is
  /// supplied and the user has typed something: a loading row while a
  /// search is in flight, an error/empty message, or a tappable list of
  /// [Place] matches. Returns an empty widget (no layout space) when there
  /// is no provider or the query is blank, matching [PlaceSearchProvider]'s
  /// own idle state for an empty query.
  Widget _buildPlaceResults() {
    final provider = widget.placeSearchProvider;
    if (provider == null || _query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    Widget content;
    switch (provider.status) {
      case PlaceSearchStatus.idle:
        return const SizedBox.shrink();
      case PlaceSearchStatus.loading:
        content = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case PlaceSearchStatus.error:
        content = Text(
          provider.error ?? 'Could not search for places.',
          style: const TextStyle(color: _textPrimary, fontSize: 13),
        );
      case PlaceSearchStatus.empty:
        content = Text(
          'No places match "${_query.trim()}".',
          style: const TextStyle(color: _textSecondary, fontSize: 13),
        );
      case PlaceSearchStatus.loaded:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < provider.results.length; i++)
              _buildPlaceResultRow(i, provider.results[i]),
          ],
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: content,
    );
  }

  /// One row of the loaded "Places" list, keyed by [index] rather than the
  /// place's name alone: geocoding results routinely share a name (e.g. two
  /// different "Paris"es), and a name-only key would collide and trip
  /// Flutter's duplicate-key assertion.
  Widget _buildPlaceResultRow(int index, Place place) {
    final subtitle = _placeSubtitle(place);
    return InkWell(
      key: ValueKey('place-result-$index-${place.name}'),
      onTap: () => _selectPlace(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 18, color: _textPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bottom-sheet body: a loading spinner, an error message, a
  /// "no matches"/"no favorites" message, or the (placeholder) results
  /// list, matching [SearchScreen.isLoading]/[SearchScreen.error], [_query]
  /// and [_showFavoritesOnly].
  Widget _buildResults() {
    final nearbyBeachesProvider = widget.nearbyBeachesProvider;
    if (widget.isLoading || (nearbyBeachesProvider?.isLoading ?? false)) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = widget.error ?? nearbyBeachesProvider?.error;
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
    final unitSystem =
        widget.unitPreferencesProvider?.unitSystem ?? UnitSystem.metric;
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: beaches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final beach = beaches[index];
        final seaCondition = nearbyBeachesProvider?.seaConditionFor(beach);
        return BeachResultCard(
          placeName: beach.name,
          areaSubtitle: beach.city,
          temperature: '--°',
          fee: nearbyBeachesProvider == null ? null : beach.fee,
          waveHeightMeters: seaCondition?.waveHeight,
          waterTemperatureCelsius: seaCondition?.seaSurfaceTemperature,
          shoeAdvice: nearbyBeachesProvider == null
              ? null
              : adviseOnShoes(beach.surface),
          hasParking: nearbyBeachesProvider == null ? null : beach.hasParking,
          hasBeachResort: nearbyBeachesProvider == null
              ? null
              : beach.hasBeachResort,
          hasCafe: nearbyBeachesProvider == null ? null : beach.hasCafe,
          isFavorite: favoritesProvider?.isFavorite(beach) ?? false,
          onFavoriteToggle: favoritesProvider == null
              ? null
              : () => favoritesProvider.toggleFavorite(beach),
          unitSystem: unitSystem,
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

/// Opens a small bottom sheet to switch between metric and imperial units,
/// the "small toggle entry point" added to this screen's existing overflow
/// ("...") header menu (an identical copy of this lives in `main.dart` for
/// the Home screen's map card overflow menu, matching this codebase's
/// existing convention of small per-file duplication over a
/// presentation/main.dart cross-dependency).
Future<void> _showUnitSystemSheet(
  BuildContext context,
  UnitPreferencesProvider provider,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in UnitSystem.values)
              RadioListTile<UnitSystem>(
                title: Text(
                  option == UnitSystem.metric
                      ? 'Metric (m, °C, km/h)'
                      : 'Imperial (ft, °F, mph)',
                ),
                value: option,
                groupValue: provider.unitSystem,
                onChanged: (value) {
                  if (value != null) provider.setUnitSystem(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}
