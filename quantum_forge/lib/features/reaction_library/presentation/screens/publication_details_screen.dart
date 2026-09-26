import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/core/services/web_services.dart';
import 'package:quantum_forge/core/widgets/animations/staggered_animation_list.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/utils/avogadro_element_data.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';

import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_warning_banner.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_header_card.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_abstract_card.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_energies_card.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_external_links_card.dart';
import 'package:quantum_forge/features/reaction_library/presentation/widgets/publication/publication_related_videos_card.dart';

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
    // Non-blocking UI: The page renders immediately using bundled template data,
    // while the CrossRef data loads in the background.

    // Parse Data — every field falls back to the bundled template metadata.
    final titleList = _crossrefData?['title'] as List<dynamic>?;
    final rawTitle = (titleList != null && titleList.isNotEmpty) ? titleList[0].toString() : widget.template.name;
    final title = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final abstractHtml = _isLoadingCrossref
        ? 'Fetching publication metadata from CrossRef (and live energies from GNN backend)…'
        : (_crossrefData?['abstract']?.toString() ??
          'Publication metadata could not be fetched from CrossRef'
          '${_crossrefError != null ? ' ($_crossrefError)' : ''}.\n'
          'The details shown are from the bundled reaction library.');
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
      child: StaggeredAnimationList(
        children: [
          if (_isLoadingCrossref)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: palette.accent, strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Fetching live metadata and energy profiles...', style: TextStyle(color: palette.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          if (_crossrefError != null && !_isLoadingCrossref)
            PublicationWarningBanner(error: _crossrefError!),
          if (_crossrefError != null && !_isLoadingCrossref) const SizedBox(height: 16),
          PublicationHeaderCard(
            title: title,
            authors: authors,
            journal: containerTitle,
            publisher: publisher,
            year: year,
            doi: widget.template.doi,
          ),
          const SizedBox(height: 20),
          PublicationAbstractCard(abstractText: abstractText),
          const SizedBox(height: 20),
          PublicationEnergiesCard(
            isLoading: _isLoadingEnergies,
            reactantEnergy: _reactantEnergy,
            productEnergy: _productEnergy,
          ),
          const SizedBox(height: 20),
          PublicationExternalLinksCard(
            title: title,
            doi: widget.template.doi,
          ),
          const SizedBox(height: 20),
          PublicationRelatedVideosCard(query: title),
        ],
      ),
    );
  }
}
