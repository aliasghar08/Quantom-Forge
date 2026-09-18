import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/reaction_animation_widget.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/molecular_viewer_widget.dart';

class TemplateDetailScreen extends StatelessWidget {
  final ReactionTemplate template;
  final VoidCallback onLoad;

  const TemplateDetailScreen({
    super.key,
    required this.template,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(template.category);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Animation Viewer Header ─────────────────────────────────────
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF15151C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReactionAnimationWidget(
                  trajectoryFrames: [template.reactantXyz, template.productXyz],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Metadata Header ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _categoryLabel(template.category),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 16, color: Colors.amber.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Ea: ${template.referenceEa} kcal/mol',
                        style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLoad();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  icon: const Icon(Icons.science),
                  label: const Text('Simulate Reaction', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Info Section ──────────────────────────────────────────────
            const Text('Reaction Name', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            const Text('IUPAC Description', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.iupacName, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),

            const Text('Mechanism & Details', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.description, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6)),
            const SizedBox(height: 32),

            // ── Static Molecule Viewers ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reactants', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15151C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MolecularViewerWidget(currentXyzData: template.reactantXyz),
                        ),
                      )
                    ],
                  )
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Products', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15151C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MolecularViewerWidget(currentXyzData: template.productXyz),
                        ),
                      )
                    ],
                  )
                )
              ],
            ),
            const SizedBox(height: 32),

            // ── Tags & Reference ──────────────────────────────────────────
            const Text('Tags', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: template.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#$tag', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.book, color: Colors.white54),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Literature Reference', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(template.journalRef, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('DOI: ${template.doi}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _categoryColor(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => const Color(0xFF4FC3F7),
      ReactionCategory.radical       => const Color(0xFFFF7043),
      ReactionCategory.organometallic=> const Color(0xFFAB47BC),
      ReactionCategory.ionic         => const Color(0xFF26A69A),
      ReactionCategory.thermal       => const Color(0xFFFFCA28),
      ReactionCategory.nucleophilic  => const Color(0xFF66BB6A),
    };
  }

  String _categoryLabel(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => 'Pericyclic',
      ReactionCategory.radical       => 'Radical',
      ReactionCategory.organometallic=> 'Organometallic',
      ReactionCategory.ionic         => 'Ionic',
      ReactionCategory.thermal       => 'Thermal',
      ReactionCategory.nucleophilic  => 'Nucleophilic',
    };
  }
}
