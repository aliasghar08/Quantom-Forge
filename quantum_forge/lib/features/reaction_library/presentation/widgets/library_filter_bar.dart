import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

class LibraryFilterBar extends StatelessWidget {
  final ReactionCategory? selectedCategory;
  final ValueChanged<ReactionCategory?> onCategoryChanged;

  const LibraryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [null, ...ReactionCategory.values];
    final labels = {
      null: 'All',
      ReactionCategory.pericyclic: 'Pericyclic',
      ReactionCategory.radical: 'Radical',
      ReactionCategory.organometallic: 'Organometallic',
      ReactionCategory.ionic: 'Ionic',
      ReactionCategory.thermal: 'Thermal',
      ReactionCategory.nucleophilic: 'Nucleophilic',
      ReactionCategory.electrochemistry: 'Electrochem',
      ReactionCategory.inorganic: 'Inorganic',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = selectedCategory == cat;
            final color = cat == null
                ? Colors.white
                : ReactionCardWidget.categoryColor(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => onCategoryChanged(cat),
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
}
