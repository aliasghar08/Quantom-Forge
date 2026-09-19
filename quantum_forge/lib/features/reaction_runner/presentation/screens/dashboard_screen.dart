// ============================================================================
// Dashboard Screen — PhD Researcher 3-Column Desktop Layout
// Left Rail | Center Setup & Status | Right Quantum Controls
//
// All widgets are in separate files under dashboard_cards/.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/state/reaction_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/core/utils/avogadro_bridge.dart';
import 'package:quantum_forge/core/utils/avogadro_codec.dart';
import 'package:quantum_forge/core/utils/avogadro_deep_link.dart';
import 'package:quantum_forge/core/utils/avogadro_interchange.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/utils/zip_writer.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/results_header_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/quantum_controls_panel.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/screens/library_screen.dart';
// Dashboard card widgets
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/energy_profile_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/hero_metrics_row.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/arrhenius_plot_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/thermo_properties_grid.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/molecular_data_cards.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/distinct_molecules_viewer.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/vibrational_analysis_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/reaction_status_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/reaction_error_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/reaction_animation_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/reaction_progress_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/left_nav_rail.dart';
import 'history_screen.dart';
import 'coordinate_editor_screen.dart';
import 'package:quantum_forge/features/settings/presentation/screens/settings_screen.dart';
import 'package:quantum_forge/state/dashboard_viewmodel.dart';

