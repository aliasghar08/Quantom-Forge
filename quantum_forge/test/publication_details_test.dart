// ============================================================================
// Publication details regression test
// ----------------------------------------------------------------------------
// Pins the fix for "failed to load metadata": when the CrossRef fetch fails
// (or has no DOI), the page must fall back to the bundled template data with a
// warning banner — never a dead-end error screen.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/screens/publication_details_screen.dart';

void main() {
  testWidgets('falls back to bundled data when CrossRef metadata is unavailable',
      (tester) async {
    final template = kReactionTemplates.firstWhere(
      (t) => t.doi.isNotEmpty,
      orElse: () => kReactionTemplates.first,
    );

    await tester.pumpWidget(
      MaterialApp(home: PublicationDetailsScreen(template: template)),
    );

    // On the Dart VM, `WebServices.fetchString` throws UnsupportedError, which
    // is exactly the failure mode this test exercises.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The template's own title is still shown (fallback)…
    expect(find.text(template.name), findsOneWidget);
    // …and a warning banner explains the metadata could not be fetched.
    expect(find.textContaining('Live metadata unavailable'), findsOneWidget);
    // The abstract card still renders (with a fallback message).
    expect(find.text('Abstract'), findsOneWidget);
  });

  testWidgets('handles a template with no DOI gracefully', (tester) async {
    final template = kReactionTemplates.firstWhere(
      (t) => t.doi.isEmpty,
      orElse: () => kReactionTemplates.first,
    );

    await tester.pumpWidget(
      MaterialApp(home: PublicationDetailsScreen(template: template)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(template.name), findsOneWidget);
  });
}
