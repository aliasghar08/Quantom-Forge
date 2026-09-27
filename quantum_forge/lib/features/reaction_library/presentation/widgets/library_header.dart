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
  final VoidCallback? onRefreshCount;

  const LibraryHeader({
    super.key,
    required this.localCount,
    this.cloudCount,
    required this.onSearchChanged,
    this.onRefreshCount,
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
          _buildStatCard(),
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

    // Cloud count handled directly in the return widget below

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Showing ', style: subtitleStyle),
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
        Text(' of ', style: subtitleStyle),
        if (cloudCount != null && cloudCount! > 0) ...[
          _AnimatedCount(
            from: 0,
            to: cloudCount!,
            duration: const Duration(milliseconds: 1200),
            style: accentStyle,
          ),
          Text(' reactions from Firebase', style: subtitleStyle),
        ] else if (cloudCount == null)
          _ShimmerPill()
        else
          Text('? reactions from Firebase', style: subtitleStyle),
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

  Widget _buildStatCard() {
    Widget content;
    if (cloudCount == null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ShimmerPill(width: 80, height: 32),
          const SizedBox(height: 4),
          Text('total reactions in Firebase', style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 11)),
        ],
      );
    } else if (cloudCount == -1) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('—', style: TextStyle(color: Colors.white70, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('total reactions in Firebase', style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 11)),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedCount(
            from: 0,
            to: cloudCount!,
            duration: const Duration(milliseconds: 1200),
            style: TextStyle(
              color: Colors.cyanAccent.withValues(alpha: 0.9),
              fontSize: 32,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.cyanAccent.withValues(alpha: 0.5), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('total reactions in Firebase', style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 11)),
        ],
      );
    }

    return MouseRegion(
      cursor: onRefreshCount != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onRefreshCount,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Tiny pulsing shimmer pill shown while the cloud count is loading.
class _ShimmerPill extends StatefulWidget {
  final double width;
  final double height;
  
  const _ShimmerPill({this.width = 72, this.height = 14});

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
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: Colors.white.withValues(alpha: 0.08 + 0.08 * _ctrl.value),
        ),
      ),
    );
  }
}
