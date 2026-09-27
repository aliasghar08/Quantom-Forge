// ============================================================================
// LibraryGrid — zero-dependency staggered entrance animation
// ----------------------------------------------------------------------------
// Previously used flutter_staggered_animations, which depends on an
// AnimationLimiter ancestor providing a context-extension. That contract
// silently breaks when AnimationLimiter is separated from the GridView by any
// widget that rebuilds on its own (LayoutBuilder, ValueListenableBuilder,
// etc.), causing every card to stay at opacity 0 / scale 0.85 forever.
//
// This file replaces it with a hand-rolled implementation that:
//   1. Keeps NO package dependency — pure Flutter SDK only.
//   2. Uses a single AnimationController per grid widget (not per card), which
//      drives a staggered Interval for each item index, exactly like the
//      package did internally.
//   3. Works correctly inside an Expanded → GridView.builder tree with zero
//      unbounded-height issues, because GridView.builder is never wrapped.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

class LibraryGrid extends StatefulWidget {
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
  State<LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends State<LibraryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // How many cards get the staggered treatment before we just show the rest
  // immediately. With 200k items, only the first screenful is visible; animating
  // beyond that would never be seen anyway.
  static const int _maxAnimated = 30;

  // Total duration covers all staggered items.
  static const Duration _totalDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..forward();
  }

  @override
  void didUpdateWidget(LibraryGrid old) {
    super.didUpdateWidget(old);
    // Re-run the entrance animation whenever the item list changes
    // (e.g. filter changed, search query updated).
    if (old.items != widget.items) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns a [CurvedAnimation] for the card at [index], staggered so
  /// earlier cards finish before later ones start.
  Animation<double> _entranceFor(int index) {
    if (index >= _maxAnimated) {
      // Items beyond the animated window are shown immediately.
      return const AlwaysStoppedAnimation(1.0);
    }
    final start = index / _maxAnimated;
    final end = (index + 1) / _maxAnimated;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No reactions found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200
        ? 3
        : width >= 820
            ? 2
            : 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: LibraryGrid._spacing,
          crossAxisSpacing: LibraryGrid._spacing,
          mainAxisExtent: LibraryGrid._cardHeight,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final entrance = _entranceFor(index);

          return AnimatedBuilder(
            animation: entrance,
            builder: (context, child) {
              return Opacity(
                opacity: entrance.value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - entrance.value)),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * entrance.value,
                    child: child,
                  ),
                ),
              );
            },
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
