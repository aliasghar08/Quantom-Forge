// ============================================================================
// Library Screen — Server-side paginated Firestore browser
//
// Architecture:
//   * ALL data comes from Firestore. No local generation in this screen.
//   * First page (24 items) loads on open.
//   * Subsequent pages load as the user scrolls toward the bottom.
//   * Search + category filter hit Firestore indexes — never local arrays.
//   * The 41 curated templates are seeded on first-run only (not 200K variants).
// ============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
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
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  final _repo = FirestoreLibraryRepository();
  final _scrollController = ScrollController();

  // ── State ──────────────────────────────────────────────────────────────────
  String _query = '';
  ReactionCategory? _filterCategory;

  List<ReactionTemplate> _items = [];
  DocumentSnapshot? _nextCursor;
  bool _isFirstLoad = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int? _cloudCount; // null = loading, -1 = unavailable

  String _error = '';

  Timer? _debounce;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _fetchCloudCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll → load more ────────────────────────────────────────────────────

  void _onScroll() {
    final pos = _scrollController.position;
    // Trigger when within 300px of the bottom
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        _query.isEmpty) {
      _loadNextPage();
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadFirstPage() async {
    setState(() {
      _isFirstLoad = true;
      _error = '';
      _items = [];
      _nextCursor = null;
      _hasMore = true;
    });

    if (_query.isNotEmpty) {
      await _runSearch(_query);
      return;
    }

    try {
      final page = await _repo.getPage(category: _filterCategory);
      if (!mounted) return;
      if (page.items.isEmpty) {
        // Firestore empty — auto-seed the 41 curated base templates.
        await _seedCurated();
        return;
      }
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load library. Check your connection.';
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repo.getPage(
        category: _filterCategory,
        after: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _runSearch(String query) async {
    try {
      final results =
          await _repo.search(query, category: _filterCategory);
      if (!mounted) return;
      setState(() {
        _items = results;
        _nextCursor = null;
        _hasMore = false; // search results are not paginated further
        _isFirstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Check your connection.';
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _fetchCloudCount() async {
    final count = await _repo.getTotalCount();
    if (mounted) setState(() => _cloudCount = count);
  }

  /// Seeds only the 41 curated templates on first run (not the 200K variants).
  Future<void> _seedCurated() async {
    debugPrint('Firestore empty — seeding curated templates...');
    try {
      await _repo.seedLibrary(kReactionTemplates);
    } catch (e) {
      debugPrint('Seed failed: $e');
    }
    if (!mounted) return;
    // Re-fetch after seeding
    _loadFirstPage();
  }

  // ── Event handlers ─────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      if (value.trim().isEmpty) {
        _loadFirstPage();
      } else {
        _runSearch(value.trim());
      }
    });
  }

  void _onCategoryChanged(ReactionCategory? category) {
    setState(() => _filterCategory = category);
    _loadFirstPage();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          LibraryHeader(
            localCount: _items.length,
            cloudCount: _cloudCount,
            onSearchChanged: _onSearchChanged,
            onRefreshCount: () {
              setState(() => _cloudCount = null);
              _fetchCloudCount();
            },
          ),
          LibraryFilterBar(
            selectedCategory: _filterCategory,
            onCategoryChanged: _onCategoryChanged,
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isFirstLoad) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading library from cloud…',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(_error,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              _query.isNotEmpty
                  ? 'No reactions match "$_query"'
                  : 'No reactions found',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LibraryGrid(
      items: _items,
      onTemplateSelected: widget.onTemplateSelected,
      isLoadingMore: _isLoadingMore,
      scrollController: _scrollController,
    );
  }
}
