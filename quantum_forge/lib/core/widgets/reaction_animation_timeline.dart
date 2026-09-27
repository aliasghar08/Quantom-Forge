// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationTimelineExt on _ReactionAnimationWidgetState {
  Widget _buildTimeline() {
      final segments = [
        ('Approach', 0.0, _ReactionAnimationWidgetState._t1, const Color(0xFF4FC3F7)),
        ('Transition State', _ReactionAnimationWidgetState._t1, _ReactionAnimationWidgetState._t2, const Color(0xFFFFAB40)),
        ('Separation', _ReactionAnimationWidgetState._t2, _ReactionAnimationWidgetState._t3, const Color(0xFF80DEEA)),
        ('Products', _ReactionAnimationWidgetState._t3, 1.0, const Color(0xFF66BB6A)),
      ];
      final t = _pathT;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Row(
          children: segments.map((segment) {
            final (label, start, end, color) = segment;
            final isActive = t >= start && t < end;
            final isDone = t >= end;
            final segT = isActive
                ? (t - start) / (end - start)
                : (isDone ? 1.0 : 0.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? color
                            : Colors.white.withValues(alpha: 0.25),
                        fontSize: 9,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: segT,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(
                          color.withValues(alpha: isActive ? 1.0 : 0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

}
