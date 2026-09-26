// ============================================================================
// Library Screen — Searchable, filterable template browser
//
// Performance notes (the library now holds thousands of templates):
//   * filtering happens once per input change, not on every build;
//   * the search box is debounced so typing does not rebuild the grid per key;
//   * the grid itself builds only the cards inside the viewport (see LibraryGrid).
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_template_generator.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_header.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_filter_bar.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_grid.dart';

import 'package:quantum_forge/features/reaction_library/data/firestore_library_repository.dart';

class LibraryScreen extends StatefulWidget {
  final void Function(ReactionTemplate template) onTemplateSelected;

  const LibraryScreen({super.key, required this.onTemplateSelected});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const Duration _searchDebounce = Duration(milliseconds: 180);

  String _query = '';
  ReactionCategory? _filterCategory;
  List<ReactionTemplate> _allTemplates = const [];
  List<ReactionTemplate> _filtered = const [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    // The bundled library (curated + generated variants) is always present, so
    // start from it and layer any cloud-only extras on top instead of replacing
    // it — the library must keep working signed-out and offline.
    final bundled = allReactionTemplates;
    var merged = bundled;

    try {
      // Heavily optimised: only fetch the first 50 non-derived templates on load.
      final cloud = await FirestoreLibraryRepository().getLibraryTemplates(
        category: _filterCategory,
        limit: 50,
      );
      if (cloud.isNotEmpty) {
        final known = bundled.map((t) => t.id).toSet();
        merged = <ReactionTemplate>[
          ...bundled,
          ...cloud.where((t) => !known.contains(t.id)),
        ];
      }
    } catch (e) {
      debugPrint('Library fetch failed, using bundled templates: $e');
    }

    if (!mounted) return;
    setState(() {
      _allTemplates = merged;
      _recomputeFiltered();
      _isLoading = false;
    });
  }

  /// Filters once per input change rather than on every build.
  ///
  /// The previous `_filtered` getter re-scanned and re-allocated the entire
  /// library on every rebuild — including every hover and animation frame.
  void _recomputeFiltered() {
    final query = _query.trim().toLowerCase();
    final category = _filterCategory;

    if (query.isEmpty && category == null) {
      _filtered = _allTemplates;
      return;
    }

    _filtered = _allTemplates.where((t) {
      if (category != null && t.category != category) return false;
      if (query.isEmpty) return true;
      return t.name.toLowerCase().contains(query) ||
          t.iupacName.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query) ||
          t.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  Future<void> _performCloudSearch(String query) async {
    try {
      // Fetch up to 50 matching records from the cloud.
      final cloudResults = await FirestoreLibraryRepository().searchLibraryTemplates(
        query,
        category: _filterCategory,
        limit: 50,
      );
      if (!mounted) return;
      if (cloudResults.isNotEmpty) {
        final known = _allTemplates.map((t) => t.id).toSet();
        final newItems = cloudResults.where((t) => !known.contains(t.id)).toList();
        if (newItems.isNotEmpty) {
          setState(() {
            _allTemplates = <ReactionTemplate>[..._allTemplates, ...newItems];
            _recomputeFiltered();
          });
        }
      }
    } catch (e) {
      debugPrint('Cloud search failed: $e');
    }
  }

  void _onSearchChanged(String value) {
    // Debounced: filtering thousands of templates on every keystroke would
    // rebuild the grid once per character typed.
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _recomputeFiltered(); // Instantly filter local items
      });
      // Fire off a cloud search to pull in massive library items not yet loaded
      if (value.isNotEmpty) {
        _performCloudSearch(value);
      }
    });
  }

  void _onCategoryChanged(ReactionCategory? category) {
    setState(() {
      _filterCategory = category;
      _recomputeFiltered();
    });
    // If we changed category, we should pull cloud items for the new category
    _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.backgroundGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibraryHeader(onSearchChanged: _onSearchChanged),
          LibraryFilterBar(
            selectedCategory: _filterCategory,
            onCategoryChanged: _onCategoryChanged,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LibraryGrid(
                    items: _filtered,
                    onTemplateSelected: widget.onTemplateSelected,
                  ),
          ),
        ],
      ),
    );
  }
}
