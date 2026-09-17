// ============================================================================
// Library Screen — Searchable, filterable template browser
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

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
          _buildHeader(),
          _buildFilterBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reaction Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${kReactionTemplates.length} curated reaction templates with embedded XYZ coordinates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search field
          SizedBox(
            width: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search reactions, tags...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final categories = [null, ...ReactionCategory.values];
    final labels = {
      null: 'All',
      ReactionCategory.pericyclic: 'Pericyclic',
      ReactionCategory.radical: 'Radical',
      ReactionCategory.organometallic: 'Organometallic',
      ReactionCategory.ionic: 'Ionic',
      ReactionCategory.thermal: 'Thermal',
      ReactionCategory.nucleophilic: 'Nucleophilic',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = _filterCategory == cat;
            final color = cat == null
                ? Colors.white
                : _categoryColorStatic(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => setState(() => _filterCategory = cat),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    labels[cat] ?? 'All',
                    style: TextStyle(
                      color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No reactions found',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => ReactionCardWidget(
          template: items[i],
          onLoad: () => widget.onTemplateSelected(items[i]),
        ),
      ),
    );
  }

  Color _categoryColorStatic(ReactionCategory c) {
    switch (c) {
      case ReactionCategory.pericyclic:
        return const Color(0xFF4FC3F7);
      case ReactionCategory.radical:
        return const Color(0xFFFF7043);
      case ReactionCategory.organometallic:
        return const Color(0xFFAB47BC);
      case ReactionCategory.ionic:
        return const Color(0xFF26A69A);
      case ReactionCategory.thermal:
        return const Color(0xFFFFCA28);
      case ReactionCategory.nucleophilic:
        return const Color(0xFF66BB6A);
    }
  }
}
