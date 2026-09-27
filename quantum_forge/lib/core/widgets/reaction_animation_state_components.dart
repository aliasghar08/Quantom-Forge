// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationComponentsExt on _ReactionAnimationWidgetState {
  Widget _loopChip(AnimationLoopMode mode) {
    final active = _loopMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _claimKeyboard();
        _setLoopMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF4FC3F7).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          mode.name,
          style: TextStyle(
            color: active ? const Color(0xFF4FC3F7) : Colors.white54,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    Key? key,
  }) {
    Widget child = InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return child;
  }

  
}

class _CalculatedBond {
  final Atom a1, a2;
  final double dist, idealDist;
  final int index;
  _CalculatedBond(this.a1, this.a2, this.dist, this.idealDist, this.index);
}
