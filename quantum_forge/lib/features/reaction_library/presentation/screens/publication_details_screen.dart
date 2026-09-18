import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class PublicationDetailsScreen extends StatefulWidget {
  final ReactionTemplate template;

  const PublicationDetailsScreen({super.key, required this.template});

  @override
  State<PublicationDetailsScreen> createState() => _PublicationDetailsScreenState();
}

class _PublicationDetailsScreenState extends State<PublicationDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    if (widget.template.doi.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No DOI provided for this template.';
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse('https://api.crossref.org/works/${widget.template.doi}'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          _metadata = json['message'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to fetch metadata. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error fetching metadata: $e';
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: Text('Publication Details: ${widget.template.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4FC3F7)),
            SizedBox(height: 16),
            Text('Fetching publication metadata from CrossRef...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null && _metadata == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      );
    }

    // Parse Data
    final title = _metadata?['title']?[0] ?? widget.template.name;
    final abstractHtml = _metadata?['abstract'] ?? 'Abstract not provided by publisher via CrossRef API.';
    // Clean basic abstract XML/HTML tags if present (e.g. <jats:p>)
    final abstractText = abstractHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    
    final authorsList = _metadata?['author'] as List<dynamic>?;
    String authors = 'Unknown Authors';
    if (authorsList != null && authorsList.isNotEmpty) {
      authors = authorsList.map((a) => '${a['given']} ${a['family']}').join(', ');
    }

    final publisher = _metadata?['publisher'] ?? 'Unknown Publisher';
    final containerTitle = _metadata?['container-title']?[0] ?? widget.template.journalRef;
    
    final createdDate = _metadata?['created']?['date-parts']?[0];
    final year = createdDate != null ? createdDate[0].toString() : 'Unknown Year';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: AnimationLimiter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              _buildHeaderCard(title, authors, containerTitle, publisher, year),
              const SizedBox(height: 24),
              _buildAbstractCard(abstractText),
              const SizedBox(height: 24),
              _buildExternalLinksCard(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String title, String authors, String journal, String publisher, String year) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('DOI: ${widget.template.doi}', style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(year, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(authors, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.book, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('$journal • $publisher', style: const TextStyle(color: Colors.white54, fontSize: 14))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbstractCard(String abstractText) {
    return GlassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: const Color(0xFF4FC3F7),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: const Text('Abstract', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(abstractText, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinksCard(String title) {
    final doiUrl = 'https://doi.org/${widget.template.doi}';
    final scholarUrl = 'https://scholar.google.com/scholar?q=${Uri.encodeComponent(title)}';

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('External References', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildLinkButton(
              icon: Icons.language,
              label: 'View on Publisher Site (DOI)',
              url: doiUrl,
              color: const Color(0xFF4FC3F7),
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              icon: Icons.school,
              label: 'Search on Google Scholar',
              url: scholarUrl,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              icon: Icons.data_object,
              label: 'View Raw CrossRef Metadata',
              url: 'https://api.crossref.org/works/${widget.template.doi}',
              color: Colors.orangeAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton({required IconData icon, required String label, required String url, required Color color}) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.open_in_new, color: color.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
