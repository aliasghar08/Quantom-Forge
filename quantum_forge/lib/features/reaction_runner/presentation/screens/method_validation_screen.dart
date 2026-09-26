// ============================================================================
// Method validation screen
// ----------------------------------------------------------------------------
// "How well does MLIP reproduce known barriers?" — the question a reviewer asks
// first. Each reference has a literature barrier; running it through the backend
// reports the MLIP value, the signed error and the percentage error.
//
// The literature values are single numbers with a level of theory attached; they
// are not uncertainty-weighted, and a real validation would need several
// references per class. Treat this as a first-pass sanity check, not a
// benchmarking study.
// ============================================================================

import 'package:flutter/material.dart';

import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/state/settings_provider.dart';

/// One reference reaction with a literature barrier.
class ValidationReference {
  final String name;
  final String note;

  /// kcal/mol at the level named in [source].
  final double literatureEa;
  final String source;
  final String reactantXyz;
  final String productXyz;

  const ValidationReference({
    required this.name,
    required this.note,
    required this.literatureEa,
    required this.source,
    required this.reactantXyz,
    required this.productXyz,
  });
}

/// Five small, genuinely single-saddle reactions.
///
/// Atom ordering is IDENTICAL between reactant and product in every entry: DMF's
/// FB-ENM interpolation matches atoms by index, so a reordered product silently
/// compares the wrong atoms. (HCN→HNC is the easy one to get wrong — HCN is
/// H-C≡N and HNC is H-N≡C, so both are written C, N, H.)
const List<ValidationReference> kValidationReferences = [
  ValidationReference(
    name: 'NH3 umbrella inversion',
    note: '4 atoms · planar D3h saddle',
    literatureEa: 5.8,
    source: 'experimental inversion barrier',
    reactantXyz: '4\nNH3 pyramidal\n'
        'N 0.0000 0.0000 0.1173\nH 0.0000 0.9397 -0.2739\n'
        'H 0.8137 -0.4698 -0.2739\nH -0.8137 -0.4698 -0.2739\n',
    productXyz: '4\nNH3 inverted\n'
        'N 0.0000 0.0000 -0.1173\nH 0.0000 0.9397 0.2739\n'
        'H 0.8137 -0.4698 0.2739\nH -0.8137 -0.4698 0.2739\n',
  ),
  ValidationReference(
    name: 'HCN → HNC isomerization',
    note: '3 atoms · bent saddle',
    literatureEa: 48.0,
    source: 'CCSD(T)/CBS, ~48 kcal/mol',
    reactantXyz: '3\nHCN\nC 0.0000 0.0000 0.0000\nN 0.0000 0.0000 1.1560\n'
        'H 0.0000 0.0000 -1.0660\n',
    productXyz: '3\nHNC (same C,N,H order)\nC 0.0000 0.0000 2.1630\n'
        'N 0.0000 0.0000 0.9940\nH 0.0000 0.0000 0.0000\n',
  ),
  ValidationReference(
    name: 'H2 + F → H + HF',
    note: '3 atoms · linear H-H-F saddle',
    literatureEa: 1.7,
    source: 'classic benchmark, ~1.7 kcal/mol',
    reactantXyz: '3\nH2 + F\nH 0.0000 0.0000 -0.7400\nH 0.0000 0.0000 0.0000\n'
        'F 0.0000 0.0000 2.2000\n',
    productXyz: '3\nH + HF (same H,H,F order)\nH 0.0000 0.0000 0.9200\n'
        'H 0.0000 0.0000 1.7000\nF 0.0000 0.0000 0.0000\n',
  ),
  ValidationReference(
    name: 'SN2: Cl⁻ + CH3Br',
    note: '6 atoms · trigonal-bipyramidal saddle',
    literatureEa: 13.0,
    source: 'gas-phase CCSD(T), ~13 kcal/mol',
    reactantXyz: '6\nCl- + CH3Br\nCl 0.0000 0.0000 -2.4000\n'
        'C 0.0000 0.0000 0.0000\nH 0.0000 0.9500 0.3500\n'
        'H 0.8200 -0.4800 0.3500\nH -0.8200 -0.4800 0.3500\n'
        'Br 0.0000 0.0000 1.9500\n',
    productXyz: '6\nCH3Cl + Br- (same order)\nCl 0.0000 0.0000 -1.9000\n'
        'C 0.0000 0.0000 0.0000\nH 0.0000 0.9500 -0.3500\n'
        'H 0.8200 -0.4800 -0.3500\nH -0.8200 -0.4800 -0.3500\n'
        'Br 0.0000 0.0000 2.4500\n',
  ),
  ValidationReference(
    name: 'H2O2 torsion (trans → cis)',
    note: '4 atoms · torsional saddle',
    literatureEa: 7.0,
    source: 'experimental trans barrier, ~7 kcal/mol',
    reactantXyz: '4\ntrans-H2O2\nO 0.0000 0.0000 0.0000\n'
        'O 0.0000 0.0000 1.4750\nH 0.9000 0.0000 -0.4000\n'
        'H -0.9000 0.0000 1.8750\n',
    productXyz: '4\ncis-H2O2 (same order)\nO 0.0000 0.0000 0.0000\n'
        'O 0.0000 0.0000 1.4750\nH 0.9000 0.0000 -0.4000\n'
        'H 0.9000 0.0000 1.8750\n',
  ),
];

class ValidationResult {
  final ValidationReference reference;
  final double? mlipEa;
  final String? error;
  const ValidationResult({required this.reference, this.mlipEa, this.error});

