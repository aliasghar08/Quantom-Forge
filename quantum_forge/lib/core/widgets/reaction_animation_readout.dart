// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationReadoutExt on _ReactionAnimationWidgetState {
  Widget _buildReadout() {
      final energy = _energyAtFrame;
      final absolute = _absoluteEnergyAtFrame;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.25),
            ),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _infoItem('Frame', '${_frame + 1} / $_frameCount'),
              if (energy != null)
                _infoItem('Energy', '${energy.toStringAsFixed(2)} kcal·mol⁻¹'),
              if (absolute != null)
                _infoItem('MLIP E', '${absolute.toStringAsFixed(4)} eV'),
              _infoItem('Progress', '${_progressPercent.toStringAsFixed(1)}%'),
              _infoItem('Status', _playing ? 'Playing' : 'Stopped'),
              _infoItem('Speed', '$_effectiveFrameRate FPS'),
              _infoItem('Cycle', '${_cycleSeconds.toStringAsFixed(1)} s'),
              _infoItem('Loop', _loopMode.name),
              _infoItem(
                'TS frame',
                '${_transitionStateFrame + 1} / $_frameCount',
              ),
              _infoItem('Bonds', '${_bondsForCurrentFrame().length}'),
            ],
          ),
        ),
      );
    }

  Widget _infoItem(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

  List<PerceivedBond> _bondsForCurrentFrame() {
      if (!_dynamicBonding) return _staticBonds;
      final atoms = _atomsAt(_frame);
      if (atoms.isEmpty) return const <PerceivedBond>[];
      return AvogadroBondPerception.perceive(atoms);
    }

}
