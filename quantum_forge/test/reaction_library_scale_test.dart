// ============================================================================
// Reaction library scale + laziness tests
// ----------------------------------------------------------------------------
// Guards the two things that make a many-thousand-entry library usable:
//   1. the generated variants are structurally valid and never claim a citation;
//   2. the grid builds only what is on screen.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_template_generator.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/library_grid.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/reaction_card_widget.dart';

/// Element symbols in the order they appear, as declared by the XYZ header.
List<String> _xyzElements(String xyz) {
  final lines = xyz.split('\n');
  final declared = int.parse(lines.first.trim());
  final out = <String>[];
  for (var i = 2; i < lines.length && out.length < declared; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    out.add(line.split(RegExp(r'\s+')).first);
  }
  return out;
}

int _xyzCount(String xyz) => int.parse(xyz.split('\n').first.trim());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('generated template library', () {
    late List<ReactionTemplate> all;
    late List<ReactionTemplate> derived;

    setUpAll(() {
      final sw = Stopwatch()..start();
      all = buildFullTemplateLibrary(kReactionTemplates);
      sw.stop();
      derived = all.where((t) => t.isDerived).toList();
      debugPrint(
        'library=${all.length} curated=${kReactionTemplates.length} '
        'generated=${derived.length} built in ${sw.elapsedMilliseconds}ms',
      );
    });

    test('reaches thousands of entries', () {
      expect(all.length, greaterThanOrEqualTo(1000));
      expect(derived.length, greaterThanOrEqualTo(1000));
    });

    test('curated entries are untouched and still cited', () {
      for (final t in kReactionTemplates) {
        expect(t.isDerived, isFalse, reason: t.id);
      }
      // At least the majority of curated milestones carry a journal reference.
      final cited = kReactionTemplates.where((t) => t.journalRef.isNotEmpty);
      expect(cited.length, greaterThan(kReactionTemplates.length ~/ 2));
    });

    test('derived entries never claim a citation', () {
      for (final t in derived) {
        expect(t.doi, isEmpty, reason: '${t.id} must not carry a DOI');
        expect(t.derivedFrom, isNotNull, reason: t.id);
        expect(t.journalRef.startsWith('Derived from:'), isTrue, reason: t.id);
        // The description must say so, so nobody mistakes it for measured data.
        expect(t.description.contains('[Derived variant]'), isTrue, reason: t.id);
      }
    });

    test('derived geometries stay internally consistent', () {
      for (final t in derived) {
        final rCount = _xyzCount(t.reactantXyz);
        final pCount = _xyzCount(t.productXyz);

        // The XYZ header must match the number of atom lines actually written.
        expect(_xyzElements(t.reactantXyz).length, rCount, reason: t.id);
        expect(_xyzElements(t.productXyz).length, pCount, reason: t.id);

        // Reactant and product must keep the same atom ordering, otherwise the
        // DMF path search compares different atoms.
        expect(pCount, rCount, reason: '${t.id} atom count drifted');
        expect(_xyzElements(t.productXyz), _xyzElements(t.reactantXyz),
            reason: '${t.id} element order drifted');
      }
    });

    test('substitution actually changes the composition', () {
      // Every variant must differ from its parent - a no-op derivation would
      // silently duplicate entries.
      final parentByName = {for (final t in kReactionTemplates) t.name: t};
      for (final t in derived.take(200)) {
        final parent = parentByName[t.derivedFrom];
        expect(parent, isNotNull, reason: '${t.id} has no parent');
        expect(t.reactantXyz == parent!.reactantXyz, isFalse,
            reason: '${t.id} geometry identical to parent');
        expect(t.id == parent.id, isFalse);
      }
    });

    test('ids are unique', () {
      final ids = all.map((t) => t.id).toSet();
      expect(ids.length, all.length);
    });
  });

  group('LibraryGrid laziness', () {
    /// The laziness guarantee is about the GRID, not the current library size, so
    /// build a synthetic 3000-entry list with unique keys.
    List<ReactionTemplate> synthetic(int count) {
      final base = buildFullTemplateLibrary(kReactionTemplates);
      return List<ReactionTemplate>.generate(count, (i) {
        final t = base[i % base.length];
        return ReactionTemplate(
          id: '${t.id}#$i',
          name: t.name,
          iupacName: t.iupacName,
          description: t.description,
          category: t.category,
          reactantXyz: t.reactantXyz,
          productXyz: t.productXyz,
          referenceEa: t.referenceEa,
          doi: t.doi,
          journalRef: t.journalRef,
          tags: t.tags,
          defaults: t.defaults,
          isDerived: t.isDerived,
          derivedFrom: t.derivedFrom,
        );
      });
    }

    testWidgets('builds only a screenful of cards for a huge library',
        (tester) async {
      final huge = synthetic(3000);
      expect(huge.length, 3000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: LibraryGrid(items: huge, onTemplateSelected: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      final built = find.byType(ReactionCardWidget).evaluate().length;
      debugPrint('cards built for ${huge.length} items in a 1000x600 viewport: $built');

      // Laziness proof: a screenful plus the cache extent, nowhere near 3000.
      expect(built, greaterThan(0));
      expect(built, lessThan(60));

      // Scrolling deep into the list must still work and stay bounded.
      await tester.fling(find.byType(GridView), const Offset(0, -20000), 20000);
      await tester.pumpAndSettle();
      final afterScroll = find.byType(ReactionCardWidget).evaluate().length;
      debugPrint('cards built after scrolling: $afterScroll');
      expect(afterScroll, lessThan(60));
    });
  });
}
