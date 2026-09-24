// ============================================================================
// GlassCard — shared frosted-glass card wrapper used across all dashboard cards
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // BackdropFilter (especially with ImageFilter.blur) causes severe lag on iOS Safari
    // in CanvasKit mode. We fall back to a semi-transparent solid color on iOS web.
    final bool isIOSWeb = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);

    final material = Material(
      color: isIOSWeb ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (isIOSWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: material,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        // A `Material` (not a `Container`/`BoxDecoration`) is the ink surface,
        // so nested ListTiles/ExpansionTiles keep visible ripples instead of
        // tripping the "background color may be invisible" assertion.
        child: material,
      ),
    );
  }
}
