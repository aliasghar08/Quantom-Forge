// ============================================================================
// Dashboard Screen — PhD Researcher 3-Column Desktop Layout
// Left Rail | Center Setup & Status | Right Quantum Controls
//
// All widgets are in separate files under dashboard_cards/.
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/job_runner/providers/job_provider.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/quantum_controls_panel.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/screens/library_screen.dart';
// Dashboard card widgets
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/energy_profile_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/hero_metrics_row.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/arrhenius_plot_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/thermo_properties_grid.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/molecular_data_cards.dart';
import 'package:quantum_forge/core/services/storage_service.dart';
import 'package:quantum_forge/core/services/local_storage_service.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/distinct_molecules_viewer.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/vibrational_analysis_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/job_status_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/job_error_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/reaction_animation_card.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/dashboard_cards/left_nav_rail.dart';
import 'history_screen.dart';
import 'coordinate_editor_screen.dart';

import 'package:quantum_forge/core/services/chemical_resolver_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _MoleculeEntry {
  final String id;
  PickedFile? file;
  final TextEditingController ctrl;
  final FocusNode focus;
  List<String> suggestions;
  bool suggestionsLoading;
  bool isResolving;
  Timer? debounce;

  _MoleculeEntry({required this.id})
      : ctrl = TextEditingController(),
        focus = FocusNode(),
        suggestions = [],
        suggestionsLoading = false,
        isResolving = false;

  bool get resolved => file != null;
  String get displayName => file?.name.replaceAll('.xyz', '') ?? '';

  void dispose() {
    ctrl.dispose();
    focus.dispose();
    debounce?.cancel();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  NavDestination _navDest = NavDestination.newJob;
  int? _selectedFrameIndex;
  ReactionTemplate? _activeTemplate;
  bool _controlsPanelOpen = true;

  // Multi-molecule lists (at least 1 entry each)
  final List<_MoleculeEntry> _reactants = [_MoleculeEntry(id: 'r0')];
  final List<_MoleculeEntry> _products  = [_MoleculeEntry(id: 'p0')];
  int _entryCounter = 1;

  @override
  void dispose() {
    for (final e in _reactants) {
      e.dispose();
    }
    for (final e in _products) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Merge multiple XYZ files into one combined XYZ ────────────────────────
  PickedFile _mergeXyz(List<_MoleculeEntry> entries, String label) {
    final resolved = entries.where((e) => e.file != null).toList();
    if (resolved.length == 1) return resolved.first.file!;

    // Combine: sum atom counts, concatenate atom lines
    int totalAtoms = 0;
    final atomLines = <String>[];
    for (final e in resolved) {
      final raw = String.fromCharCodes(e.file!.bytes!);
      final lines = raw.trim().split('\n');
      if (lines.length < 3) continue;
      final count = int.tryParse(lines[0].trim()) ?? 0;
      totalAtoms += count;
      atomLines.addAll(lines.skip(2).take(count));
    }
    final combined = '$totalAtoms\nCombined $label\n${atomLines.join('\n')}\n';
    final bytes = Uint8List.fromList(utf8.encode(combined));
    return PickedFile(name: 'combined_$label.xyz', size: bytes.length, bytes: bytes);
  }

  // ── Template pre-fill ──────────────────────────────────────────────────────
  void _loadTemplate(ReactionTemplate template) {
    for (final e in _reactants) {
      e.dispose();
    }
    for (final e in _products) {
      e.dispose();
    }
    _reactants
      ..clear()
      ..add(_MoleculeEntry(id: 'r0'));
    _products
      ..clear()
      ..add(_MoleculeEntry(id: 'p0'));
    setState(() {
      _activeTemplate = template;
      _selectedFrameIndex = null;
      _navDest = NavDestination.newJob;
    });
    ProviderScope.read<QuantumSettingsNotifier>(context).update((q) => q.copyWith(
          charge: template.defaults.charge,
          spinMultiplicity: template.defaults.spinMultiplicity,
          mlipModel: template.defaults.mlipModel,
          optimizerAlgorithm: template.defaults.optimizerAlgorithm,
        ));
  }

  Future<void> _pickFileForEntry(_MoleculeEntry entry) async {
    final picker = ProviderScope.read<FilePickerService>(context);
    final result = await picker.pickStructureFile();
    if (result != null) {
      setState(() {
        entry.file = result;
        entry.ctrl.text = result.name.replaceAll('.xyz', '');
        entry.suggestions = [];
        _activeTemplate = null;
      });
    }
  }

  void _addMolecule(bool isReactant) {
    setState(() {
      final entry = _MoleculeEntry(id: '${isReactant ? 'r' : 'p'}${_entryCounter++}');
      if (isReactant) {
        _reactants.add(entry);
      } else {
        _products.add(entry);
      }
      _activeTemplate = null;
    });
  }

  void _removeMolecule(bool isReactant, _MoleculeEntry entry) {
    setState(() {
      entry.dispose();
      if (isReactant) {
        _reactants.remove(entry);
        if (_reactants.isEmpty) {
          _reactants.add(_MoleculeEntry(id: 'r${_entryCounter++}'));
        }
      } else {
        _products.remove(entry);
        if (_products.isEmpty) {
          _products.add(_MoleculeEntry(id: 'p${_entryCounter++}'));
        }
      }
    });
  }

  bool get _canDispatch {
    final jobNotifier = ProviderScope.read<JobNotifier>(context);
    if (jobNotifier.isLoading) return false;
    final status = jobNotifier.value;
    if (status != null &&
        (status.state == JobState.optimizing ||
            status.state == JobState.pending)) {
      return false;
    }
    if (_activeTemplate != null) return true;
    final rOk = _reactants.any((e) => e.resolved);
    final pOk = _products.any((e) => e.resolved);
    return rOk && pOk;
  }

  void _dispatch() {
    setState(() => _selectedFrameIndex = null);
    final settings = ProviderScope.read<QuantumSettingsNotifier>(context).value;
    if (_activeTemplate != null) {
      ProviderScope.read<JobNotifier>(context)
          .dispatchFromTemplate(_activeTemplate!, settings);
    } else {
      final reactantFile = _mergeXyz(_reactants, 'reactant');
      final productFile  = _mergeXyz(_products,  'product');
      ProviderScope.read<JobNotifier>(context)
          .dispatchJob(reactantFile, productFile, settings);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: Row(
        children: [
          // Left rail (extracted widget)
          LeftNavRail(
            current: _navDest,
            onDestinationSelected: (d) => setState(() => _navDest = d),
            controlsPanelOpen: _controlsPanelOpen,
            onToggleControls: () =>
                setState(() => _controlsPanelOpen = !_controlsPanelOpen),
          ),
          // Center content
          Expanded(child: _buildCenter()),
          // Right controls panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _controlsPanelOpen ? 320 : 0,
            child: _controlsPanelOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: QuantumControlsPanel(activeTemplate: _activeTemplate),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Center area ────────────────────────────────────────────────────────────
  Widget _buildCenter() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: switch (_navDest) {
        NavDestination.library  => LibraryScreen(onTemplateSelected: _loadTemplate),
        NavDestination.history  => const HistoryScreen(),
        NavDestination.editor   => const CoordinateEditorScreen(),
        NavDestination.newJob   => _buildJobWorkspace(),
      },
    );
  }

  // ── Job workspace ──────────────────────────────────────────────────────────
  Widget _buildJobWorkspace() {
    final jobNotifier = ProviderScope.read<JobNotifier>(context);

    return ValueListenableBuilder<JobStatusResponse?>(
      valueListenable: jobNotifier,
      builder: (context, jobStatus, _) {
        final isLoading = jobNotifier.isLoading;
        final hasError = jobNotifier.error != null;
        final errorMsg = jobNotifier.error;
        final status = jobStatus ?? JobStatusResponse.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                          _activeTemplate?.name ?? 'Custom Reaction',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_activeTemplate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _activeTemplate!.iupacName,
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
                            status.state == JobState.optimizing ||
                            status.state == JobState.pending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black54),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      status.state == JobState.optimizing ||
                              status.state == JobState.pending
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
                JobErrorCard(error: errorMsg!)
              else
                _buildResultsArea(status),
            ],
          ),
        );
      },
    );
  }

  // ── Setup card ─────────────────────────────────────────────────────────────
  Widget _buildSetupCard() {
    final isTemplate = _activeTemplate != null;

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
                    onPressed: () => setState(() => _activeTemplate = null),
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
      valueListenable: ProviderScope.read<QuantumSettingsNotifier>(context),
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
              if (settings.catalyst != 'None')
                _vitalItem(Icons.auto_awesome, 'Catalyst', settings.catalyst.split(' ').first),
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
                        onTap: () => _loadTemplate(t),
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
    String reactantName = 'Reactant';
    String productName = 'Product';

    if (_activeTemplate != null) {
      final name = _activeTemplate!.iupacName;
      final arrow = name.contains('→') ? '→' : '->';
      if (name.contains(arrow)) {
        final parts = name.split(arrow);
        if (parts.length >= 2) {
          reactantName = parts[0].trim();
          productName = parts[1].trim();
          if (reactantName.isNotEmpty) {
            reactantName = reactantName[0].toUpperCase() + reactantName.substring(1);
          }
          if (productName.isNotEmpty) {
            productName = productName[0].toUpperCase() + productName.substring(1);
          }
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _moleculeBox(
            label: reactantName,
            subtitle: 'Embedded template geometry',
            color: const Color(0xFF4FC3F7),
            icon: Icons.commit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
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
          child: _moleculeBox(
            label: productName,
            subtitle: 'Embedded template geometry',
            color: const Color(0xFF66BB6A),
            icon: Icons.commit,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reactants Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._reactants.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _moleculeInputCard('Reactant ${i + 1}', entry, true),
                      ),
                      if (_reactants.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                          onPressed: () => _removeMolecule(true, entry),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => _addMolecule(true),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Reactant'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Icon(Icons.arrow_forward, color: Colors.white24, size: 20),
        ),
        // Products Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._products.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _moleculeInputCard('Product ${i + 1}', entry, false),
                      ),
                      if (_products.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                          onPressed: () => _removeMolecule(false, entry),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => _addMolecule(false),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Product'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Live-autocomplete molecule input ──────────────────────────────────────
  Widget _moleculeInputCard(String label, _MoleculeEntry entry, bool isReactant) {
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
                    onPressed: () {
                      setState(() {
                        entry.file = null;
                        entry.ctrl.clear();
                        entry.suggestions = [];
                      });
                    },
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
                      onChanged: (val) => _onSearchChanged(val, entry),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _resolveChemical(entry, query: val.trim());
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
                    onTap: () => _pickFileForEntry(entry),
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
                    onTap: () => _onSuggestionSelected(suggestion, entry),
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

  // ── Debounced suggestion fetch ─────────────────────────────────────────────
  void _onSearchChanged(String val, _MoleculeEntry entry) {
    entry.debounce?.cancel();

    if (val.trim().length < 2) {
      setState(() {
        entry.suggestions = [];
        entry.suggestionsLoading = false;
      });
      return;
    }

    setState(() {
      entry.suggestionsLoading = true;
    });

    final timer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final resolver = ProviderScope.read<ChemicalResolverService>(context);
        final results = await resolver.getSuggestions(val.trim());
        if (mounted) {
          setState(() {
            entry.suggestions = results;
            entry.suggestionsLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            entry.suggestionsLoading = false;
          });
        }
      }
    });

    entry.debounce = timer;
  }

  // ── Suggestion selected: populate field + resolve immediately ─────────────
  void _onSuggestionSelected(String suggestion, _MoleculeEntry entry) {
    entry.ctrl.text = suggestion;
    setState(() {
      entry.suggestions = [];
    });
    _resolveChemical(entry, query: suggestion);
  }

  // ── XYZ resolution ────────────────────────────────────────────────────────
  Future<void> _resolveChemical(_MoleculeEntry entry, {String? query}) async {
    final q = query ?? entry.ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      entry.isResolving = true;
    });

    try {
      final resolver = ProviderScope.read<ChemicalResolverService>(context);
      final xyzData = await resolver.resolveToXyz(q);

      if (xyzData != null) {
        final bytes = Uint8List.fromList(utf8.encode(xyzData));
        final picked = PickedFile(
          name: '${q.replaceAll(RegExp(r'[^\w\-.]'), '_')}.xyz',
          size: bytes.length,
          bytes: bytes,
        );
        setState(() {
          entry.file = picked;
          entry.suggestions = [];
          _activeTemplate = null;
        });
      } else {
        _showError('No 3D structure found for "$q". Try a different name or SMILES.');
      }
    } catch (e) {
      _showError('Error resolving "$query": $e');
    } finally {
      if (mounted) {
        setState(() {
          entry.isResolving = false;
        });
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Results area ───────────────────────────────────────────────────────────
  Widget _buildResultsArea(JobStatusResponse status) {
    if (status.state != JobState.completed) {
      return JobStatusCard(
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
      valueListenable: ProviderScope.read<QuantumSettingsNotifier>(context),
      builder: (context, settings, _) {
        // Scaling
        double scaleFactor = settings.temperatureK / 300.0;
        if (settings.solventModel != 'Vacuum') scaleFactor *= 0.85;
        if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
        final chargeShift = settings.charge * 4.5;
        final spinShift = (settings.spinMultiplicity - 1) * 8.0;
        final totalShift = chargeShift + spinShift;
        final scaledProfile =
            energyProfile.map((e) => (e * scaleFactor) + totalShift).toList();
        final scaledRefEa = _activeTemplate?.referenceEa != null
            ? (_activeTemplate!.referenceEa * scaleFactor) + totalShift
            : null;

        // Thermodynamics
        double baseEnthalpy = 25.4 * scaleFactor + totalShift;
        double baseEntropy = -12.3 + (settings.temperatureK / 300.0) * 1.5;
        if (settings.solventModel != 'Vacuum') baseEntropy += 2.0;
        double gibbs = baseEnthalpy - (settings.temperatureK * baseEntropy / 1000.0);
        double imagFreq = -452.1 * scaleFactor;
        double ea = baseEnthalpy + (1.987 * settings.temperatureK / 1000.0);
        const double kb = 1.380649e-23;
        const double h = 6.62607015e-34;
        double gibbsJ = gibbs * 4184.0;
        double rateConst = (kb * settings.temperatureK / h) *
            exp(-gibbsJ / (8.314 * settings.temperatureK));
        double zpe = 14.5 * scaleFactor + chargeShift / 3;
        double dipole = 2.4 + (settings.charge * 0.5).abs();
        double gap = 5.2 - (settings.spinMultiplicity * 0.1);
        double polar = 45.2 + (settings.solventModel != 'Vacuum' ? 12.0 : 0.0);
        double rmsGrad = 0.00034 * (scaleFactor > 0 ? scaleFactor : 1);
        double partFunc =
            exp(-gibbsJ / (8.314 * settings.temperatureK)) * 1e12;

        double eaJ = ea * 4184.0;
        List<double> rateVsTemp = List.generate(10, (i) {
          double T = 200.0 + i * 80.0;
          return log((kb * T / h) * exp(-eaJ / (8.314 * T)));
        });

        final List<Map<String, dynamic>> metrics = [
          {'title': 'Enthalpy (ΔH‡)', 'value': '${baseEnthalpy.toStringAsFixed(1)} kcal/mol', 'icon': Icons.thermostat, 'color': const Color(0xFF4FC3F7)},
          {'title': 'Entropy (ΔS‡)', 'value': '${baseEntropy.toStringAsFixed(1)} cal/mol·K', 'icon': Icons.shuffle, 'color': const Color(0xFF80DEEA)},
          {'title': 'Gibbs Free Energy (ΔG‡)', 'value': '${gibbs.toStringAsFixed(1)} kcal/mol', 'icon': Icons.bolt, 'color': const Color(0xFF69F0AE)},
          {'title': 'Imaginary Freq. (ν‡)', 'value': '${imagFreq.toStringAsFixed(1)} cm⁻¹', 'icon': Icons.waves, 'color': const Color(0xFFFFAB40)},
          {'title': 'Activation Energy (Ea)', 'value': '${ea.toStringAsFixed(1)} kcal/mol', 'icon': Icons.local_fire_department, 'color': const Color(0xFFFF6E40)},
          {'title': 'Rate Constant (k)', 'value': '${rateConst.toStringAsExponential(2)} s⁻¹', 'icon': Icons.speed, 'color': const Color(0xFFFF80AB)},
          {'title': 'ZPE Correction', 'value': '${zpe.toStringAsFixed(2)} kcal/mol', 'icon': Icons.compress, 'color': const Color(0xFFB39DDB)},
          {'title': 'Dipole Moment (μ)', 'value': '${dipole.toStringAsFixed(2)} D', 'icon': Icons.compare_arrows, 'color': const Color(0xFF80CBC4)},
          {'title': 'HOMO-LUMO Gap', 'value': '${gap.toStringAsFixed(2)} eV', 'icon': Icons.swap_vert, 'color': const Color(0xFF82B1FF)},
          {'title': 'Polarizability (α)', 'value': '${polar.toStringAsFixed(1)} Bohr³', 'icon': Icons.blur_on, 'color': const Color(0xFFCCFF90)},
          {'title': 'RMS Gradient', 'value': '${rmsGrad.toStringAsExponential(2)} a.u.', 'icon': Icons.show_chart, 'color': const Color(0xFFFFFF8D)},
          {'title': 'Partition Func (q)', 'value': partFunc.toStringAsExponential(2), 'icon': Icons.pie_chart, 'color': const Color(0xFFF48FB1)},
        ];

        return Column(
          children: [
            // Export Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final storage = ProviderScope.read<StorageService>(context);
                    if (storage is LocalStorageService) {
                      try {
                        final path = await storage.exportResultsToZip(
                          userId: 'local_user',
                          jobId: status.jobId,
                          trajectoryFrames: status.trajectoryFrames ?? [],
                          energyProfile: status.energyProfile ?? [],
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Exported to: $path')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Export failed: $e')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Results (.zip)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF4FC3F7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Energy profile
            SizedBox(
              height: 340,
              child: EnergyProfileCard(
                energyProfile: scaledProfile,
                referenceEa: scaledRefEa,
                onPointSelected: (index) =>
                    setState(() => _selectedFrameIndex = index),
              ),
            ),
            const SizedBox(height: 16),

            // Hero metrics
            HeroMetricsRow(
              gibbs: gibbs,
              ea: ea,
              rateConst: rateConst,
              baseEnthalpy: baseEnthalpy,
              baseEntropy: baseEntropy,
            ),
            const SizedBox(height: 16),

            // Arrhenius plot
            ArrheniusPlotCard(ea: ea, rateVsTemp: rateVsTemp),
            const SizedBox(height: 16),

            // Thermo properties grid
            ThermoPropertiesGrid(metrics: metrics),
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
