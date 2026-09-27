import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A completely from-scratch implementation of a Glassmorphism container.
/// It applies a frosted glass blur to whatever is behind it, with customizable
/// highlights, borders, and shadows to create a premium depth effect.
class GlassContainer extends StatelessWidget {
  final Widget? child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final DecorationImage? image;
  final Gradient? gradient;
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    this.child,
    this.blur = 12.0,
    this.opacity = 0.10,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShadow,
    this.image,
    this.gradient,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16.0);
    // Default to white for the glass tint unless another is specified
    final themeColor = color ?? Colors.white;
    
    // Default glassy border provides a subtle edge highlight to distinguish it from the background
    final effectiveBorder = border ?? Border.all(
      color: themeColor.withValues(alpha: 0.25),
      width: 1.2,
    );

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: opacity),
              borderRadius: effectiveRadius,
              border: effectiveBorder,
              image: image,
              // Optional subtle gradient over the glass to give a lighting effect
              gradient: gradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColor.withValues(alpha: opacity + 0.05),
                  themeColor.withValues(alpha: opacity),
                  themeColor.withValues(alpha: math.max(0, opacity - 0.05)),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
