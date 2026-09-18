import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class LibraryGrid extends StatelessWidget {
  final List<ReactionTemplate> items;
  final ValueChanged<ReactionTemplate> onTemplateSelected;

  const LibraryGrid({
    super.key,
    required this.items,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate width for 3 columns with 20px spacing (2 gaps = 40px)
          double cardWidth = (constraints.maxWidth - 40) / 3;
          if (cardWidth < 280) {
            // Drop to 2 columns on narrow windows
            cardWidth = (constraints.maxWidth - 20) / 2;
          }
          
          return SingleChildScrollView(
            child: AnimationLimiter(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 500),
                    columnCount: 3,
                    child: ScaleAnimation(
                      child: FadeInAnimation(
                        child: SizedBox(
                          width: cardWidth,
                          height: 250, // Fix height so all cards occupy same space
                          child: ReactionCardWidget(
                            template: item,
                            onLoad: () => onTemplateSelected(item),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
