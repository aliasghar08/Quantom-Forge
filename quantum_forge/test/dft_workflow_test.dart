// ============================================================================
// Hybrid UMA → DFT workflow tests
// ----------------------------------------------------------------------------
// Covers the parts that are pure logic and therefore worth pinning: the DFT
// attachment parsing, the comparison threshold, the methods-paragraph template
// and the validation reference table.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/screens/method_validation_screen.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/dft_workflow_card.dart';

/// Shaped from the real POST /reactions/{id}/attach-dft response.
const Map<String, dynamic> _attachResponse = {
  'attachment_id': '74561ab5-4e51-4c58-9eda-f4e2b7d4911e',
  'level_of_theory': 'wB97X-D3/def2-TZVP',
  'ts_energy_hartree': -1538.0,
  'reactant_energy_hartree': -1538.06,
  'imaginary_frequency_cm1': -1180.0,
  'notes': 'ORCA 5.0.4, tight SCF',
  'log_file_name': null,
  'log_file_text': null,
  'attached_at': '2026-09-20T05:54:49+00:00',
  'barrier_kcal_mol': 37.6506,
};

void main() {
  group('DFT attachments', () {
    test('parses the attach-dft response', () {
      final a = DftAttachment.fromJson(_attachResponse);
      expect(a.attachmentId, isNotEmpty);
      expect(a.levelOfTheory, 'wB97X-D3/def2-TZVP');
      expect(a.barrierKcalMol, closeTo(37.6506, 1e-6));
      expect(a.imaginaryFrequencyCm1, -1180.0);
      expect(a.hasBarrier, isTrue);
      expect(a.displayLevel, 'wB97X-D3/def2-TZVP');
    });

    test('a barrier needs both energies, and blanks are labelled', () {
      final partial = DftAttachment.fromJson({
        'attachment_id': 'x',
        'ts_energy_hartree': -1538.0,
      });
      // The backend only derives a barrier when both energies are present.
      expect(partial.hasBarrier, isFalse);
      expect(partial.displayLevel, 'DFT (level not stated)');
    });

    test('status parses the attached list, empty by default', () {
      final withNone = ReactionStatusResponse.fromJson({
        'reaction_id': 'r', 'state': 'completed', 'progress': 1.0,
      });
      expect(withNone.dftAttachments, isEmpty);

      final withOne = ReactionStatusResponse.fromJson({
        'reaction_id': 'r', 'state': 'completed', 'progress': 1.0,
        'dft_attachments': [_attachResponse],
      });
      expect(withOne.dftAttachments, hasLength(1));
      expect(withOne.dftAttachments.first.barrierKcalMol, closeTo(37.6506, 1e-6));
    });
  });

  group('comparison threshold', () {
    test('5 kcal/mol is the reliability cut-off', () {
      expect(kUmaReliableDeltaKcal, 5.0);
    });
  });

  group('methods paragraph', () {
    test('attributes screening to the MLIP, not to a DFT level', () {
      final p = buildMethodsParagraph(
        model: 'UMA-SM',
        method: 'ωB97X-D/def2-TZVP',
        solvent: 'Dichloromethane',
      );

      // The correction this test exists for: the DFT level belongs to the
      // refinement, and the screening is attributed to the MLIP alone.
      expect(p, startsWith('Screening was performed with the UMA-SM '
          'machine-learned interatomic potential.'));
      expect(p, contains('Transition state geometries were refined at the '
          'ωB97X-D/def2-TZVP level of theory.'));
      expect(p, contains('Implicit solvation was modeled with SMD '
          '(Dichloromethane).'));

      // The old, wrong wording must be gone.
      expect(p.contains('UMA-MLIP screening used'), isFalse);
    });

    test('includes the single-point sentence when one is supplied', () {
      final p = buildMethodsParagraph(
        model: 'UMA-SM',
        method: 'ωB97X-D/def2-TZVP',
        solvent: 'Vacuum',
        singlePointMethod: 'DLPNO-CCSD(T)/def2-QZVP',
      );
      expect(p, contains('Single-point energies were computed at '
          'DLPNO-CCSD(T)/def2-QZVP.'));
      expect(p, contains('refined at the ωB97X-D/def2-TZVP level'));
    });

    test('OMITS the sentence when no single-point level is given', () {
      // The rule: an absent value produces an absent sentence, never one that
      // silently reuses the geometry level.
      final omitted = buildMethodsParagraph(
        model: 'UMA-SM',
        method: 'ωB97X-D/def2-TZVP',
        solvent: 'Vacuum',
      );
      expect(omitted.contains('Single-point energies'), isFalse);
      expect(omitted, endsWith('level of theory.'));

      // Whitespace is not a value either.
      final blank = buildMethodsParagraph(
        model: 'UMA-SM',
        method: 'ωB97X-D/def2-TZVP',
        solvent: 'Vacuum',
        singlePointMethod: '   ',
      );
      expect(blank.contains('Single-point energies'), isFalse);
    });

    test('no placeholder survives, with or without a single-point level', () {
      const placeholders = ['{model}', '{method}', '{solvent}',
                            '{solvation_clause}', '{single_point_method}'];
      final variants = [
        buildMethodsParagraph(model: 'UMA-SM', method: 'M', solvent: 'Water'),
        buildMethodsParagraph(
            model: 'UMA-SM', method: 'M', solvent: 'Water',
            singlePointMethod: 'SP'),
        buildMethodsParagraph(model: 'UMA-SM', method: '', solvent: 'Vacuum'),
      ];
      for (final p in variants) {
        for (final ph in placeholders) {
          expect(p.contains(ph), isFalse, reason: '$ph in: $p');
        }
      }
    });

    test('omits the solvation clause when there is no solvent', () {
      final vacuum = buildMethodsParagraph(
          model: 'UMA-SM', method: 'B3LYP/6-31G*', solvent: 'Vacuum');
      expect(vacuum.contains('Implicit solvation'), isFalse);

      final blank = buildMethodsParagraph(
          model: 'UMA-SM', method: 'B3LYP/6-31G*', solvent: '   ');
      expect(blank.contains('Implicit solvation'), isFalse);
    });

    test('falls back to an obvious marker when the level is blank', () {
      final p = buildMethodsParagraph(model: 'UMA-SM', method: '', solvent: 'Vacuum');
      expect(p, contains('<DFT level of theory>'));
    });
  });

  group('validation references', () {
    test('five references, each with a literature barrier and a source', () {
      expect(kValidationReferences, hasLength(5));
      for (final r in kValidationReferences) {
        expect(r.literatureEa, greaterThan(0), reason: r.name);
        expect(r.source.trim(), isNotEmpty, reason: r.name);
        expect(r.reactantXyz.trim(), isNotEmpty, reason: r.name);
        expect(r.productXyz.trim(), isNotEmpty, reason: r.name);
      }
    });

    test('reactant and product keep a consistent atom count and order', () {
      // DMF's FB-ENM matches atoms by index, so a reordered product would compare
      // the wrong atoms and the "validation" would be meaningless.
      List<String> elements(String xyz) {
        final lines = xyz.trim().split('\n');
        final n = int.parse(lines.first.trim());
        final out = <String>[];
        for (var i = 2; i < lines.length && out.length < n; i++) {
          final t = lines[i].trim();
          if (t.isEmpty) continue;
          out.add(t.split(RegExp(r'\s+')).first);
        }
        return out;
      }

      for (final r in kValidationReferences) {
        final a = elements(r.reactantXyz);
        final b = elements(r.productXyz);
        expect(b, a, reason: '${r.name}: element order drifted');
      }
    });

    test('covers the reaction types the request named', () {
      final names = kValidationReferences.map((r) => r.name.toLowerCase()).join(' | ');
      expect(names, contains('hcn'));
      expect(names, contains('nh3'));
      expect(names, contains('sn2'));
    });
  });
}
