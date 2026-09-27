// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationBondEnergiesExt on _ReactionAnimationWidgetState {
  Widget _buildBondEnergiesPanel() {
      final atoms = _atomsAt(_frame);
      if (atoms.isEmpty) return const SizedBox.shrink();

      final bonds = <_CalculatedBond>[];
      int bondIdx = 1;
      final perceivedBonds = _bondsForCurrentFrame();

      for (int b = 0; b < perceivedBonds.length; b++) {
        final bond = perceivedBonds[b];
        final a1 = atoms[bond.a], a2 = atoms[bond.b];
        final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final idealDist = a1.covalentRadius + a2.covalentRadius;
        bonds.add(_CalculatedBond(a1, a2, dist, idealDist, bondIdx++));
      }

      if (bonds.isEmpty) return const SizedBox.shrink();

      // Use context.read to avoid subscribing the animation widget to every
      // QuantumSettingsNotifier change — the parent already rebuilds us when
      // settings that affect the energy profile change, so a second
      // subscription here would cause a redundant rebuild of the whole subtree.
      final settings = context.read<QuantumSettingsNotifier>().value;

      double scaleFactor = (settings.temperatureK / 300.0);
      if (settings.solventModel != 'Vacuum') {
        scaleFactor *= 0.85;
      }
      if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
      final chargeShift = settings.charge * 1.5;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bond Energies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: bonds.map((b) {
                final energy =
                    100 * math.exp(-2.0 * (b.dist - b.idealDist)) * scaleFactor +
                    chargeShift;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${b.index}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${b.a1.symbol}–${b.a2.symbol}: '
                      '${energy.toStringAsFixed(1)} kcal·mol⁻¹',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

}
