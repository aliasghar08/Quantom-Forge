import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/reaction_progress_card.dart';

void main() {
  testWidgets('ReactionProgressCard renders without errors', (WidgetTester tester) async {
    final status = ReactionStatusResponse(
      reactionId: '123',
      state: ReactionState.optimizing,
      progress: 0.5,
      message: 'Testing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReactionProgressCard(status: status),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ReactionProgressCard), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    
    // Advance time to test animation
    await tester.pump(const Duration(milliseconds: 500));
  });
}
