// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationBondEnergiesExt on _ReactionAnimationWidgetState {
  Widget _buildBondEnergiesPanel() {
    // ── Atoms and bonds must come from the same frame ───────────────────────
    //
    // When `_dynamicBonding` is false, `_staticBonds` were perceived once from
    // frame 0 at load time. Those bonds hold indices into frame 0's atom list.
    // The previous version paired them with the *current* frame's atoms, which
    // is only valid when every frame has the same atom count. Any reaction
    // that gains or loses an atom — a condensation that releases water, a
    // dissociation that produces two fragments — produces a RangeError on the
    // first frame with a shorter atom list, which throws out of build, drops
    // the subtree, and tears down the NGL platform view.
    //
    // The fix pairs each bond set with the atom list it was perceived against:
    // frame 0 for the static path, the current frame for the dynamic path.
    final List<Atom> atoms;
    final List<PerceivedBond> perceivedBonds;

    if (_dynamicBonding) {
      atoms = _atomsAt(_frame);
      perceivedBonds = atoms.isEmpty
          ? const <PerceivedBond>[]
          : AvogadroBondPerception.perceive(atoms);
    } else {
      atoms = _atomsAt(0);
      perceivedBonds = _staticBonds;
    }

    if (atoms.isEmpty || perceivedBonds.isEmpty) {
      return const SizedBox.shrink();
    }

    final bonds = <_CalculatedBond>[];
    int bondIdx = 1;

    for (final bond in perceivedBonds) {
      // ── Defensive bounds check ────────────────────────────────────────────
      //
      // Even with the frame alignment above, a stale bond set can survive a
      // trajectory swap or a mid-load frame. Skipping a bad bond is strictly
      // better than throwing out of build, because a build-time throw on web
      // drops the whole subtree — including the WebGL platform view — and
      // re-creating it is what produces the "appears, disappears, appears"
      // flicker.
      if (bond.a < 0 || bond.a >= atoms.length) continue;
      if (bond.b < 0 || bond.b >= atoms.length) continue;

      final a1 = atoms[bond.a];
      final a2 = atoms[bond.b];
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