import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:quantum_forge/core/services/url_service.dart';

class PublicationExternalLinksCard extends StatelessWidget {
  final String title;
  final String doi;

  const PublicationExternalLinksCard({
    super.key,
    required this.title,
    required this.doi,
  });

  @override
  Widget build(BuildContext context) {
    final cleanDoi = doi.trim();
    // A DOI might exist on doi.org even if CrossRef returns 404. 
    // We should always let the user tap it if a DOI string is provided.
    final hasDoi = cleanDoi.isNotEmpty;
    
    // Google Scholar is best for titles and authors, not raw DOI strings.
    final scholarUrl = 'https://scholar.google.com/scholar?q=${Uri.encodeComponent(title)}';
    final googleSearchUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(title)}';

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('External References', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _LinkButton(
              icon: Icons.language,
              label: hasDoi ? 'View on Publisher Site (DOI)' : 'DOI Not Available',
              url: hasDoi ? 'https://doi.org/$cleanDoi' : null,
              color: const Color(0xFF4FC3F7),
              disabled: !hasDoi,
            ),
            const SizedBox(height: 12),
            _LinkButton(
              icon: Icons.school,
              label: 'Search on Google Scholar',
              url: scholarUrl,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            _LinkButton(
              icon: Icons.search,
              label: 'Search Web (Google)',
              url: googleSearchUrl,
              color: Colors.blueAccent,
            ),
            if (hasDoi) ...[
              const SizedBox(height: 12),
              _LinkButton(
                icon: Icons.data_object,
                label: 'View Raw CrossRef Metadata',
                url: 'https://api.crossref.org/works/${Uri.encodeComponent(cleanDoi)}',
                color: Colors.orangeAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? url;
  final Color color;
  final bool disabled;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? Colors.grey.withValues(alpha: 0.5) : color;
    final bgAlpha = disabled ? 0.05 : 0.1;
    final borderAlpha = disabled ? 0.1 : 0.3;

    return InkWell(
      onTap: disabled ? null : () {
            if (url == null) return;
            try {
              UrlService.launch(url!.trim());
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching link: $e')));
              }
            }
          },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: effectiveColor.withValues(alpha: borderAlpha)),
        ),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: effectiveColor, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (url != null && !disabled)
              Icon(Icons.open_in_new, color: effectiveColor.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
