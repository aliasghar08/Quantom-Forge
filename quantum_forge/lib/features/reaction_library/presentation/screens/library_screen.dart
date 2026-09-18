// ============================================================================
// Library Screen — Searchable, filterable template browser
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_header.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_filter_bar.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_grid.dart';

class LibraryScreen extends StatefulWidget {
  final void Function(ReactionTemplate template) onTemplateSelected;

  const LibraryScreen({super.key, required this.onTemplateSelected});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _searchQuery = '';
  ReactionCategory? _filterCategory;

  List<ReactionTemplate> get _filtered {
    return kReactionTemplates.where((t) {
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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
            child: LibraryGrid(
              items: _filtered,
              onTemplateSelected: widget.onTemplateSelected,
            ),
          ),
        ],
      ),
    );
  }
}
