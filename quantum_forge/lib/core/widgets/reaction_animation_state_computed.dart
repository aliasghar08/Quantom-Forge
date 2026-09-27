// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationComputedExt on _ReactionAnimationWidgetState {
  // ── Readout values ────────────────────────────────────────────────────────

  double? get _energyAtFrame {
    final profile = widget.energyProfile;
    if (profile == null || profile.isEmpty) return null;
    return profile[_frame.clamp(0, profile.length - 1)];
  }

  double? get _absoluteEnergyAtFrame {
    final profile = widget.energyProfileEv;
    if (profile == null || profile.isEmpty) return null;
    return profile[_frame.clamp(0, profile.length - 1)];
  }

  double get _progressPercent => _pathT * 100.0;

  double get _cycleSeconds => _span / _effectiveFrameRate;

  String get _phaseName {
    final t = _pathT;
    if (t < _ReactionAnimationWidgetState._t1) return 'Approach';
    if (t < _ReactionAnimationWidgetState._t2) return 'Transition State';
    if (t < _ReactionAnimationWidgetState._t3) return 'Separation';
    return 'Products';
  }

  Color get _phaseColor {
    final t = _pathT;
    if (t < _ReactionAnimationWidgetState._t1) return const Color(0xFF4FC3F7);
    if (t < _ReactionAnimationWidgetState._t2) return const Color(0xFFFFAB40);
    if (t < _ReactionAnimationWidgetState._t3) return const Color(0xFF80DEEA);
    return const Color(0xFF66BB6A);
  }

  double get _phaseProgress {
    final t = _pathT;
    if (t < _ReactionAnimationWidgetState._t1) return _ReactionAnimationWidgetState._t1 == 0 ? 1 : t / _ReactionAnimationWidgetState._t1;
    if (t < _ReactionAnimationWidgetState._t2) return (t - _ReactionAnimationWidgetState._t1) / (_ReactionAnimationWidgetState._t2 - _ReactionAnimationWidgetState._t1);
    if (t < _ReactionAnimationWidgetState._t3) return (t - _ReactionAnimationWidgetState._t2) / (_ReactionAnimationWidgetState._t3 - _ReactionAnimationWidgetState._t2);
    return _ReactionAnimationWidgetState._t3 >= 1 ? 1 : (t - _ReactionAnimationWidgetState._t3) / (1.0 - _ReactionAnimationWidgetState._t3);
  }

  IconData get _phaseIcon {
    final t = _pathT;
    if (t < _ReactionAnimationWidgetState._t1) return Icons.arrow_right_alt;
    if (t < _ReactionAnimationWidgetState._t2) return Icons.bolt;
    if (t < _ReactionAnimationWidgetState._t3) return Icons.call_split;
    return Icons.check_circle_outline;
  }

}
