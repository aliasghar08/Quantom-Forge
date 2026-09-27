// ============================================================================
// LibraryGrid — paginated grid with custom staggered entrance animation
// ----------------------------------------------------------------------------
// Data comes entirely from Firestore (via LibraryScreen). This widget only
// renders what it receives and triggers more loads via the shared
// ScrollController when the user nears the bottom.
//
// Animation: single AnimationController drives staggered Interval per card —
// no external package, no AnimationLimiter context dependency.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

class LibraryGrid extends StatefulWidget {
  final List<ReactionTemplate> items;
  final ValueChanged<ReactionTemplate> onTemplateSelected;
  final bool isLoadingMore;
  final ScrollController? scrollController;

  const LibraryGrid({
    super.key,
    required this.items,
    required this.onTemplateSelected,
    this.isLoadingMore = false,
    this.scrollController,
  });

  static const double _spacing = 20;
  static const double _cardHeight = 250;

  @override
  State<LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends State<LibraryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Only stagger the first visible screenful. Animating 24+ cards at once
  /// looks great; anything beyond that is outside the viewport anyway.
  static const int _maxAnimated = 24;
  static const Duration _totalDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration)
      ..forward();
  }

  @override
  void didUpdateWidget(LibraryGrid old) {
    super.didUpdateWidget(old);
    // Re-trigger entrance animation when the item set changes
    // (filter or search result replaced the previous list).
    if (old.items.length != widget.items.length ||
        (old.items.isNotEmpty &&
            widget.items.isNotEmpty &&
            old.items.first.id != widget.items.first.id)) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _entranceFor(int index) {
    if (index >= _maxAnimated) return const AlwaysStoppedAnimation(1.0);
    final start = index / _maxAnimated;
    final end = (index + 1) / _maxAnimated;
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200
        ? 3
        : width >= 820
            ? 2
            : 1;

    // Extra slot at the end for the load-more spinner.
    final itemCount =
        widget.items.length + (widget.isLoadingMore ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: GridView.builder(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: LibraryGrid._spacing,
          crossAxisSpacing: LibraryGrid._spacing,
          mainAxisExtent: LibraryGrid._cardHeight,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Load-more spinner occupies the last slot
          if (index >= widget.items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final item = widget.items[index];
          final entrance = _entranceFor(index);

          return AnimatedBuilder(
            animation: entrance,
            builder: (context, child) => Opacity(
              opacity: entrance.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - entrance.value)),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * entrance.value,
                  child: child,
                ),
              ),
            ),
            child: ReactionCardWidget(
              key: ValueKey(item.id),
              template: item,
              onLoad: () => widget.onTemplateSelected(item),
            ),
          );
        },
      ),
    );
  }
}
