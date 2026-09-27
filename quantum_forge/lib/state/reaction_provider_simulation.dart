// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'reaction_provider.dart';

extension ReactionProviderSimulationExt on ReactionNotifier {
  // --- Simulation logic for testing UI without backend ---
  Future<void> _simulateReactionProcessing(String reactionId, String reactantXyz, String productXyz) async {
    // 1. Pending -> Optimizing
    await Future.delayed(const Duration(seconds: 1));
    await _repo.updateReaction(reactionId, {
      'state': ReactionState.optimizing.name,
      'message': 'Initializing TS Search (NEB)...',
      'progress': 0.1,
    });

    // 2. Loop and update progress
    for (int i = 2; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      await _repo.updateReaction(reactionId, {
        'message': 'Optimizing geometry... (Cycle $i)',
        'progress': i / 10.0,
      });
    }

    // 3. Complete and generate mock data
    await Future.delayed(const Duration(seconds: 1));
    
    // Generate mock energy profile based on a bell curve
    List<double> energyProfile = [];
    for (int i = 0; i < 21; i++) {
      double x = (i - 10) / 5.0; // -2 to 2
      double y = 25.0 * math.exp(-x * x / 2); // Gaussian curve up to ~25 kcal·mol⁻¹
      energyProfile.add(y);
    }

    // Generate mock trajectory frames (smart interpolation)
    List<String> trajectoryFrames = [];
    try {
      final rAtoms = MoleculeParser.parse(reactantXyz, 'xyz');
      final pAtoms = MoleculeParser.parse(productXyz, 'xyz');
      
      if (rAtoms.isEmpty || pAtoms.isEmpty) {
        throw Exception("Empty xyz");
      }

      // Group by symbol to pair them up
      Map<String, List<Atom>> rGroups = {};
      Map<String, List<Atom>> pGroups = {};
      
      for (var a in rAtoms) {
        rGroups.putIfAbsent(a.symbol, () => []).add(a);
      }
      for (var a in pAtoms) {
        pGroups.putIfAbsent(a.symbol, () => []).add(a);
      }

      for (int frame = 0; frame < 21; frame++) {
        double t = frame / 20.0;
        List<Atom> frameAtoms = [];
        
        // Match symbols
        Set<String> allSymbols = {...rGroups.keys, ...pGroups.keys};
        for (var sym in allSymbols) {
          var rList = rGroups[sym] ?? [];
          var pList = pGroups[sym] ?? [];
          int maxLen = math.max(rList.length, pList.length);
          
          for (int i = 0; i < maxLen; i++) {
            if (i < rList.length && i < pList.length) {
              // Interpolate
              var a1 = rList[i];
              var a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x + (a2.x - a1.x) * t,
                a1.y + (a2.y - a1.y) * t,
                a1.z + (a2.z - a1.z) * t,
                a1.color,
                a1.radius,
                a1.covalentRadius,
              ));
            } else if (i < rList.length) {
              // Only in reactant - stays at its original position
              var a1 = rList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x,
                a1.y,
                a1.z,
                a1.color,
                a1.radius,
                a1.covalentRadius,
              ));
            } else if (i < pList.length) {
              // Only in product - stays at its original position
              var a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a2.x,
                a2.y,
                a2.z,
                a2.color,
                a2.radius,
                a2.covalentRadius,
              ));
            }
          }
        }
        
        StringBuffer sb = StringBuffer();
        sb.writeln('${frameAtoms.length}');
        sb.writeln('Frame $frame (t=$t)');
        for (var a in frameAtoms) {
          sb.writeln('${a.symbol.padRight(2)} ${a.x.toStringAsFixed(4).padLeft(8)} ${a.y.toStringAsFixed(4).padLeft(8)} ${a.z.toStringAsFixed(4).padLeft(8)}');
        }
        trajectoryFrames.add(sb.toString());
      }
    } catch (e) {
      // Fallback if parsing fails entirely
      trajectoryFrames = List.generate(21, (index) {
        return index < 10 ? reactantXyz : productXyz;
      });
    }

    await _repo.updateReaction(reactionId, {
      'state': ReactionState.completed.name,
      'message': 'TS Search Converged Successfully.',
      'progress': 1.0,
      'energy_profile': energyProfile,
      'trajectory_frames': trajectoryFrames,
    });
  }

}
