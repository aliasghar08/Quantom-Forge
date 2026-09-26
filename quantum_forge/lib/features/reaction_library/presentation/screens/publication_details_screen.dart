import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/core/services/web_services.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:quantum_forge/core/services/url_service.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/utils/avogadro_element_data.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';


class PublicationDetailsScreen extends StatefulWidget {
  final ReactionTemplate template;

  const PublicationDetailsScreen({super.key, required this.template});

  @override
  State<PublicationDetailsScreen> createState() => _PublicationDetailsScreenState();
}

class _PublicationDetailsScreenState extends State<PublicationDetailsScreen> {
  bool _isLoadingCrossref = true;
  String? _crossrefError;
  Map<String, dynamic>? _crossrefData;

  double? _reactantEnergy;
  double? _productEnergy;
  bool _isLoadingEnergies = true;

  final ScrollController _scrollCtrl = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchCrossrefData();
      _fetchEnergies();
    });
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 200;
      if (show != _showFab) setState(() => _showFab = show);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCrossrefData() async {
    if (widget.template.doi.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingCrossref = false;
          _crossrefError = 'No DOI provided for this template.';
        });
      }
      return;
    }

    try {
      final cleanDoi = widget.template.doi.trim();
      final settings = Provider.of<AppSettingsNotifier>(context, listen: false).settings;
      final uri = settings.hasGnnBackend 
          ? '${settings.gnnBackendUrl}/crossref/${Uri.encodeComponent(cleanDoi)}'
          : 'https://api.crossref.org/works/${Uri.encodeComponent(cleanDoi)}';
          
      final responseBody = await WebServices.fetchString(uri);
      
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['message'] != null) {
        if (mounted) {
          setState(() {
            _crossrefData = json['message'] as Map<String, dynamic>;
            _isLoadingCrossref = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _crossrefError = 'Invalid DOI response';
            _isLoadingCrossref = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _crossrefError = 'Failed to load metadata: $e';
          _isLoadingCrossref = false;
        });
      }
    }
  }

  Future<void> _fetchEnergies() async {
    try {
      final settings = Provider.of<AppSettingsNotifier>(context, listen: false).settings;
      final quantumSettings = Provider.of<QuantumSettingsNotifier>(context, listen: false).value;
      if (!settings.hasGnnBackend) {
        if (mounted) setState(() => _isLoadingEnergies = false);
        return;
      }

      final reactantAtoms = XyzParser.parse(widget.template.reactantXyz);
      final productAtoms = XyzParser.parse(widget.template.productXyz);
      
      final reactantZ = reactantAtoms.map((a) => AvogadroElementData.atomicNumberForSymbol(a.symbol)).toList();
      final reactantPos = reactantAtoms.map((a) => [a.x, a.y, a.z]).toList();
      
      final productZ = productAtoms.map((a) => AvogadroElementData.atomicNumberForSymbol(a.symbol)).toList();
      final productPos = productAtoms.map((a) => [a.x, a.y, a.z]).toList();

      const computeService = BackendComputeService();
      String url = settings.gnnBackendUrl;
      if (quantumSettings.mlipModel == 'MACE-MP-0') {
        url = 'http://127.0.0.1:8001';
      }
      final rEnergy = await computeService.predictEnergy(url, reactantZ, reactantPos);
      final pEnergy = await computeService.predictEnergy(url, productZ, productPos);

      if (mounted) {
        setState(() {
          _reactantEnergy = rEnergy;
          _productEnergy = pEnergy;
          _isLoadingEnergies = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEnergies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.scaffold,
      floatingActionButton: AnimatedScale(
        scale: _showFab ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: FloatingActionButton.small(
          heroTag: 'pub_scroll_top',
          backgroundColor: palette.accent,
          foregroundColor: Colors.black87,
          onPressed: () => _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
          child: const Icon(Icons.keyboard_arrow_up),
        ),
      ),
      appBar: AppBar(
        backgroundColor: palette.scaffold,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Publication Details',
          style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: palette.textSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: palette.border),
        ),
      ),
      body: _buildBody(palette),
    );
  }

  Widget _buildBody(QuantumTheme palette) {
    if (_isLoadingCrossref) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: palette.accent),
            const SizedBox(height: 16),
            Text('Fetching publication metadata from CrossRef…', style: TextStyle(color: palette.textSecondary)),
          ],
        ),
      );
    }

    // Parse Data — every field falls back to the bundled template metadata.
    final titleList = _crossrefData?['title'] as List<dynamic>?;
    final rawTitle = (titleList != null && titleList.isNotEmpty) ? titleList[0].toString() : widget.template.name;
    final title = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final abstractHtml = _crossrefData?['abstract']?.toString() ??
        'Publication metadata could not be fetched from CrossRef'
            '${_crossrefError != null ? ' ($_crossrefError)' : ''}.\n'
            'The details shown are from the bundled reaction library.';
    final abstractText = abstractHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final authorsList = _crossrefData?['author'] as List<dynamic>?;
    String authors = 'Unknown Authors';
    if (authorsList != null && authorsList.isNotEmpty) {
      authors = authorsList.map((a) {
        final given = a['given']?.toString() ?? '';
        final family = a['family']?.toString() ?? '';
        return '$given $family'.trim();
      }).where((s) => s.isNotEmpty).join(', ');
      if (authors.isEmpty) authors = 'Unknown Authors';
    }

    final publisher = _crossrefData?['publisher']?.toString() ?? 'Unknown Publisher';

    final containerTitleList = _crossrefData?['container-title'] as List<dynamic>?;
    final containerTitle = (containerTitleList != null && containerTitleList.isNotEmpty)
        ? containerTitleList[0].toString()
        : widget.template.journalRef;

    final datePartsList = _crossrefData?['created']?['date-parts'] as List<dynamic>?;
    final createdDate = (datePartsList != null && datePartsList.isNotEmpty) ? datePartsList[0] as List<dynamic>? : null;
    final year = (createdDate != null && createdDate.isNotEmpty) ? createdDate[0].toString() : 'Unknown Year';

    final hPad = MediaQuery.of(context).size.width < 480 ? 16.0 : 24.0;

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 80),
      child: AnimationLimiter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 500),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 40.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              if (_crossrefError != null)
                _buildWarningBanner(_crossrefError!),
              if (_crossrefError != null) const SizedBox(height: 16),
              _buildHeaderCard(title, authors, containerTitle, publisher, year, palette),
              const SizedBox(height: 20),
              _buildAbstractCard(abstractText, palette),
              const SizedBox(height: 20),
              _buildEnergiesCard(palette),
              const SizedBox(height: 20),
              _buildExternalLinksCard(title, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner(String error) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Live metadata unavailable: $error',
                style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String title, String authors, String journal, String publisher, String year, QuantumTheme palette) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('DOI: ${widget.template.doi}', style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Text(year, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
            const SizedBox(height: 12),
            Text(authors, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.book, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('$journal • $publisher', style: const TextStyle(color: Colors.white54, fontSize: 13))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbstractCard(String abstractText, QuantumTheme palette) {
    return GlassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: const Color(0xFF4FC3F7),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: const Text('Abstract', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(abstractText, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergiesCard(QuantumTheme palette) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transition1x GNN Predictions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoadingEnergies)
              const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
            else if (_reactantEnergy == null && _productEnergy == null)
              const Text('Energy predictions unavailable. Ensure tx1-fastapi-backend is running.', style: TextStyle(color: Colors.white54, fontSize: 13))
            else
              Row(
                children: [
                  Expanded(
                    child: _buildEnergyBox('Reactant Energy', _reactantEnergy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEnergyBox('Product Energy', _productEnergy),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyBox(String label, double? energy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            energy != null ? '${energy.toStringAsFixed(3)} eV' : 'N/A',
            style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalLinksCard(String title, QuantumTheme palette) {
    final cleanDoi = widget.template.doi.trim();
    // A DOI might exist on doi.org even if CrossRef returns 404. 
    // We should always let the user tap it if a DOI string is provided.
    final hasDoi = cleanDoi.isNotEmpty;
    
    // Google Scholar is best for titles and authors, not raw DOI strings.
    final scholarUrl = 'https://scholar.google.com/scholar?q=${Uri.encodeComponent(title)}';

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('External References', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildLinkButton(
              icon: Icons.language,
              label: hasDoi ? 'View on Publisher Site (DOI)' : 'DOI Not Available (Tap for options)',
              url: hasDoi ? 'https://doi.org/$cleanDoi' : null,
              color: hasDoi ? const Color(0xFF4FC3F7) : Colors.white38,
              onTapOverride: hasDoi ? null : () => _showMissingDoiDialog(title, scholarUrl),
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              icon: Icons.school,
              label: 'Search on Google Scholar',
              url: scholarUrl,
              color: Colors.greenAccent,
            ),
            if (hasDoi) ...[
              const SizedBox(height: 12),
              _buildLinkButton(
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

  void _showMissingDoiDialog(String title, String scholarUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('DOI Not Available', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This specific structural variant is systematically generated and does not map to a single DOI citation.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'Try searching for related literature on these platforms:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildLinkButton(
                icon: Icons.school,
                label: 'Google Scholar',
                url: scholarUrl,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 8),
              _buildLinkButton(
                icon: Icons.science,
                label: 'ChemSpider',
                url: 'http://www.chemspider.com/Search.aspx?q=${Uri.encodeComponent(title)}',
                color: Colors.purpleAccent,
              ),
              const SizedBox(height: 8),
              _buildLinkButton(
                icon: Icons.search,
                label: 'Web of Science (General Search)',
                url: 'https://www.webofscience.com/',
                color: Colors.amberAccent,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLinkButton({
    required IconData icon,
    required String label,
    required String? url,
    required Color color,
    VoidCallback? onTapOverride,
  }) {
    return InkWell(
      onTap: onTapOverride ??
          () {
            if (url == null) return;
            try {
              UrlService.launch(url.trim());
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching link: $e')));
              }
            }
          },
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
            if (url != null)
              Icon(Icons.open_in_new, color: color.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
