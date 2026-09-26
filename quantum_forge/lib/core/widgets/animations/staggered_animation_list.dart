import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class StaggeredAnimationList extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final double verticalOffset;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const StaggeredAnimationList({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 500),
    this.verticalOffset = 40.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: AnimationConfiguration.toStaggeredList(
          duration: duration,
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: verticalOffset,
            child: FadeInAnimation(child: widget),
          ),
          children: children,
        ),
      ),
    );
  }
}