import 'package:quantum_forge/core/services/chemical_resolver_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardViewModel _viewModel;
  int? _selectedFrameIndex;

  /// Set when a deep link arrived but auto-load is disabled (or was rejected),
  /// so the user still gets told what happened instead of silence.
  AvogadroDeepLink? _pendingLink;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel();
    _viewModel.loadState();
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleIncomingStructure());
  }

  void _onViewModelChanged() {
    if (_viewModel.shouldAutoRun) {
      _viewModel.consumeAutoRun();
      if (_canDispatch) {
        // Need to wait for frame to render the new state before dispatching
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _dispatch();
        });
      }
    }
  }

  /// Handles a structure pushed in from Avogadro through the URL.
  ///
  /// The previous implementation decoded the payload by hand, dropped it into
  /// the first reactant slot and swallowed every failure in a debugPrint — the
  /// user saw nothing at all when a payload was malformed. It now decodes
  /// through [AvogadroCodec] (CJSON *and* legacy XYZ), reports failures in the
  /// UI, honours the bridge preferences, and opens the editor.
  void _handleIncomingStructure() {
    final settings = context.read<AppSettingsNotifier>().settings;
    if (!settings.avogadroBridgeEnabled) return;

    final link = AvogadroDeepLinkCodec.fromCurrentUrl();
    if (link.isAbsent) return;

    if (link.isInvalid) {
      setState(() => _pendingLink = link);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avogadro import failed: ${link.error}'),
          duration: const Duration(seconds: 8),
        ),
      );
      _cleanUrl(settings);
      return;
    }

    final structure = link.structure!;
    if (settings.autoImportDeepLink) {
      _viewModel.loadStructure(structure);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded from Avogadro — ${link.summary}'),
          duration: const Duration(seconds: 5),
        ),
      );
      _cleanUrl(settings);
    } else {
      // Auto-load off: keep the banner so the work is not lost on refresh.
      setState(() => _pendingLink = link);
    }
  }

  void _cleanUrl(AppSettings settings) {
    if (!settings.cleanUrlAfterImport) return;
    AvogadroBridge.stripImportParams(Uri.base);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  bool get _canDispatch {
    final reactionNotifier = context.read<ReactionNotifier>();
    return _viewModel.canDispatch(
      reactionNotifier.isLoading,
      reactionNotifier.value?.state == ReactionState.optimizing || reactionNotifier.value?.state == ReactionState.pending
    );
  }

  void _dispatch() {
    setState(() => _selectedFrameIndex = null);
    final settings = context.read<QuantumSettingsNotifier>().value;
    if (_viewModel.activeTemplate != null) {
      context.read<ReactionNotifier>()
          .dispatchFromTemplate(_viewModel.activeTemplate!, settings);
    } else {
      final rList = [..._viewModel.reactants, ..._viewModel.catalysts];
      final pList = [..._viewModel.products, ..._viewModel.catalysts];
      final reactantFile = _viewModel.mergeXyz(rList, 'reactant');
      final productFile  = _viewModel.mergeXyz(pList,  'product');
      context.read<ReactionNotifier>()
          .dispatchReaction(reactantFile, productFile, settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    final settings = context.watch<AppSettingsNotifier>().settings;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: palette.scaffold,
          drawer: ProfessionalDrawer(
            current: _viewModel.navDest,
            onDestinationSelected: (d) {
              _viewModel.setNavDestination(d);
              Navigator.pop(context); // Close drawer
            },
            controlsPanelOpen: _viewModel.controlsPanelOpen,
            onToggleControls: () {
              _viewModel.toggleControlsPanel();
            },
          ),
          appBar: AppBar(
            backgroundColor: palette.scaffold,
            title: Text(
              'Quantum Forge',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: palette.textPrimary,
              ),
            ),
            iconTheme: IconThemeData(color: palette.textPrimary),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: settings.showTooltips ? 'Settings' : null,
                icon: Icon(Icons.settings_outlined, color: palette.textSecondary),
                onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: palette.border, height: 1.0),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.backgroundGradient,
              ),
            ),
            child: Column(
              children: [
                if (_pendingLink != null) _buildImportBanner(palette),
                Expanded(child: _buildCenter()),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shown when a structure arrived by deep link but was not auto-loaded.
  Widget _buildImportBanner(QuantumTheme palette) {
    final link = _pendingLink!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 18, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              link.isReady
                  ? 'Structure received from Avogadro — ${link.summary}'
                  : 'Avogadro payload could not be read: ${link.error}',
              style: TextStyle(color: palette.textPrimary, fontSize: 12.5),
            ),
          ),
          if (link.isReady)
            FilledButton.icon(
              onPressed: () {
                final structure = link.structure!;
                final settings = context.read<AppSettingsNotifier>().settings;
                setState(() => _pendingLink = null);
                _viewModel.loadStructure(structure);
                _cleanUrl(settings);
              },
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text('Open in editor'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
              ),
            ),
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(Icons.close, size: 18, color: palette.textMuted),
            onPressed: () => setState(() => _pendingLink = null),
          ),
        ],
      ),
    );
  }

  // ── Center area ────────────────────────────────────────────────────────────
  Widget _buildCenter() {
    return Container(
      color: Colors.transparent,
      child: switch (_viewModel.navDest) {
        NavDestination.library  => LibraryScreen(onTemplateSelected: _viewModel.loadTemplate),
        NavDestination.history  => const HistoryScreen(),
        NavDestination.editor   => CoordinateEditorScreen(
            // Keyed on the import revision, not on the structure's hashCode:
            // a new import rebuilds the editor, anything else leaves the user's
            // in-progress coordinates untouched.
            key: ValueKey('editor-${_viewModel.structureRevision}'),
            initialStructure: _viewModel.pendingStructure,
          ),
        NavDestination.newReaction   => _buildReactionWorkspace(),
      },
    );
  }

  // ── Reaction workspace ──────────────────────────────────────────────────────────
  Widget _buildReactionWorkspace() {
    final reactionNotifier = context.read<ReactionNotifier>();

    return ValueListenableBuilder<ReactionStatusResponse?>(
      valueListenable: reactionNotifier,
      builder: (context, reactionStatus, _) {
        final isLoading = reactionNotifier.isLoading;
        final hasError = reactionNotifier.error != null;
        final errorMsg = reactionNotifier.error;
        final status = reactionStatus ?? ReactionStatusResponse.empty();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            
            final mainContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _viewModel.activeTemplate?.name ?? 'Custom Reaction',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_viewModel.activeTemplate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _viewModel.activeTemplate!.iupacName,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.3),
                                  
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dispatch button
                    FilledButton.icon(
                      onPressed: _canDispatch ? _dispatch : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white30,
                      ),
                      icon: isLoading ||
                              status.state == ReactionState.optimizing ||
                              status.state == ReactionState.pending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black54),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        status.state == ReactionState.optimizing ||
                                status.state == ReactionState.pending
                            ? 'Running...'
                            : 'Execute TS Search',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Input setup card
                _buildSetupCard(),
                const SizedBox(height: 16),

                // Results / status
                if (hasError)
                  ReactionErrorCard(error: errorMsg!)
                else if (isLoading || status.state == ReactionState.pending || status.state == ReactionState.optimizing)
                  ReactionProgressCard(status: status)
                else
                  _buildResultsArea(status),
                  
                if (!isDesktop && _viewModel.controlsPanelOpen) ...[
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  QuantumControlsPanel(activeTemplate: _viewModel.activeTemplate),
                ],
              ],
            );

            if (isDesktop && _viewModel.controlsPanelOpen) {
              // Sticky controls panel: the main column scrolls independently
              // while the side panel stays pinned in view. If the panel's own
              // content is taller than the viewport, it scrolls itself.
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(child: mainContent),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: QuantumControlsPanel(activeTemplate: _viewModel.activeTemplate),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: mainContent,
            );
          }
        );
      },
    );
  }

  // ── Setup card ─────────────────────────────────────────────────────────────
  Widget _buildSetupCard() {
    final isTemplate = _viewModel.activeTemplate != null;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTemplate ? Icons.check_circle : Icons.science_outlined,
                  color: isTemplate
                      ? Colors.greenAccent.shade200
                      : Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isTemplate ? 'Template Loaded' : 'System Coordinates',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const Spacer(),
                if (isTemplate)
                  TextButton.icon(
                    onPressed: _viewModel.clearTemplate,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Use custom files'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isTemplate)
              _buildTemplateDisplay()
            else ...[
              _buildFileUploadRow(),
              const SizedBox(height: 24),
              _buildQuickTemplates(),
            ],
            const SizedBox(height: 20),
            _buildVitalsSummary(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSummary(BuildContext context) {
    return ValueListenableBuilder<QuantumSettings>(
      valueListenable: context.read<QuantumSettingsNotifier>(),
      builder: (context, settings, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _vitalItem(Icons.bolt, 'Charge',
                  settings.charge > 0 ? '+${settings.charge}' : settings.charge.toString()),
              _vitalItem(Icons.rotate_right, 'Spin',
                  settings.spinMultiplicity.toString()),
              _vitalItem(Icons.memory, 'Model', settings.mlipModel),
              _vitalItem(Icons.water_drop_outlined, 'Solvent', settings.solventModel),
              _vitalItem(Icons.thermostat, 'Temp',
                  '${settings.temperatureK.toStringAsFixed(0)} K'),
            ],
          ),
        );
      },
    );
  }

  Widget _vitalItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.cyanAccent.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickTemplates() {
    final topTemplates = kReactionTemplates.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or try a sample reaction to test the engine:',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: topTemplates
              .map((t) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          _viewModel.loadTemplate(t);
                          context.read<QuantumSettingsNotifier>().update((q) => q.copyWith(
                            charge: t.defaults.charge,
                            spinMultiplicity: t.defaults.spinMultiplicity,
                            mlipModel: t.defaults.mlipModel,
                            optimizerAlgorithm: t.defaults.optimizerAlgorithm,
                          ));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.science,
                                      size: 14, color: Colors.blue.shade300),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.iupacName,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTemplateDisplay() {
    List<String> reactantNames = ['Reactant'];
    List<String> productNames = ['Product'];

    if (_viewModel.activeTemplate != null) {
      final name = _viewModel.activeTemplate!.iupacName;
      final arrow = name.contains('→') ? '→' : '->';
      if (name.contains(arrow)) {
        final parts = name.split(arrow);
        if (parts.length >= 2) {
          reactantNames = parts[0].split('+').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          productNames = parts[1].split('+').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          
          if (reactantNames.isEmpty) reactantNames = ['Reactant'];
          if (productNames.isEmpty) productNames = ['Product'];
          
          reactantNames[0] = reactantNames[0][0].toUpperCase() + reactantNames[0].substring(1);
          productNames[0] = productNames[0][0].toUpperCase() + productNames[0].substring(1);
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < reactantNames.length; i++) ...[
                _moleculeBox(
                  label: reactantNames[i],
                  subtitle: 'Embedded geometry',
                  color: const Color(0xFF4FC3F7),
                  icon: Icons.commit,
                ),
                if (i < reactantNames.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.add, color: Colors.white24, size: 20),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward, color: Colors.amber.shade300, size: 24),
              const SizedBox(height: 4),
              Text('TS',
                  style: TextStyle(
                      color: Colors.amber.shade300,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < productNames.length; i++) ...[
                _moleculeBox(
                  label: productNames[i],
                  subtitle: 'Embedded geometry',
                  color: const Color(0xFF66BB6A),
                  icon: Icons.commit,
                ),
                if (i < productNames.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.add, color: Colors.white24, size: 20),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _moleculeBox({
    required String label,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadRow() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildMoleculeList(MoleculeRole.reactant)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Icon(Icons.arrow_forward, color: Colors.white24, size: 20),
            ),
            Expanded(child: _buildMoleculeList(MoleculeRole.product)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: _buildMoleculeList(MoleculeRole.catalyst),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SizedBox(width: 20),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildMoleculeList(MoleculeRole role) {
    final list = role == MoleculeRole.reactant 
        ? _viewModel.reactants 
        : role == MoleculeRole.product ? _viewModel.products : _viewModel.catalysts;
    final label = role == MoleculeRole.reactant 
        ? 'Reactant' 
        : role == MoleculeRole.product ? 'Product' : 'Catalyst';
    final buttonColor = role == MoleculeRole.catalyst ? Colors.amber.shade300 : const Color(0xFF4FC3F7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (role == MoleculeRole.catalyst)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 16),
                const SizedBox(width: 8),
                Text('Catalysts (Optional)', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ...list.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _moleculeInputCard('$label ${i + 1}', entry, role),
                ),
                if (list.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                    onPressed: () => _viewModel.removeMolecule(role, entry),
                  ),
                ],
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _viewModel.addMolecule(role),
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add $label'),
          style: TextButton.styleFrom(
            foregroundColor: buttonColor,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── Live-autocomplete molecule input ──────────────────────────────────────
  Widget _moleculeInputCard(String label, MoleculeEntry entry, MoleculeRole role) {
    final uploaded = entry.resolved;
    final isResolving = entry.isResolving;
    final ctrl = entry.ctrl;
    final focus = entry.focus;
    final suggestions = entry.suggestions;
    final suggestionsLoading = entry.suggestionsLoading;

    return Container(
      decoration: BoxDecoration(
        color: uploaded
            ? Colors.greenAccent.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploaded
              ? Colors.greenAccent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              children: [
                Icon(
                  uploaded ? Icons.check_circle_rounded : Icons.science_outlined,
                  color: uploaded
                      ? Colors.greenAccent.shade200
                      : const Color(0xFF4FC3F7),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (uploaded)
                        Text(
                          entry.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                if (uploaded) ...[
                  // Source badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '3D ready',
                      style: TextStyle(
                        color: Colors.greenAccent.shade200,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 15, color: Colors.white38),
                    onPressed: () => _viewModel.clearEntry(entry),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Clear',
                  ),
                ] else if (isResolving)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4FC3F7),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Search input + upload ──────────────────────────────────
          if (!uploaded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF4FC3F7), size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      focusNode: focus,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '$label name or SMILES…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => _viewModel.onSearchChanged(val, entry, context.read<ChemicalResolverService>()),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _viewModel.resolveChemical(entry, context.read<ChemicalResolverService>(), query: val.trim());
                        }
                      },
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1, height: 18,
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  // Upload xyz fallback
                  GestureDetector(
                    onTap: () => _viewModel.pickFileForEntry(entry, context.read<FilePickerService>()),
                    child: Tooltip(
                      message: 'Upload .xyz file',
                      child: Icon(
                        Icons.upload_file_rounded,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            // Divider line
            Container(
              height: 1,
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ],

          // ── Live suggestions dropdown ──────────────────────────────
          if (!uploaded && (suggestions.isNotEmpty || suggestionsLoading)) ...[
            if (suggestionsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4FC3F7)),
                    ),
                    SizedBox(width: 10),
                    Text('Searching PubChem…',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: suggestions.asMap().entries.map((e) {
                  final i = e.key;
                  final suggestion = e.value;
                  final isLast = i == suggestions.length - 1;
                  return InkWell(
                    onTap: () => _viewModel.onSuggestionSelected(suggestion, entry, context.read<ChemicalResolverService>()),
                    borderRadius: BorderRadius.only(
                      bottomLeft: isLast ? const Radius.circular(10) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(10) : Radius.zero,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: !isLast
                            ? Border(bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.science_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.35)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.north_west_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.2)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 4),
          ] else if (!uploaded)
            const SizedBox(height: 10),
        ],
      ),
    );
  }
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: context.read<ThemeNotifier>().palette.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Writes the converged structure (final frame) to a file.
  ///
  /// The old "Export Results (.zip)" button called a web stub that returned a
  /// fake `memory://` path and never produced a file — it told the user
  /// "Exported to: memory://results_….zip" and nothing was downloaded.
  void _exportResults(ReactionStatusResponse status) {
    final frames = status.trajectoryFrames ?? const <String>[];
    if (frames.isEmpty) {
      _notify('No trajectory frames available to export yet.');
      return;
    }
    final settings = context.read<AppSettingsNotifier>().settings;
    final finalFrame = XyzParser.parse(frames.last);
    if (finalFrame.isEmpty) {
      _showError('The final frame could not be parsed as an XYZ structure.');
      return;
    }
    try {
      downloadAtoms(
        atoms: finalFrame,
        title: 'Quantum Forge ${status.reactionId} — final structure',
        format: settings.defaultExportFormat.extension,
        precision: settings.exportPrecision,
        includeTitleLine: settings.includeTitleLine,
        bondTolerance: settings.bondTolerance,
      );
      _notify(
        'Exported the final structure (${finalFrame.length} atoms) as '
        '.${settings.defaultExportFormat.extension}',
      );
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  /// Downloads every trajectory frame plus a manifest as a real ZIP archive.
  void _exportArchive(ReactionStatusResponse status) {
    final frames = status.trajectoryFrames ?? const <String>[];
    if (frames.isEmpty) {
      _notify('No trajectory frames available to archive yet.');
      return;
    }
    final settings = context.read<AppSettingsNotifier>().settings;
    final energies = status.energyProfile ?? const <double>[];

    final entries = <ZipEntry>[
      ZipEntry(
        'README.txt',
        'Quantum Forge export\n'
            '====================\n'
            'Reaction id : ${status.reactionId}\n'
            'State       : ${status.state.name}\n'
            'Frames      : ${frames.length}\n'
            'Atoms/frame : ${XyzParser.parse(frames.first).length}\n'
            'Generated   : ${DateTime.now().toIso8601String()}\n\n'
            'trajectory.xyz  — every image of the reaction path (multi-XYZ).\n'
            'final.xyz       — the converged structure.\n'
            'manifest.csv    — image index, energy, atom count.\n',
      ),
    ];

    final structures = <AvogadroStructure>[];
    final manifest = StringBuffer('image,energy_kcal_per_mol,atoms\n');
    for (var i = 0; i < frames.length; i++) {
      final atoms = XyzParser.parse(frames[i]);
      if (atoms.isEmpty) continue;
      structures.add(AvogadroInterchange.structure(
        atoms,
        title: 'Image ${i + 1}/${frames.length}',
        bondTolerance: settings.bondTolerance,
      ));
      final energy = i < energies.length ? energies[i].toStringAsFixed(4) : '';
      manifest.writeln('${i + 1},$energy,${atoms.length}');
    }

    if (structures.isEmpty) {
      _showError('None of the trajectory frames could be parsed.');
      return;
    }

    entries.add(ZipEntry(
      'trajectory.xyz',
      AvogadroInterchange.toMultiXyz(
        structures,
        precision: settings.exportPrecision,
        includeTitleLine: settings.includeTitleLine,
      ),
    ));
    entries.add(ZipEntry('final.xyz', AvogadroInterchange.toXyz(
      structures.last,
      precision: settings.exportPrecision,
      includeTitleLine: settings.includeTitleLine,
    )));
    entries.add(ZipEntry('final.cjson', AvogadroInterchange.toCjson(structures.last)));
    entries.add(ZipEntry('manifest.csv', manifest.toString()));

    try {
      final archive = ZipWriter.build(entries);
      AvogadroBridge.downloadBytes(
        'quantum_forge_${status.reactionId}.zip',
        archive,
        mimeType: 'application/zip',
      );
      _notify(
        'Downloaded ${entries.length} files '
        '(${(archive.length / 1024).toStringAsFixed(1)} kB) as a ZIP archive.',
      );
    } catch (e) {
      _showError('Archive export failed: $e');
    }
  }

  /// Exports the whole NEB trajectory for inspection in Avogadro.
  void _exportTrajectoryForAvogadro(
    ReactionStatusResponse status,
    QuantumTheme palette,
  ) {
    final frames = status.trajectoryFrames ?? const <String>[];
    if (frames.isEmpty) {
      _notify('No trajectory frames available to export.');
      return;
    }
    final settings = context.read<AppSettingsNotifier>().settings;
    final structures = <AvogadroStructure>[];
    for (var i = 0; i < frames.length; i++) {
      final atoms = XyzParser.parse(frames[i]);
      if (atoms.isEmpty) continue;
      structures.add(AvogadroInterchange.structure(
        atoms,
        title: 'Image ${i + 1}/${frames.length}',
        bondTolerance: settings.bondTolerance,
      ));
    }
    if (structures.isEmpty) {
      _showError('None of the trajectory frames could be parsed.');
      return;
    }
    try {
      AvogadroBridge.downloadTrajectory(
        structures,
        filename: 'quantum_forge_${status.reactionId}_path.xyz',
        precision: settings.exportPrecision,
        includeTitleLine: settings.includeTitleLine,
      );
      _notify(
        'Exported ${structures.length} images as a multi-XYZ trajectory — open '
        'it in Avogadro to animate the path.',
      );
    } catch (e) {
      _showError('Trajectory export failed: $e');
    }
  }

  // ── Results area ───────────────────────────────────────────────────────────
  Widget _buildResultsArea(ReactionStatusResponse status) {
    final palette = context.watch<ThemeNotifier>().palette;
    final appSettings = context.watch<AppSettingsNotifier>().settings;

    if (status.state != ReactionState.completed) {
      return ReactionStatusCard(
        message: status.message ?? 'Ready to begin.',
        progress: status.progress,
        state: status.state,
      );
    }

    final energyProfile = status.energyProfile ?? [];

    if (_selectedFrameIndex == null && energyProfile.isNotEmpty) {
      final maxE = energyProfile.reduce((a, b) => a > b ? a : b);
      _selectedFrameIndex = energyProfile.indexWhere((e) => e == maxE);
    }

    return ValueListenableBuilder<QuantumSettings>(
      valueListenable: context.read<QuantumSettingsNotifier>(),
      builder: (context, settings, _) {
        final summary = computeResultsSummary(
          settings: settings,
          energyProfile: energyProfile,
          referenceEa: _viewModel.activeTemplate?.referenceEa,
        );

        return Column(
          children: [
            // Export Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _exportResults(status),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export results (.xyz)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent.withValues(alpha: 0.15),
                    foregroundColor: palette.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _exportArchive(status),
                  icon: const Icon(Icons.folder_zip_outlined, size: 16),
                  label: const Text('Export bundle (.zip)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.warning.withValues(alpha: 0.15),
                    foregroundColor: palette.warning,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _exportTrajectoryForAvogadro(status, palette),
                  icon: const Icon(Icons.science, size: 16),
                  label: Text('Export trajectory (.${appSettings.defaultExportFormat.extension})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.success.withValues(alpha: 0.15),
                    foregroundColor: palette.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results header — method, conditions, confidence
            ResultsHeaderCard(
              summary: summary,
              reactionName: _viewModel.activeTemplate?.name,
            ),
            const SizedBox(height: 16),

            // Energy profile (with ±1σ band)
            AspectRatio(
              aspectRatio: 1.8,
              child: EnergyProfileCard(
                energyProfile: summary.energyProfile,
                referenceEa: summary.referenceEa,
                uncertainty: summary.profileUncertainty,
                onPointSelected: (index) =>
                    setState(() => _selectedFrameIndex = index),
              ),
            ),
            const SizedBox(height: 16),

            // Hero metrics
            HeroMetricsRow(metrics: summary.heroMetrics),
            const SizedBox(height: 16),

            // Arrhenius plot
            ArrheniusPlotCard(
              ea: summary.estimatedEa,
              eaUncertainty: summary.byLabel('Activation Energy (Ea)').uncertainty,
              rateVsTemp: summary.rateVsTemp,
              lnUncertainty: summary.lnUncertainty,
            ),
            const SizedBox(height: 16),

            // Thermo properties grid
            ThermoPropertiesGrid(metrics: summary.thermoMetrics),
            const SizedBox(height: 16),

            // Molecular data
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              MolecularDataCards(trajectoryFrames: status.trajectoryFrames!),
              const SizedBox(height: 16),
            ],

            // Distinct reactants
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              DistinctMoleculesViewer(
                title: 'Distinct Reactants',
                atoms: XyzParser.parse(status.trajectoryFrames!.first),
              ),
              const SizedBox(height: 16),
            ],

            // Distinct products
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              DistinctMoleculesViewer(
                title: 'Distinct Products',
                atoms: XyzParser.parse(status.trajectoryFrames!.last),
              ),
              const SizedBox(height: 16),
            ],

            // Reaction animation card (extracted widget)
            ReactionAnimationCard(status: status),
            const SizedBox(height: 16),

            // Vibrational Analysis Card
            if (status.vibrationalModes != null && status.vibrationalModes!.isNotEmpty) ...[
              VibrationalAnalysisCard(status: status),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}
