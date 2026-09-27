import 'package:flutter/material.dart';

enum StaggerAnimationType {
  slideVertical,
  slideHorizontal,
  scale,
  fade,
}

/// A comprehensive, scratch-built staggered animation system.
/// Wraps a list of children and animates them sequentially when mounted.
/// Doesn't force a Column/Row layout—takes a `wrapperBuilder` so you can
/// wrap the animated children in a Wrap, ListView, Row, or anything else.
class StaggeredGroup extends StatefulWidget {
  final List<Widget> children;
  
  /// Base duration for each child's individual animation
  final Duration childDuration;
  
  /// Delay between the start of one child's animation and the next
  final Duration staggerDelay;
  
  /// Animation curve
  final Curve curve;
  
  /// The visual effect to apply
  final StaggerAnimationType type;
  
  /// Distance in logical pixels for sliding animations (positive = slide from bottom/right)
  final double slideOffset;
  
  /// How to lay out the animated children. If null, defaults to a Column.
  final Widget Function(BuildContext context, List<Widget> children)? wrapperBuilder;
  
  /// If true, automatically starts animation on mount. Otherwise you can control it via a GlobalKey.
  final bool autoPlay;

  const StaggeredGroup({
    super.key,
    required this.children,
    this.childDuration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 75),
    this.curve = Curves.easeOutCubic,
    this.type = StaggerAnimationType.slideVertical,
    this.slideOffset = 40.0,
    this.wrapperBuilder,
    this.autoPlay = true,
  });

  @override
  State<StaggeredGroup> createState() => StaggeredGroupState();
}

class StaggeredGroupState extends State<StaggeredGroup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.autoPlay && widget.children.isNotEmpty) {
      _controller.forward();
    }
  }
  
  void _initController() {
    final totalDurationMs = widget.childDuration.inMilliseconds + 
        (widget.staggerDelay.inMilliseconds * (widget.children.isNotEmpty ? widget.children.length - 1 : 0));
    _controller = AnimationController(
      vsync: this, 
      duration: Duration(milliseconds: totalDurationMs),
    );
  }

  @override
  void didUpdateWidget(StaggeredGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != oldWidget.children.length ||
        widget.childDuration != oldWidget.childDuration ||
        widget.staggerDelay != oldWidget.staggerDelay) {
      
      final wasPlaying = _controller.isAnimating;
      final progress = _controller.value;
      
      _controller.dispose();
      _initController();
      
      if (wasPlaying) {
        _controller.forward(from: progress);
      } else if (progress >= 1.0) {
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// Programmatically trigger the animation (useful if autoPlay is false)
  void play() => _controller.forward(from: 0);
  
  /// Reverse the animation
  void reverse() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final totalDurationMs = _controller.duration!.inMilliseconds.toDouble();
    final childDurationMs = widget.childDuration.inMilliseconds.toDouble();
    final staggerMs = widget.staggerDelay.inMilliseconds.toDouble();

    final animatedChildren = List<Widget>.generate(widget.children.length, (index) {
      // Calculate normalized start/end times [0.0 - 1.0] for this specific child
      final startMs = index * staggerMs;
      final endMs = startMs + childDurationMs;
      
      final start = (startMs / totalDurationMs).clamp(0.0, 1.0);
      final end = (endMs / totalDurationMs).clamp(0.0, 1.0);

      final animation = CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: widget.curve),
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) => _buildAnimatedItem(child!, animation),
        child: widget.children[index],
      );
    });

    if (widget.wrapperBuilder != null) {
      return widget.wrapperBuilder!(context, animatedChildren);
    }
    
    // Default fallback wrapper
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: animatedChildren,
    );
  }

  Widget _buildAnimatedItem(Widget child, Animation<double> animation) {
    switch (widget.type) {
      case StaggerAnimationType.slideVertical:
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, widget.slideOffset * (1.0 - animation.value)),
            child: child,
          ),
        );
      case StaggerAnimationType.slideHorizontal:
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(widget.slideOffset * (1.0 - animation.value), 0),
            child: child,
          ),
        );
      case StaggerAnimationType.scale:
        return FadeTransition(
          opacity: animation,
          child: Transform.scale(
            scale: 0.85 + (0.15 * animation.value),
            child: child,
          ),
        );
      case StaggerAnimationType.fade:
        return FadeTransition(
          opacity: animation,
          child: child,
        );
    }
  }
}