  double? get signedError =>
      mlipEa == null ? null : mlipEa! - reference.literatureEa;
  double? get percentError => signedError == null || reference.literatureEa == 0
      ? null
      : signedError! / reference.literatureEa * 100.0;
  bool get withinChemicalAccuracy =>
      signedError != null && signedError!.abs() <= 1.0;
}

class MethodValidationScreen extends StatefulWidget {
  final String backendUrl;
  final QuantumSettings settings;

  const MethodValidationScreen({
    super.key,
    required this.backendUrl,
    required this.settings,
  });

  @override
  State<MethodValidationScreen> createState() => _MethodValidationScreenState();
}

class _MethodValidationScreenState extends State<MethodValidationScreen> {
  final Map<String, ValidationResult> _results = {};
  bool _running = false;
  String? _current;

  Future<void> _runOne(ValidationReference ref) async {
    if (widget.backendUrl.trim().isEmpty) return;
    setState(() {
      _running = true;
      _current = ref.name;
    });
    final service = const BackendComputeService();
    try {
      final id = await service.submit(
        widget.backendUrl,
        ref.reactantXyz,
        ref.productXyz,
        widget.settings,
      );
      final status = await service.poll(widget.backendUrl, id).last;
      final profile = status.energyProfile;
      if (status.state == ReactionState.error || profile == null || profile.isEmpty) {
        _results[ref.name] = ValidationResult(
          reference: ref,
          error: status.error ?? status.message ?? 'no energy profile returned',
        );
      } else {
        _results[ref.name] = ValidationResult(
          reference: ref,
          mlipEa: profile.reduce((a, b) => a > b ? a : b),
        );
      }
    } catch (e) {
      _results[ref.name] = ValidationResult(reference: ref, error: '$e');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _current = null;
        });
      }
    }
  }

  Future<void> _runAll() async {
    for (final ref in kValidationReferences) {
      if (!mounted) return;
      await _runOne(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    final done = _results.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Method validation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0D0D12),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Method validation',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Known barriers, computed with the same MLIP settings as your '
              'production runs. This is the table a reviewer asks for. Literature '
              'values are single numbers with a stated level of theory, not '
              'uncertainty-weighted benchmarks.',
              style: TextStyle(color: palette.textMuted, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (widget.backendUrl.trim().isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No compute backend configured — set the backend URL in Settings '
                  'to run the references.',
                  style: TextStyle(color: palette.warning, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _running || widget.backendUrl.trim().isEmpty
                      ? null
                      : _runAll,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(_running
                      ? 'Running${_current == null ? '' : ' ${_current!}'}… '
                          '($done/${kValidationReferences.length})'
                      : 'Run all ${kValidationReferences.length} references'),
                ),
                const SizedBox(width: 12),
                if (done > 0)
                  TextButton(
                    onPressed: _running ? null : () => setState(_results.clear),
                    child: const Text('Clear results'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _table(palette),
          ],
        ),
      ),
    );
  }

  Widget _table(QuantumTheme palette) {
    return Table(
      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.10)),
      columnWidths: const {
        0: FlexColumnWidth(3.0),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.0),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04)),
          children: const [
            _VCell('Reference reaction', bold: true),
            _VCell('Literature', bold: true),
            _VCell('MLIP', bold: true),
            _VCell('Error', bold: true),
            _VCell('Error %', bold: true),
            _VCell('', bold: true),
          ],
        ),
        for (final ref in kValidationReferences) ..._rows(ref, palette),
      ],
    );
  }

  List<TableRow> _rows(ValidationReference ref, QuantumTheme palette) {
    final r = _results[ref.name];
    final err = r?.signedError;
    final pct = r?.percentError;
    final good = r?.withinChemicalAccuracy ?? false;
    final color = r == null
        ? null
        : (r.error != null
            ? palette.danger
            : (good ? palette.success : palette.warning));

    return [
      TableRow(children: [
        _VCell('${ref.name}\n${ref.note}', muted: true),
        _VCell(ref.literatureEa.toStringAsFixed(1)),
        _VCell(r == null
            ? '—'
            : (r.error != null ? 'error' : r.mlipEa!.toStringAsFixed(1))),
        _VCell(err == null
            ? '—'
            : '${err >= 0 ? '+' : ''}${err.toStringAsFixed(1)}',
            color: color),
        _VCell(
            pct == null ? '—' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
            color: color),
        Padding(
          padding: const EdgeInsets.all(4),
          child: TextButton(
            onPressed: _running ? null : () => _runOne(ref),
            child: const Text('Run', style: TextStyle(fontSize: 11)),
          ),
        ),
      ]),
      if (r?.error != null)
        TableRow(children: [
          _VCell('⚠️ ${r!.error}', color: palette.danger, span: true),
          const _VCell(''), const _VCell(''), const _VCell(''),
          const _VCell(''), const _VCell(''),
        ]),
      if (r != null && r.error == null)
        TableRow(children: [
          _VCell(ref.source, muted: true, span: true),
          const _VCell(''), const _VCell(''), const _VCell(''),
          const _VCell(''), const _VCell(''),
        ]),
    ];
  }
}

class _VCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  final bool span;
  final Color? color;

  const _VCell(this.text,
      {this.bold = false, this.muted = false, this.span = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: color ??
              Colors.white.withValues(alpha: muted || span ? 0.55 : 0.88),
          fontSize: (muted || span) ? 10.5 : 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          height: 1.35,
        ),
      ),
    );
  }
}
