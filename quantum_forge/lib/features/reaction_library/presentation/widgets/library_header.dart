import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Animated number display for the library header.
///
/// Counts up from [from] to [to] over [duration] using an ease-out curve so
/// it feels snappy at the start and settles gently — same technique used by
/// dashboard analytics cards.
class _AnimatedCount extends StatefulWidget {
  final int from;
  final int to;
  final Duration duration;
  final TextStyle style;

  const _AnimatedCount({
    required this.from,
    required this.to,
    required this.duration,
    required this.style,
  });

  @override
  State<_AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<_AnimatedCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCount old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final value =
            (widget.from + (widget.to - widget.from) * _anim.value).round();
        return Text(_formatCount(value), style: widget.style);
      },
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      // e.g. 200,000 → "200K" or 12,345 → "12.3K"
      final k = n / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class LibraryHeader extends StatelessWidget {
  /// Number of templates currently loaded locally (always ≥ 0).
  final int localCount;

  /// Total templates stored in Firestore. Null = still loading, -1 = unavailable.
  final int? cloudCount;

  final ValueChanged<String> onSearchChanged;

  const LibraryHeader({
    super.key,
    required this.localCount,
    this.cloudCount,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 4),
                _buildCountRow(context),
              ],
            ),
          ),
          // Search field
          Container(
            width: 320,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (!(kIsWeb && defaultTargetPlatform == TargetPlatform.iOS))
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: _buildTextField(),
                    )
                  : _buildTextField(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(BuildContext context) {
    final subtitleStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.5),
      fontSize: 13,
    );
    final accentStyle = TextStyle(
      color: Colors.cyanAccent.withValues(alpha: 0.85),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    // Cloud count badge
    Widget cloudBadge;
    if (cloudCount == null) {
      // Loading — pulsing shimmer pill
      cloudBadge = _ShimmerPill();
    } else if (cloudCount == -1 || cloudCount == 0) {
      // Unavailable or zero — show local count only
      cloudBadge = Text('local only', style: subtitleStyle);
    } else {
      cloudBadge = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_done_rounded,
            size: 13, color: Colors.cyanAccent.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        _AnimatedCount(
          from: 0,
          to: cloudCount!,
          duration: const Duration(milliseconds: 1200),
          style: accentStyle,
        ),
        Text(' in cloud', style: subtitleStyle),
      ]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedCount(
          from: 0,
          to: localCount,
          duration: const Duration(milliseconds: 900),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(' systematic variants  •  ', style: subtitleStyle),
        cloudBadge,
      ],
    );
  }

  Widget _buildTextField() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search reactions, tags...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.search,
            color: Colors.white.withValues(alpha: 0.4), size: 20),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

/// Tiny pulsing shimmer pill shown while the cloud count is loading.
class _ShimmerPill extends StatefulWidget {
  @override
  State<_ShimmerPill> createState() => _ShimmerPillState();
}

class _ShimmerPillState extends State<_ShimmerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        width: 72,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: Colors.white.withValues(alpha: 0.08 + 0.08 * _ctrl.value),
        ),
      ),
    );
  }
}
