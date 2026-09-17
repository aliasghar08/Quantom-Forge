// ============================================================================
// Reaction Card Widget — displays a template in the library browser
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

class ReactionCardWidget extends StatelessWidget {
  final ReactionTemplate template;
  final VoidCallback onLoad;

  const ReactionCardWidget({
    super.key,
    required this.template,
    required this.onLoad,
  });

  static Color _categoryColor(ReactionCategory c) {
    switch (c) {
      case ReactionCategory.pericyclic:
        return const Color(0xFF4FC3F7); // sky blue
      case ReactionCategory.radical:
        return const Color(0xFFFF7043); // deep orange
      case ReactionCategory.organometallic:
        return const Color(0xFFAB47BC); // purple
      case ReactionCategory.ionic:
        return const Color(0xFF26A69A); // teal
      case ReactionCategory.thermal:
        return const Color(0xFFFFCA28); // amber
      case ReactionCategory.nucleophilic:
        return const Color(0xFF66BB6A); // green
    }
  }

  static String _categoryLabel(ReactionCategory c) {
    switch (c) {
      case ReactionCategory.pericyclic:
        return 'Pericyclic';
      case ReactionCategory.radical:
        return 'Radical';
      case ReactionCategory.organometallic:
        return 'Organometallic';
      case ReactionCategory.ionic:
        return 'Ionic';
      case ReactionCategory.thermal:
        return 'Thermal';
      case ReactionCategory.nucleophilic:
        return 'Nucleophilic';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(template.category);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onLoad,
        hoverColor: color.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _categoryLabel(template.category),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Ea badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.amber.shade300),
                    const SizedBox(width: 4),
                    Text(
                      'ΔE‡ = ${template.referenceEa} kcal/mol',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reaction name
              Text(
                template.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // IUPAC name
              Text(
                template.iupacName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Description
              Expanded(
                child: Text(
                  template.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 16),

              // Tags
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: template.tags.take(4).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // DOI + Load button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.journalRef,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onLoad,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.science, size: 16),
                    label: const Text(
                      'Load Template',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
