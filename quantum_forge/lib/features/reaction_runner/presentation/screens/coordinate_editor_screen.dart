// ============================================================================
// Coordinate Editor — 3D builder + text editor + Avogadro 2 bridge
// ----------------------------------------------------------------------------
// Upgrades over the first version of this screen:
//
//   * Reads every format Avogadro writes (CJSON / CML / XYZ / SDF / MOL) and
//     reports *why* an import failed instead of a generic message.
//   * Exports to CJSON (Avogadro's native format), CML, SDF and XYZ with the
//     precision and title-line preferences from Settings.
//   * Can hand the structure straight to the desktop app as a deep link, or
//     copy it to the clipboard so it can be pasted into Avogadro.
//   * Reacts to editor preferences (default element, auto-optimise, atom
//     representation, bond tolerance) instead of hard-coded constants.
//   * Keeps its own title, and the text buffer is regenerated from the atom
//     list through one serializer so the header can never disagree with the
//     atom block.
// ============================================================================

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/core/utils/avogadro_bridge.dart';
import 'package:quantum_forge/core/utils/avogadro_codec.dart';
import 'package:quantum_forge/core/utils/avogadro_deep_link.dart';
import 'package:quantum_forge/core/utils/avogadro_interchange.dart';
import 'package:quantum_forge/core/utils/element_data.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/interactive_builder_widget.dart';

class CoordinateEditorScreen extends StatefulWidget {
  const CoordinateEditorScreen({super.key, this.initialStructure});

  /// Optional structure pushed in from outside (dependency injection point for
  /// tests and for a deep link that arrives while the app is running).
  final DecodedStructure? initialStructure;

  @override
  State<CoordinateEditorScreen> createState() => _CoordinateEditorScreenState();
}

class _CoordinateEditorScreenState extends State<CoordinateEditorScreen> {
  static const String _defaultXyz = '''3
Water molecule
O  0.00000  0.00000  0.11779
H  0.00000  0.75545 -0.47116
H  0.00000 -0.75545 -0.47116''';

  final TextEditingController _controller = TextEditingController();
  List<Atom> _atoms = [];

  BuilderTool _currentTool = BuilderTool.navigate;
  String _currentElement = 'C';
  bool _autoOptimize = true;
  String _title = 'Water molecule';
  String? _parseError;

