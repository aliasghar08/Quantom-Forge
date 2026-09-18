// ============================================================================
// Reaction Card Widget — displays a template in the library browser
// Overflow-safe: no Expanded inside unbounded Column. All text is clamped.
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

  static Color categoryColor(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => const Color(0xFF4FC3F7),
      ReactionCategory.radical       => const Color(0xFFFF7043),
      ReactionCategory.organometallic=> const Color(0xFFAB47BC),
      ReactionCategory.ionic         => const Color(0xFF26A69A),
      ReactionCategory.thermal       => const Color(0xFFFFCA28),
      ReactionCategory.nucleophilic  => const Color(0xFF66BB6A),
    };
  }

  static String categoryLabel(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => 'Pericyclic',
      ReactionCategory.radical       => 'Radical',
      ReactionCategory.organometallic=> 'Organometallic',
      ReactionCategory.ionic         => 'Ionic',
      ReactionCategory.thermal       => 'Thermal',
      ReactionCategory.nucleophilic  => 'Nucleophilic',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(template.category);

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // ← key: don't expand
            children: [
              // ── Top row: category chip + Ea badge ──────────────────────────
              Row(
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      categoryLabel(template.category),
                      style: TextStyle(
                          color: color, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  // Ea badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, size: 12, color: Colors.amber.shade300),
                      const SizedBox(width: 3),
                      Text(
                        '${template.referenceEa} kcal/mol',
                        style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Reaction name ───────────────────────────────────────────────
              Text(
                template.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // ── IUPAC name ──────────────────────────────────────────────────
              Text(
                template.iupacName,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // ── Description (clamped, no Expanded needed) ───────────────────
              Text(
                template.description,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.45),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // ── Tags ────────────────────────────────────────────────────────
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: template.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 9),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ── Footer: DOI + Load button ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.journalRef,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onLoad,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.science, size: 14),
                    label: const Text('Load',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
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
