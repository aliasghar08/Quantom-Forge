// ============================================================================
// Library Screen — Searchable, filterable template browser
// ============================================================================

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
  String _searchQuery = '';
  ReactionCategory? _filterCategory;
  List<ReactionTemplate> _allTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    List<ReactionTemplate> templates = const [];
    try {
      templates = await FirestoreLibraryRepository().getLibraryTemplates();
    } catch (e) {
      debugPrint('Library fetch failed, using bundled templates: $e');
    }
    // The library must work signed-out and offline, so fall back to the
    // templates bundled with the app whenever the cloud copy is unavailable.
    if (templates.isEmpty) templates = kReactionTemplates;
    if (mounted) {
      setState(() {
        _allTemplates = templates;
        _isLoading = false;
      });
    }
  }

  List<ReactionTemplate> get _filtered {
    return _allTemplates.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesCategory =
          _filterCategory == null || t.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();
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
          LibraryHeader(
            onSearchChanged: (v) => setState(() => _searchQuery = v),
          ),
          LibraryFilterBar(
            selectedCategory: _filterCategory,
            onCategoryChanged: (cat) => setState(() => _filterCategory = cat),
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
