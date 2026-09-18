// ============================================================================
// Quantum Controls Panel — PhD researcher parameter control surface
// Right-rail collapsible panel with System / Optimizer / Analysis tabs
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

class QuantumControlsPanel extends StatefulWidget {
  final ReactionTemplate? activeTemplate;

  const QuantumControlsPanel({super.key, this.activeTemplate});

  @override
  State<QuantumControlsPanel> createState() =>
      _QuantumControlsPanelState();
}

class _QuantumControlsPanelState extends State<QuantumControlsPanel>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  static const _mlipModels = ['UMA-SM', 'UMA-Medium', 'MACE-MP-0', 'CHGNet', 'GFN2-xTB'];
  static const _solventModels = [
    'Vacuum',
    'PCM (H₂O)',
    'PCM (EtOH)',
    'PCM (MeOH)',
    'PCM (DMSO)',
    'PCM (THF)',
    'PCM (DCM)',
    'PCM (Toluene)',
    'PCM (Hexane)',
    'Onsager (ε=78.4)',
    'SMD (H₂O)',
    'SMD (DMSO)',
  ];
  static const _catalysts = [
    'None',
    // Transition metals
    'Pd(0)  — Oxidative addition',
    'Pd(II) — Reductive elimination',
    'Rh(I)  — Wilkinson',
    'Ru(II) — Grubbs 2nd gen',
    'Cu(I)  — CuAAC click',
    'Ni(0)  — Kumada coupling',
    'Ir(III)— C–H activation',
    // Organocatalysts
    'Proline (organocatalyst)',
    'NHC (N-heterocyclic carbene)',
    'Chiral BINAP-Rh',
    // Acids / Bases
    'BF₃ (Lewis acid)',
    'TiCl₄ (Lewis acid)',
    'KOH (base)',
    'LDA (strong base)',
    // Enzymes
    'Lipase B (enzyme)',
    'Cytochrome P450 (enzyme)',
  ];
  static const _algorithms = [
    'NEB-CI',
    'Growing String Method',
    'Dimer',
    'P-RFO'
  ];
  static const _convergences = ['Loose', 'Normal', 'Tight', 'Very Tight'];
  static const _exportFormats = ['XYZ', 'PDB', 'JSON'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ProviderScope.read<QuantumSettingsNotifier>(context);

    return ValueListenableBuilder<QuantumSettings>(
      valueListenable: notifier,
      builder: (context, settings, _) {
        return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              _buildPanelHeader(settings, notifier),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4FC3F7),
                labelColor: const Color(0xFF4FC3F7),
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'SYSTEM'),
                  Tab(text: 'OPTIMIZER'),
                  Tab(text: 'ANALYSIS'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSystemTab(settings, notifier),
                    _buildOptimizerTab(settings, notifier),
                    _buildAnalysisTab(settings, notifier),
                  ],
                ),
              ),
              if (widget.activeTemplate != null)
                _buildLiteratureRef(widget.activeTemplate!),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildPanelHeader(QuantumSettings s, QuantumSettingsNotifier n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.tune, color: Color(0xFF4FC3F7), size: 18),
          const SizedBox(width: 8),
          const Text(
            'Quantum Controls',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => n.update((_) => const QuantumSettings()),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SYSTEM TAB
  // ---------------------------------------------------------------------------
  Widget _buildSystemTab(QuantumSettings s, QuantumSettingsNotifier n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Electronic Structure'),
        const SizedBox(height: 12),

        // Charge spinner
        _labeledRow('Charge', Row(
          children: [
            _iconButton(Icons.remove, () {
              if (s.charge > -5) n.update((q) => q.copyWith(charge: q.charge - 1));
            }),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '${s.charge >= 0 ? '+' : ''}${s.charge}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _iconButton(Icons.add, () {
              if (s.charge < 5) n.update((q) => q.copyWith(charge: q.charge + 1));
            }),
          ],
        )),
        const SizedBox(height: 12),

        // Spin multiplicity
        _labeledRow('Spin Mult.', Row(
          children: [
            _iconButton(Icons.remove, () {
              if (s.spinMultiplicity > 1) {
                n.update((q) => q.copyWith(spinMultiplicity: q.spinMultiplicity - 1));
              }
            }),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '${s.spinMultiplicity}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _iconButton(Icons.add, () {
              if (s.spinMultiplicity < 7) {
                n.update((q) => q.copyWith(spinMultiplicity: q.spinMultiplicity + 1));
              }
            }),
          ],
        )),
        const SizedBox(height: 16),
        _sectionLabel('ML Potential'),
        const SizedBox(height: 12),

        // MLIP model dropdown
        _dropdownField(
          label: 'MLIP Model',
          value: s.mlipModel,
          items: _mlipModels,
          onChanged: (v) => n.update((q) => q.copyWith(mlipModel: v)),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Environment'),
        const SizedBox(height: 12),

        // Solvent
        _dropdownField(
          label: 'Solvent',
          value: s.solventModel,
          items: _solventModels,
          onChanged: (v) => n.update((q) => q.copyWith(solventModel: v)),
        ),
        const SizedBox(height: 16),

        // Temperature slider
        _labeledWidget(
          'Temperature',
          '${s.temperatureK.toStringAsFixed(0)} K',
          Slider(
            value: s.temperatureK,
            min: 100,
            max: 1000,
            divisions: 90,
            activeColor: const Color(0xFF4FC3F7),
            inactiveColor: Colors.white12,
            onChanged: (v) => n.update((q) => q.copyWith(temperatureK: v)),
          ),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Catalyst'),
        const SizedBox(height: 10),
        // Catalyst picker
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: s.catalyst == 'None'
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFFFAB40).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: s.catalyst == 'None'
                          ? Colors.white38
                          : const Color(0xFFFFAB40),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Catalyst',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (s.catalyst != 'None')
                      InkWell(
                        onTap: () =>
                            n.update((q) => q.copyWith(catalyst: 'None')),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 9)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _catalysts.contains(s.catalyst) ? s.catalyst : 'None',
                      dropdownColor: const Color(0xFF1C2E3A),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      isExpanded: true,
                      items: _catalysts.map((c) {
                        final isNone = c == 'None';
                        return DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: TextStyle(
                              color: isNone ? Colors.white38 : Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          n.update((q) => q.copyWith(catalyst: v ?? 'None')),
                    ),
                  ),
                ),
              ),
              if (s.catalyst != 'None')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFAB40).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFFFAB40).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFFFFAB40), size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Catalyst included in NEB path. Energy profile accounts for catalytic cycle.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 9,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Credentials'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: s.hfToken,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          obscureText: true,
          decoration: _inputDecoration('Hugging Face API Token'),
          onChanged: (v) => n.update((q) => q.copyWith(hfToken: v)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OPTIMIZER TAB
  // ---------------------------------------------------------------------------
  Widget _buildOptimizerTab(QuantumSettings s, QuantumSettingsNotifier n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Algorithm'),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Method',
          value: s.optimizerAlgorithm,
          items: _algorithms,
          onChanged: (v) => n.update((q) => q.copyWith(optimizerAlgorithm: v)),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Advanced Optimization'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automated Conformational Search', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Run MMFF94 sweep prior to DFT.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: s.conformationalSearch,
              onChanged: (v) => n.update((q) => q.copyWith(conformationalSearch: v)),
              activeTrackColor: const Color(0xFF4FC3F7),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // NEB Images (only shown for NEB)
        if (s.optimizerAlgorithm == 'NEB-CI') ...[
          _labeledWidget(
            'NEB Images',
            '${s.nebImages}',
            Slider(
              value: s.nebImages.toDouble(),
              min: 5,
              max: 30,
              divisions: 25,
              activeColor: const Color(0xFF4FC3F7),
              inactiveColor: Colors.white12,
              onChanged: (v) => n.update((q) => q.copyWith(nebImages: v.round())),
            ),
          ),
          const SizedBox(height: 8),
          _labeledWidget(
            'Spring Constant',
            '${s.springConstant.toStringAsFixed(2)} eV/Å²',
            Slider(
              value: s.springConstant,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              activeColor: const Color(0xFF4FC3F7),
              inactiveColor: Colors.white12,
              onChanged: (v) => n.update((q) => q.copyWith(springConstant: v)),
            ),
          ),
          const SizedBox(height: 8),
        ],

        _sectionLabel('Convergence'),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Threshold',
          value: s.convergence,
          items: _convergences,
          onChanged: (v) => n.update((q) => q.copyWith(convergence: v)),
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'DMF Convergence',
          value: s.dmfConvergence,
          items: const ['Loose', 'Normal', 'Tight'],
          onChanged: (v) => n.update((q) => q.copyWith(dmfConvergence: v)),
        ),
        const SizedBox(height: 16),

        _labeledWidget(
          'Max Steps',
          '${s.maxSteps}',
          Slider(
            value: s.maxSteps.toDouble(),
            min: 50,
            max: 2000,
            divisions: 39,
            activeColor: const Color(0xFF4FC3F7),
            inactiveColor: Colors.white12,
            onChanged: (v) => n.update((q) => q.copyWith(maxSteps: v.round())),
          ),
        ),
        const SizedBox(height: 8),
        _labeledWidget(
          'nmove',
          '${s.nmove}',
          Slider(
            value: s.nmove.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            activeColor: const Color(0xFF4FC3F7),
            inactiveColor: Colors.white12,
            onChanged: (v) => n.update((q) => q.copyWith(nmove: v.round())),
          ),
        ),
        const SizedBox(height: 8),
        _switchRow(
          'Update Teval',
          s.updateTeval,
          (v) => n.update((q) => q.copyWith(updateTeval: v)),
        ),
        const SizedBox(height: 8),

        // Max force norm text field
        _sectionLabel('Force Criterion'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: s.maxForceNorm.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('Max Force Norm (eV/Å)'),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) n.update((q) => q.copyWith(maxForceNorm: parsed));
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYSIS TAB
  // ---------------------------------------------------------------------------
  Widget _buildAnalysisTab(QuantumSettings s, QuantumSettingsNotifier n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Thermochemistry'),
        const SizedBox(height: 12),
        _switchRow('ZPE Correction', s.zpeCorrection,
            (v) => n.update((q) => q.copyWith(zpeCorrection: v))),
        _switchRow('ΔH / ΔG at T', s.computeThermochemistry,
            (v) => n.update((q) => q.copyWith(computeThermochemistry: v))),
        const SizedBox(height: 16),

        _sectionLabel('Post-TS Analysis'),
        const SizedBox(height: 12),
        _switchRow('Intrinsic Reaction Coordinate (IRC)', s.runIrc,
            (v) => n.update((q) => q.copyWith(runIrc: v))),
        _switchRow('Frequency Analysis (ν‡)', s.frequencyAnalysis,
            (v) => n.update((q) => q.copyWith(frequencyAnalysis: v))),
        const SizedBox(height: 16),

        _sectionLabel('Export'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _exportFormats.map((fmt) {
            final selected = s.exportFormat == fmt;
            return ChoiceChip(
              label: Text(fmt),
              selected: selected,
              selectedColor: const Color(0xFF4FC3F7).withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF4FC3F7) : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF4FC3F7)
                    : Colors.white.withValues(alpha: 0.15),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              onSelected: (_) => n.update((q) => q.copyWith(exportFormat: fmt)),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LITERATURE REFERENCE
  // ---------------------------------------------------------------------------
  Widget _buildLiteratureRef(ReactionTemplate t) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, color: Colors.amber.shade300, size: 14),
              const SizedBox(width: 6),
              Text(
                'Literature Reference',
                style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ΔE‡ = ${t.referenceEa} kcal/mol',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            t.journalRef,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 2),
          SelectableText(
            'DOI: ${t.doi}',
            style: TextStyle(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  Widget _labeledRow(String label, Widget trailing) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          ),
          trailing,
        ],
      );

  Widget _labeledWidget(String label, String value, Widget control) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              ),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          control,
        ],
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF4FC3F7),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF1A2E3A),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        iconEnabledColor: const Color(0xFF4FC3F7),
        decoration: _inputDecoration(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  Widget _iconButton(IconData icon, VoidCallback onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
