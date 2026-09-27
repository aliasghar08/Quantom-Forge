// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'reaction_provider.dart';

extension ReactionProviderGuestExt on ReactionNotifier {
  // --- Local (guest) simulation — no Firestore, no history ------------------
  /// Runs the whole workflow in memory for unauthenticated users, updating the
  /// notifier directly. Nothing is persisted, so "history" remains a signed-in
  /// feature while the app itself stays fully usable without an account.
  Future<void> _simulateGuestReaction(String reactantXyz, String productXyz) async {
    final reactionId = 'guest-${UuidUtil.v4()}';

    void emit(ReactionState state, double progress, String message) {
      value = ReactionStatusResponse(
        reactionId: reactionId,
        state: state,
        progress: progress,
        message: message,
      );
      notifyListeners();
    }

    emit(ReactionState.pending, 0.0, 'Queued (local session)…');
    await Future.delayed(const Duration(seconds: 1));
    emit(ReactionState.optimizing, 0.1, 'Initializing TS Search (NEB)…');
    for (int i = 2; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      emit(ReactionState.optimizing, i / 10.0, 'Optimizing geometry… (Cycle $i)');
    }
    await Future.delayed(const Duration(seconds: 1));

    // Mock energy profile (Gaussian barrier).
    final energyProfile = List<double>.generate(21, (i) {
      final x = (i - 10) / 5.0;
      return 25.0 * math.exp(-x * x / 2);
    });

    // Mock trajectory frames via symbol-matched interpolation.
    List<String> trajectoryFrames;
    try {
      final rAtoms = MoleculeParser.parse(reactantXyz, 'xyz');
      final pAtoms = MoleculeParser.parse(productXyz, 'xyz');
      if (rAtoms.isEmpty || pAtoms.isEmpty) throw Exception('Empty xyz');

      final rGroups = <String, List<Atom>>{};
      final pGroups = <String, List<Atom>>{};
      for (final a in rAtoms) {
        rGroups.putIfAbsent(a.symbol, () => []).add(a);
      }
      for (final a in pAtoms) {
        pGroups.putIfAbsent(a.symbol, () => []).add(a);
      }

      trajectoryFrames = <String>[];
      for (int frame = 0; frame < 21; frame++) {
        final t = frame / 20.0;
        final frameAtoms = <Atom>[];
        for (final sym in {...rGroups.keys, ...pGroups.keys}) {
          final rList = rGroups[sym] ?? const <Atom>[];
          final pList = pGroups[sym] ?? const <Atom>[];
          final maxLen = math.max(rList.length, pList.length);
          for (int i = 0; i < maxLen; i++) {
            if (i < rList.length && i < pList.length) {
              final a1 = rList[i], a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x + (a2.x - a1.x) * t,
                a1.y + (a2.y - a1.y) * t,
                a1.z + (a2.z - a1.z) * t,
                a1.color, a1.radius, a1.covalentRadius,
              ));
            } else if (i < rList.length) {
              frameAtoms.add(rList[i]);
            } else {
              frameAtoms.add(pList[i]);
            }
          }
        }
        final sb = StringBuffer()
          ..writeln('${frameAtoms.length}')
          ..writeln('Frame $frame (t=$t)');
        for (final a in frameAtoms) {
          sb.writeln('${a.symbol.padRight(2)} '
              '${a.x.toStringAsFixed(4).padLeft(8)} '
              '${a.y.toStringAsFixed(4).padLeft(8)} '
              '${a.z.toStringAsFixed(4).padLeft(8)}');
        }
        trajectoryFrames.add(sb.toString());
      }
    } catch (_) {
      trajectoryFrames =
          List.generate(21, (i) => i < 10 ? reactantXyz : productXyz);
    }

    value = ReactionStatusResponse(
      reactionId: reactionId,
      state: ReactionState.completed,
      progress: 1.0,
      message: 'TS Search Converged Successfully (local session).',
      energyProfile: energyProfile,
      trajectoryFrames: trajectoryFrames,
    );
    _isLoading = false;
    notifyListeners();
  }

}
