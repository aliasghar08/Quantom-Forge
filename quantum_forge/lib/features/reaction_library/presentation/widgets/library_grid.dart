import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

/// Lazily-built grid of reaction cards.
///
/// This previously used `SingleChildScrollView` + `Wrap` and materialised EVERY
/// card up front, each wrapped in a `flutter_staggered_animations` configuration.
/// That is fine for a dozen templates, but the library now holds thousands, so
/// the first frame built thousands of widget trees and the screen janked badly.
///
/// `GridView.builder` builds only the cards inside the viewport (plus the
/// viewport's default cache extent), so cost is proportional to what is *visible*
/// rather than to the size of the library. The staggered entrance animation went
/// with it: it required an `AnimationConfiguration` per child and, on a lazy
/// list, would fire for items scrolled into view long after the page opened.
class LibraryGrid extends StatelessWidget {
  final List<ReactionTemplate> items;
  final ValueChanged<ReactionTemplate> onTemplateSelected;

  const LibraryGrid({
    super.key,
    required this.items,
    required this.onTemplateSelected,
  });

  static const double _spacing = 20;
  static const double _cardHeight = 250;

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
          final width = constraints.maxWidth;
          final columns = width >= 1200
              ? 3
              : width >= 820
                  ? 2
                  : 1;

          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
              // Fixed row height keeps every card identical, and a lazy delegate
              // needs the extent without measuring a child.
              mainAxisExtent: _cardHeight,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              // Keyed by template id so a refiltered list reuses card state
              // instead of rebuilding every visible card from scratch.
              return ReactionCardWidget(
                key: ValueKey(item.id),
                template: item,
                onLoad: () => onTemplateSelected(item),
              );
            },
          );
        },
      ),
    );
  }
}
