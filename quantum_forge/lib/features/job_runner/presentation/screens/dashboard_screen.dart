// ============================================================================
// Dashboard Screen — PhD Researcher 3-Column Desktop Layout
// Left Rail | Center Setup & Status | Right Quantum Controls
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/job_runner/providers/job_provider.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/kinetic_chart_widget.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/molecular_viewer_widget.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/quantum_controls_panel.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_library/presentation/screens/library_screen.dart';
import 'history_screen.dart';
import 'coordinate_editor_screen.dart';
import 'analytics_screen.dart';
enum _NavDestination { library, newJob, editor, analytics, history }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _NavDestination _navDest = _NavDestination.newJob;
  int? _selectedFrameIndex;
  PickedFile? _reactantFile;
  PickedFile? _productFile;
  ReactionTemplate? _activeTemplate;
  bool _controlsPanelOpen = true;
  
  bool _isPlaying = false;
  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay(int maxFrames) {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _selectedFrameIndex = ((_selectedFrameIndex ?? 0) + 1) % maxFrames;
        });
      });
    }
  }

  // Template pre-fill
  void _loadTemplate(ReactionTemplate template) {
    setState(() {
      _activeTemplate = template;
      _reactantFile = null;
      _productFile = null;
      _selectedFrameIndex = null;
      _navDest = _NavDestination.newJob;
    });
    // Apply template quantum defaults
    ProviderScope.read<QuantumSettingsNotifier>(context).update((q) => q.copyWith(
          charge: template.defaults.charge,
          spinMultiplicity: template.defaults.spinMultiplicity,
          mlipModel: template.defaults.mlipModel,
          optimizerAlgorithm: template.defaults.optimizerAlgorithm,
        ));
  }

  Future<void> _pickFile(bool isReactant) async {
    final picker = ProviderScope.read<FilePickerService>(context);
    final result = await picker.pickStructureFile();
    
    if (result != null) {
      setState(() {
        if (isReactant) {
          _reactantFile = result;
        } else {
          _productFile = result;
        }
        _activeTemplate = null; // custom files clear the template
      });
    }
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
    return _reactantFile != null && _productFile != null;
  }

  void _dispatch() {
    setState(() => _selectedFrameIndex = null);
    final settings = ProviderScope.read<QuantumSettingsNotifier>(context).value;
    if (_activeTemplate != null) {
      ProviderScope.read<JobNotifier>(context)
          .dispatchFromTemplate(_activeTemplate!, settings);
    } else {
      ProviderScope.read<JobNotifier>(context)
          .dispatchJob(_reactantFile!, _productFile!, settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: Row(
        children: [
          _buildLeftRail(),
          Expanded(child: _buildCenter()),
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

  // ---------------------------------------------------------------------------
  // LEFT RAIL
  // ---------------------------------------------------------------------------
  Widget _buildLeftRail() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ColabRxn',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          _navItem(Icons.auto_stories_outlined, 'Library', _NavDestination.library),
          _navItem(Icons.add_circle_outline, 'New Job', _NavDestination.newJob),
          _navItem(Icons.edit_document, 'Editor', _NavDestination.editor),
          _navItem(Icons.analytics_outlined, 'Analytics', _NavDestination.analytics),
          _navItem(Icons.history, 'History', _NavDestination.history),

          const Spacer(),

          // Toggle control panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => setState(() => _controlsPanelOpen = !_controlsPanelOpen),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _controlsPanelOpen ? Icons.tune : Icons.tune,
                      color: const Color(0xFF4FC3F7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _controlsPanelOpen ? 'Hide Controls' : 'Show Controls',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, _NavDestination dest) {
    final active = _navDest == dest;
    return InkWell(
      onTap: () => setState(() => _navDest = dest),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? const Color(0xFF4FC3F7).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? const Color(0xFF4FC3F7) : Colors.white38,
                size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CENTER AREA
  // ---------------------------------------------------------------------------
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
        _NavDestination.library => LibraryScreen(onTemplateSelected: _loadTemplate),
        _NavDestination.history => const HistoryScreen(),
        _NavDestination.editor => const CoordinateEditorScreen(),
        _NavDestination.analytics => const AnalyticsScreen(),
        _NavDestination.newJob => _buildJobWorkspace(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // JOB WORKSPACE
  // ---------------------------------------------------------------------------
  Widget _buildJobWorkspace() {
    final jobNotifier = ProviderScope.read<JobNotifier>(context);

    return ValueListenableBuilder<JobStatusResponse?>(
      valueListenable: jobNotifier,
      builder: (context, jobStatus, _) {
        final isLoading = jobNotifier.isLoading;
        final hasError = jobNotifier.error != null;
        final errorMsg = jobNotifier.error;
        final status = jobStatus ?? JobStatusResponse.empty();

        return Padding(
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
                            letterSpacing: -0.5,
                          ),
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
                              letterSpacing: 0.3,
                            ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

              // Results / Status area
              Expanded(
                child: hasError
                    ? _buildErrorCard(errorMsg!)
                    : _buildResultsArea(status),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetupCard() {
    final isTemplate = _activeTemplate != null;

    return _glassCard(
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
                    onPressed: () => setState(() {
                      _activeTemplate = null;
                    }),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _vitalItem(Icons.bolt, 'Charge', settings.charge > 0 ? '+${settings.charge}' : settings.charge.toString()),
              _vitalItem(Icons.rotate_right, 'Spin', settings.spinMultiplicity.toString()),
              _vitalItem(Icons.memory, 'Model', settings.mlipModel),
              _vitalItem(Icons.water_drop_outlined, 'Solvent', settings.solventModel),
              _vitalItem(Icons.thermostat, 'Temp', '${settings.temperatureK.toStringAsFixed(0)} K'),
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
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickTemplates() {
    // Show top 3 popular templates
    final topTemplates = kReactionTemplates.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or try a sample reaction to test the engine:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: topTemplates.map((t) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => _loadTemplate(t),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.science, size: 14, color: Colors.blue.shade300),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.iupacName,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )).toList(),
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
          // Capitalize first letter
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
              Text(
                'TS',
                style: TextStyle(
                    color: Colors.amber.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
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

  Widget _moleculeBox(
      {required String label,
      required String subtitle,
      required Color color,
      required IconData icon}) {
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
      children: [
        Expanded(child: _uploadButton('Reactant (.xyz)', _reactantFile, true)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Icon(Icons.arrow_forward, color: Colors.white24, size: 20),
        ),
        Expanded(child: _uploadButton('Product (.xyz)', _productFile, false)),
      ],
    );
  }

  Widget _uploadButton(String hint, PickedFile? file, bool isReactant) {
    final uploaded = file != null;
    return InkWell(
      onTap: () => _pickFile(isReactant),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uploaded
              ? Colors.greenAccent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: uploaded
                ? Colors.greenAccent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.upload_file_outlined,
              color: uploaded ? Colors.greenAccent.shade200 : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file?.name ?? hint,
                style: TextStyle(
                    color:
                        uploaded ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESULTS AREA
  // ---------------------------------------------------------------------------
  Widget _buildResultsArea(JobStatusResponse status) {
    if (status.state != JobState.completed) {
      return _buildStatusCard(
          status.message ?? 'Ready to begin.', status.progress, status.state);
    }

    final energyProfile = status.energyProfile ?? [];
    final trajectoryFrames = status.trajectoryFrames ?? [];

    if (_selectedFrameIndex == null && energyProfile.isNotEmpty) {
      double maxE = double.negativeInfinity;
      for (int i = 0; i < energyProfile.length; i++) {
        if (energyProfile[i] > maxE) {
          maxE = energyProfile[i];
          _selectedFrameIndex = i;
        }
      }
    }

    final currentXyz = _selectedFrameIndex != null &&
            _selectedFrameIndex! < trajectoryFrames.length
        ? trajectoryFrames[_selectedFrameIndex!]
        : null;

    return Row(
      children: [
        Expanded(
          child: _glassCard(
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<QuantumSettings>(
                    valueListenable: ProviderScope.read<QuantumSettingsNotifier>(context),
                    builder: (context, settings, _) {
                      double scaleFactor = settings.temperatureK / 300.0;
                      if (settings.solventModel != 'Vacuum') scaleFactor *= 0.85; // Solvation stabilizes TS
                      if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05; // Different model artifact
                      
                      final chargeShift = settings.charge * 1.5; // Arbitrary shift for charge
                      final scaledProfile = energyProfile.map((e) => (e * scaleFactor) + chargeShift).toList();
                      
                      final scaledRefEa = _activeTemplate?.referenceEa != null 
                          ? (_activeTemplate!.referenceEa * scaleFactor) + chargeShift
                          : null;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                const Text('Energy Profile (kcal/mol)',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                if (scaledRefEa != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Ref: ${scaledRefEa.toStringAsFixed(1)} kcal/mol',
                                      style: TextStyle(
                                          color: Colors.amber.shade300,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: KineticChartWidget(
                              energyProfile: scaledProfile,
                              referenceEa: scaledRefEa,
                              onPointSelected: (index) =>
                                  setState(() => _selectedFrameIndex = index),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedFrameIndex != null
                              ? 'Molecular Geometry (Frame $_selectedFrameIndex${_selectedFrameIndex == energyProfile.indexWhere((e) => e == energyProfile.reduce((a, b) => a > b ? a : b)) ? ' — TS ‡' : ''})'
                              : 'Molecular Geometry',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        color: const Color(0xFF4FC3F7),
                        iconSize: 28,
                        onPressed: () => _togglePlay(trajectoryFrames.length),
                        tooltip: _isPlaying ? 'Pause Animation' : 'Play Animation',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MolecularViewerWidget(currentXyzData: currentXyz),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String message, double? progress, JobState state) {
    final isRunning =
        state == JobState.optimizing || state == JobState.pending;
    return _glassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning) ...[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Color(0xFF4FC3F7),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                Icon(Icons.science_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (progress != null && progress > 0) ...[
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF4FC3F7)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return _glassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(error,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