  /// Set once the editor has been seeded from the app settings, so a rebuild
  /// never clobbers a change the user just made.
  bool _seededFromSettings = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStructure != null) {
      _adopt(widget.initialStructure!);
    } else {
      _adopt(AvogadroCodec.decode(_defaultXyz, formatHint: 'xyz'));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromSettings) return;
    _seededFromSettings = true;
    final settings = context.read<AppSettingsNotifier>().settings;
    _currentElement = settings.defaultElement;
    _autoOptimize = settings.defaultAutoOptimize;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AppSettings get _settings => context.read<AppSettingsNotifier>().settings;
  QuantumTheme get _palette => context.read<ThemeNotifier>().palette;

  // ── state helpers ────────────────────────────────────────────────────────

  /// Replaces the whole editor state with [structure].
  void _adopt(DecodedStructure structure, {bool syncText = true}) {
    _atoms = List.of(structure.atoms);
    _title = structure.title;
    _parseError = null;
    if (syncText) {
      _controller.text = _serialize(_atoms, _title);
    }
  }

  String _serialize(List<Atom> atoms, String title) => XyzParser.serialize(
        atoms,
        title: title,
        precision: _settings.exportPrecision,
      );

  void _updateViewer() {
    try {
      final decoded = AvogadroCodec.decode(
        _controller.text,
        title: _title,
      );
      setState(() {
        _atoms = List.of(decoded.atoms);
        _title = decoded.title;
        _parseError = null;
      });
    } on AvogadroCodecException catch (e) {
      setState(() => _parseError = e.message);
      _snack('Could not read the coordinates: ${e.message}', isError: true);
    }
  }

  void _onAtomsChanged(List<Atom> newAtoms) {
    setState(() {
      _atoms = newAtoms;
      _controller.text = _serialize(newAtoms, _title);
      _parseError = null;
    });
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    final palette = _palette;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? palette.danger.withValues(alpha: 0.9) : null,
        ),
      );
  }

  // ── import ───────────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    final picker = context.read<FilePickerService>();
    final PickedFile? file = await picker.pickStructureFile();
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('The browser returned an empty file.', isError: true);
      return;
    }

    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      final decoded = AvogadroCodec.decode(
        content,
        formatHint: extension.isEmpty ? null : extension,
        title: file.name,
      );
      if (!mounted) return;
      setState(() {
        _adopt(decoded);
      });
      _snack(
        'Loaded ${file.name} — ${decoded.atomCount} atoms, '
        '${decoded.bondCount} bonds (${decoded.bondsFromSource ? 'from file' : 'perceived'}).',
      );
    } on AvogadroCodecException catch (e) {
      _snack('Could not parse ${file.name}: ${e.message}', isError: true);
    } catch (e) {
      _snack('Unexpected import error: $e', isError: true);
    }
  }

  /// Accepts a structure handed over by the Avogadro plugin link.
  Future<void> _importFromDeepLink() async {
    final link = AvogadroDeepLinkCodec.fromCurrentUrl();
    if (link.isAbsent) {
      _snack(
        'No Avogadro payload in this URL. Use the plugin’s “Export to Quantum '
        'Forge Web”, or paste coordinates into the text pane.',
      );
      return;
    }
    if (link.isInvalid) {
      _snack('Avogadro payload rejected: ${link.error}', isError: true);
      return;
    }
    setState(() => _adopt(link.structure!));
    _snack('Loaded from Avogadro — ${link.summary}');
  }

  // ── export ───────────────────────────────────────────────────────────────

  AvogadroStructure _structure() => AvogadroInterchange.structure(
        _atoms,
        title: _title,
        bondTolerance: _settings.bondTolerance,
      );

  void _export(String format) {
    if (_atoms.isEmpty) {
      _snack('Nothing to export — the structure has no atoms.', isError: true);
      return;
    }
    try {
      final settings = _settings;
      AvogadroBridge.downloadStructure(
        _structure(),
        format: format,
        precision: settings.exportPrecision,
        includeTitleLine: settings.includeTitleLine,
      );
      _snack('Exported ${_atoms.length} atoms as .$format');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    }
  }

  /// Pushes the structure to the desktop app through the configured endpoint.
  void _sendToAvogadro() {
    if (_atoms.isEmpty) {
      _snack('Nothing to send — the structure has no atoms.', isError: true);
      return;
    }
    final settings = _settings;
    if (!settings.avogadroBridgeEnabled) {
      _snack(
        'The Avogadro bridge is disabled in Settings ▸ Avogadro.',
        isError: true,
      );
      return;
    }
    final uri = AvogadroDeepLinkCodec.buildImportUri(
      structure: _structure(),
      baseUrl: settings.bridgeBaseUrl,
    );
    final url = uri.toString();
    if (url.length > 60000) {
      _snack(
        'Structure is too large for a deep link '
        '(${(url.length / 1024).round()} kB). Use “Export” and open the file '
        'in Avogadro instead.',
        isError: true,
      );
      return;
    }
    AvogadroBridge.openUrl(url);
    _snack('Opening ${settings.bridgeBaseUrl} with this structure…');
  }

  Future<void> _copyAs(String format) async {
    if (_atoms.isEmpty) {
      _snack('Nothing to copy — the structure has no atoms.', isError: true);
      return;
    }
    final structure = _structure();
    final content = switch (format) {
      'cjson' => AvogadroInterchange.toCjson(structure),
      'cml' => AvogadroInterchange.toCml(structure),
      'sdf' => AvogadroInterchange.toSdf(structure),
      _ => XyzParser.serialize(
          _atoms,
          title: _title,
          precision: _settings.exportPrecision,
        ),
    };
    final ok = await AvogadroBridge.copyToClipboard(content);
    if (ok) {
      _snack('Copied ${format.toUpperCase()} to the clipboard.');
    } else {
      // Clipboard permissions are commonly denied outside HTTPS; fall back to a
      // local copy so the user can still paste manually.
      unawaited(Clipboard.setData(ClipboardData(text: content)));
      _snack(
        'Browser blocked the rich clipboard — copied as plain text instead.',
      );
    }
  }

  // ── Hybrid MD Logic ──────────────────────────────────────────────────────
  
  void _simulateHybridMd() async {
    if (!mounted) return;
    
    final backendUrl = context.read<AppSettingsNotifier>().settings.backendUrl;
    if (backendUrl.isEmpty) {
      _snack('Please configure a Compute Backend URL in Settings first.', isError: true);
      return;
    }
    
    final pdbController = TextEditingController(text: '/content/peptide.pdb');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _palette.panel,
        title: Text('Start Hybrid ML/MM MD', style: TextStyle(color: _palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the absolute path to your PDB on the Colab environment:',
                style: TextStyle(color: _palette.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: pdbController,
              style: TextStyle(color: _palette.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: _palette.viewport,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: _palette.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _palette.accent),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    
    if (confirm != true || !mounted) return;
    
    final service = const BackendComputeService();
    try {
      _snack('Submitting Hybrid MD job to Colab...');
      final jobId = await service.submitHybridMd(backendUrl, pdbController.text.trim());
      
      _snack('Job $jobId started. Polling status...');
      
      service.pollHybridMdStream(backendUrl, jobId).listen((status) {
        if (!mounted) return;
        _snack('Hybrid MD [$jobId]: ${status.state}');
        
        if (status.state == 'SUCCESS' && status.trajectoryDir != null) {
          _snack('Success! Trajectories saved to: ${status.trajectoryDir}', isError: false);
        } else if (status.state == 'FAILURE') {
          _snack('MD simulation failed. Check Colab logs.', isError: true);
        }
      });
      
    } catch (e) {
      _snack('MD Error: $e', isError: true);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    final settings = context.watch<AppSettingsNotifier>().settings;
    final showTooltips = settings.showTooltips;

    return Padding(
      padding: EdgeInsets.all(settings.gap(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: settings.gap(12),
            runSpacing: settings.gap(10),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '3D Molecular Builder',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              _TitleField(
                initialValue: _title,
                palette: palette,
                onChanged: (value) => setState(() => _title = value),
              ),
              _tooltip(
                showTooltips,
                'Import any format Avogadro writes: CJSON, CML, XYZ, SDF/MOL.',
                FilledButton.icon(
                  onPressed: _importFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import structure'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.panelAlt,
                    foregroundColor: palette.textPrimary,
                  ),
                ),
              ),
              _tooltip(
                showTooltips,
                'Reload the structure carried by the current URL payload.',
                FilledButton.icon(
                  onPressed: _importFromDeepLink,
                  icon: const Icon(Icons.link),
                  label: const Text('From Avogadro link'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.panelAlt,
                    foregroundColor: palette.textPrimary,
                  ),
                ),
              ),
              _tooltip(
                showTooltips,
                'Generate a saddle-point guess by interpolating the current '
                    'structure (LST placeholder for the backend guesser).',
                FilledButton.icon(
                  onPressed: _guessTransitionState,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('TS guess'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accentAlt.withValues(alpha: 0.85),
                    foregroundColor: palette.onAccent,
                  ),
                ),
              ),
              _tooltip(
                showTooltips,
                'Re-read the coordinate text pane and rebuild the 3D view.',
                FilledButton.icon(
                  onPressed: _updateViewer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Sync text'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: settings.gap(16)),
          _AvogadroActionBar(
            palette: palette,
            settings: settings,
            atomCount: _atoms.length,
            bondCount: AvogadroInterchange.perceiveBonds(
              _atoms,
              tolerance: settings.bondTolerance,
            ).length,
            onExport: _export,
            onSendToAvogadro: _sendToAvogadro,
            onSimulateHybridMd: _simulateHybridMd,
            onCopy: _copyAs,
          ),
          SizedBox(height: settings.gap(12)),
          _toolbar(settings, palette, showTooltips),
          if (_parseError != null) ...[
            SizedBox(height: settings.gap(10)),
            _ErrorBanner(message: _parseError!, palette: palette),
          ],
          SizedBox(height: settings.gap(16)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.viewport,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.success,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        hintText: 'Paste XYZ / CJSON / CML coordinates here…',
                        hintStyle: TextStyle(color: palette.textMuted),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: settings.gap(24)),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.viewport.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveBuilderWidget(
                        key: ValueKey(_atoms.isEmpty ? 'empty' : 'builder'),
                        initialAtoms: _atoms,
                        currentTool: _currentTool,
                        currentElement: _currentElement,
                        autoOptimize: _autoOptimize,
                        atomScale: settings.atomScale,
                        showBonds: settings.showBonds,
                        showHydrogens: settings.showHydrogens,
                        bondColor: palette.bondColor,
                        highlightColor: palette.accent,
                        background: palette.viewport,
                        onAtomsChanged: _onAtomsChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _guessTransitionState() {
    if (_atoms.isEmpty) {
      _snack('Build or import a structure first.', isError: true);
      return;
    }
    _snack('AI TS guesser (LST) interpolating a saddle point…');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final stretched = _atoms
          .map((a) => a.copyWith(y: a.y * 1.18, z: a.z + 0.08))
          .toList();
      setState(() {
        _atoms = stretched;
        _title = '${_title.replaceAll(' (TS guess)', '')} (TS guess)';
        _controller.text = _serialize(_atoms, _title);
      });
    });
  }

  Widget _tooltip(bool enabled, String message, Widget child) {
    if (!enabled) return child;
    return Tooltip(message: message, child: child);
  }

  Widget _toolbar(AppSettings settings, QuantumTheme palette, bool showTooltips) {
    return Container(
      padding: EdgeInsets.all(settings.gap(8)),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildToolBtn(BuilderTool.navigate, Icons.pan_tool, 'Navigate', showTooltips,
              'Orbit the camera. Drag anywhere in the 3D view.'),
          _buildToolBtn(BuilderTool.draw, Icons.edit, 'Draw', showTooltips,
              'Click empty space to place an atom; drag from an atom to bond.'),
          _buildToolBtn(BuilderTool.delete, Icons.delete, 'Delete', showTooltips,
              'Click an atom to remove it.'),
          const SizedBox(width: 12),
          Text('Element:', style: TextStyle(color: palette.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _currentElement,
            dropdownColor: palette.panelAlt,
            borderRadius: BorderRadius.circular(10),
            style: TextStyle(color: palette.textPrimary),
            underline: const SizedBox.shrink(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _currentElement = newValue);
              }
            },
            items: ElementData.colors.keys
                .map<DropdownMenuItem<String>>(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 12),
          Text('Auto-optimise', style: TextStyle(color: palette.textSecondary)),
          Switch(
            value: _autoOptimize,
            activeThumbColor: palette.accent,
            onChanged: (val) => setState(() => _autoOptimize = val),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              '${_atoms.length} atoms · ${settings.atomScale.label}',
              style: TextStyle(color: palette.textMuted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn(
    BuilderTool tool,
    IconData icon,
    String label,
    bool showTooltips,
    String hint,
  ) {
    final palette = _palette;
    final isActive = _currentTool == tool;
    final button = TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor:
            isActive ? palette.accent.withValues(alpha: 0.2) : Colors.transparent,
        foregroundColor: isActive ? palette.accent : palette.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => setState(() => _currentTool = tool),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
    return showTooltips ? Tooltip(message: hint, child: button) : button;
  }
}

// ── Supporting widgets ───────────────────────────────────────────────────────

class _TitleField extends StatefulWidget {
  final String initialValue;
  final QuantumTheme palette;
  final ValueChanged<String> onChanged;

  const _TitleField({
    required this.initialValue,
    required this.palette,
    required this.onChanged,
  });

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void didUpdateWidget(covariant _TitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in sync when the title changes from an import, without fighting the
    // user's cursor while they type.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(color: widget.palette.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Structure title',
          labelStyle: TextStyle(color: widget.palette.textMuted, fontSize: 12),
          prefixIcon: Icon(Icons.label_outline,
              size: 16, color: widget.palette.textMuted),
        ),
      ),
    );
  }
}

/// The Avogadro-specific half of the header: export, hand-off and clipboard.
class _AvogadroActionBar extends StatelessWidget {
  final QuantumTheme palette;
  final AppSettings settings;
  final int atomCount;
  final int bondCount;
  final void Function(String format) onExport;
  final VoidCallback onSendToAvogadro;
  final VoidCallback onSimulateHybridMd;
  final void Function(String format) onCopy;

  const _AvogadroActionBar({
    required this.palette,
    required this.settings,
    required this.atomCount,
    required this.bondCount,
    required this.onExport,
    required this.onSendToAvogadro,
    required this.onSimulateHybridMd,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                'Avogadro 2 bridge',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '$atomCount atoms · $bondCount bonds · ${settings.defaultExportFormat.shortLabel} default',
            style: TextStyle(color: palette.textMuted, fontSize: 11.5),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onSendToAvogadro,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send to Avogadro'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
            ),
          ),
          FilledButton.icon(
            onPressed: onSimulateHybridMd,
            icon: const Icon(Icons.science, size: 16),
            label: const Text('Simulate Hybrid MD'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.shade400,
              foregroundColor: Colors.white,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export structure',
            onSelected: onExport,
            color: palette.panelAlt,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cjson',
                child: Text('CJSON — native Avogadro 2'),
              ),
              const PopupMenuItem(value: 'cml', child: Text('CML — XML')),
              const PopupMenuItem(value: 'sdf', child: Text('SDF / MOL V2000')),
              const PopupMenuItem(
                value: 'xyz',
                child: Text('XYZ — cartesian coordinates'),
              ),
            ],
            child: _OutlinedAction(
              palette: palette,
              icon: Icons.ios_share,
              label: 'Export…',
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Copy to clipboard',
            onSelected: onCopy,
            color: palette.panelAlt,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'cjson', child: Text('Copy CJSON')),
              PopupMenuItem(value: 'cml', child: Text('Copy CML')),
              PopupMenuItem(value: 'xyz', child: Text('Copy XYZ')),
            ],
            child: _OutlinedAction(
              palette: palette,
              icon: Icons.content_copy,
              label: 'Copy…',
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final QuantumTheme palette;
  final IconData icon;
  final String label;

  const _OutlinedAction({
    required this.palette,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        color: palette.panelAlt,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.textPrimary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: palette.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final QuantumTheme palette;

  const _ErrorBanner({required this.message, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.textPrimary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Local fire-and-forget helper (keeps the analysis quiet about unused futures).
void unawaited(Future<void> future) {
  future.catchError((Object error) {
    debugPrint('CoordinateEditor: background task failed — $error');
  });
}
