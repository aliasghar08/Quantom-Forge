// ============================================================================
// UMA data pass-through tests
// ----------------------------------------------------------------------------
// The backend has always returned `energy_profile_ev` and `max_energy_index`, and
// both were silently discarded by the app. These tests pin the full payload —
// shaped from a real response captured off the live Space — so a field cannot go
// missing again without a failure.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';

/// Trimmed from the live NH3 inversion response.
const Map<String, dynamic> _liveResponse = {
  'reaction_id': '3a3b87ba-c6c6-4cf4-af20-65a391a92966',
  'state': 'completed',
  'progress': 1.0,
  'message': 'DMF/UMA optimisation converged.',
  'energy_profile': [0.0, 4.428865490335738, 4.428873191813182],
  'energy_profile_ev': [-1538.8092588, -1538.6172046, -1538.6172042],
  'trajectory_frames': [
    '2\n\nH 0.0 0.0 0.0\nH 0.0 0.0 0.74\n',
    '2\n\nH 0.0 0.0 0.1\nH 0.0 0.0 0.84\n',
    '2\n\nH 0.0 0.0 0.2\nH 0.0 0.0 0.94\n',
  ],
  'max_energy_index': 2,
  'vibrational_modes': [
    {'frequency': -794.03, 'vectors': []},
    {'frequency': -166.38, 'vectors': []},
  ],
  'error': null,
};

void main() {
  test('parses every field the UMA backend returns', () {
    final status = ReactionStatusResponse.fromJson(_liveResponse);

    expect(status.reactionId, isNotEmpty);
    expect(status.state, ReactionState.completed);
    expect(status.energyProfile, hasLength(3));
    expect(status.trajectoryFrames, hasLength(3));
    expect(status.vibrationalModes, hasLength(2));
    expect(status.error, isNull);

    // The two fields that used to be dropped.
    expect(status.maxEnergyIndex, 2);
    expect(status.energyProfileEv, isNotNull);
    expect(status.energyProfileEv, hasLength(3));
    expect(status.energyProfileEv!.first, closeTo(-1538.8092588, 1e-9));

    // Absolute and relative profiles must stay aligned — they are indexed together.
    expect(status.energyProfileEv!.length, status.energyProfile!.length);

    // The imaginary frequency survives with its sign.
    expect(status.vibrationalModes!.first.frequency, -794.03);
    expect(status.vibrationalModes!.first.frequency, lessThan(0));
  });

  test('keeps the backend failure reason separate from the generic message', () {
    final status = ReactionStatusResponse.fromJson({
      'reaction_id': 'failed-run',
      'state': 'error',
      'progress': 1.0,
      'message': 'DMF/UMA optimisation failed.',
      'error': 'ase.io.extxyz: Frame has 1 atoms, expected 2',
      'energy_profile': null,
      'energy_profile_ev': null,
      'trajectory_frames': null,
      'vibrational_modes': null,
      'max_energy_index': null,
    });

    expect(status.state, ReactionState.error);
    expect(status.message, 'DMF/UMA optimisation failed.');
    // Previously merged into `message`, so the generic line shadowed this.
    expect(status.error, 'ase.io.extxyz: Frame has 1 atoms, expected 2');
  });

  testWidgets('displays the model absolute energy in the frame readout',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final status = ReactionStatusResponse.fromJson(_liveResponse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReactionAnimationWidget(
              trajectoryFrames: status.trajectoryFrames!,
              energyProfile: status.energyProfile,
              energyProfileEv: status.energyProfileEv,
              maxEnergyIndex: status.maxEnergyIndex,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Frame 0 absolute energy, straight from the model, formatted at 4 dp.
    expect(find.text('UMA E: '), findsOneWidget);
    expect(find.text('-1538.8093 eV'), findsOneWidget);

    // The relative energy for the same frame is also shown.
    expect(find.text('0.00 kcal·mol⁻¹'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
