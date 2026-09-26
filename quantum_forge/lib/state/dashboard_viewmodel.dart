import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_template_generator.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/core/utils/avogadro_codec.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/left_nav_rail.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:quantum_forge/core/services/chemical_resolver_service.dart';
import 'package:quantum_forge/core/services/session_state_service.dart';

enum MoleculeRole { reactant, product, catalyst }

class MoleculeEntry {
  final String id;
  PickedFile? file;
  final TextEditingController ctrl;
  final FocusNode focus;
  List<String> suggestions;
  bool suggestionsLoading;
  bool isResolving;
  Timer? debounce;

  MoleculeEntry({required this.id})
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

class DashboardViewModel extends ChangeNotifier {
  final SessionStateService _sessionService;

  DashboardViewModel({required SessionStateService sessionService})
      : _sessionService = sessionService;

  NavDestination _navDest = NavDestination.newReaction;
  NavDestination get navDest => _navDest;

  ReactionTemplate? _activeTemplate;
  ReactionTemplate? get activeTemplate => _activeTemplate;

  bool _controlsPanelOpen = true;
  bool get controlsPanelOpen => _controlsPanelOpen;

  final List<MoleculeEntry> _reactants = [MoleculeEntry(id: 'r0')];
  List<MoleculeEntry> get reactants => _reactants;

  final List<MoleculeEntry> _products = [MoleculeEntry(id: 'p0')];
  List<MoleculeEntry> get products => _products;

  final List<MoleculeEntry> _catalysts = [MoleculeEntry(id: 'c0')];
  List<MoleculeEntry> get catalysts => _catalysts;

  int _entryCounter = 1;

  bool _shouldAutoRun = false;
  bool get shouldAutoRun => _shouldAutoRun;

  /// A structure handed over by an Avogadro deep link, waiting for the editor
  /// to pick it up. Cleared by [consumePendingStructure].
  DecodedStructure? _pendingStructure;
  DecodedStructure? get pendingStructure => _pendingStructure;
  bool get hasPendingStructure => _pendingStructure != null;

  /// Increments every time a new structure is handed over. The editor uses it as
  /// its widget key so a *new* import rebuilds the editor while a rebuild for any
  /// other reason leaves the user's in-progress edits alone.
  int _structureRevision = 0;
  int get structureRevision => _structureRevision;

  /// Sends an externally supplied structure to the coordinate editor.
  ///
  /// Imported Avogadro structures used to be dropped into the "first reactant"
  /// slot, which silently required a second reactant before anything could be
  /// dispatched. They now open in the editor, where they can be inspected,
  /// finished and exported back.
  void loadStructure(DecodedStructure structure) {
    _pendingStructure = structure;
    _structureRevision++;
    _navDest = NavDestination.editor;
    notifyListeners();
  }

  DecodedStructure? consumePendingStructure() {
    final structure = _pendingStructure;
    _pendingStructure = null;
    return structure;
  }
  
  void consumeAutoRun() {
    _shouldAutoRun = false;
  }
  
  void _triggerAutoRun() {
    _shouldAutoRun = true;
    // Don't notify listeners directly just for auto run, it will be bundled with state updates
  }

  void setNavDestination(NavDestination dest) {
    _navDest = dest;
    notifyListeners();
  }

  void toggleControlsPanel() {
    _controlsPanelOpen = !_controlsPanelOpen;
    notifyListeners();
  }

  void loadTemplate(ReactionTemplate template) {
    _disposeEntries(_reactants);
    _disposeEntries(_products);
    _disposeEntries(_catalysts);
    _reactants
      ..clear()
      ..add(MoleculeEntry(id: 'r0'));
    _products
      ..clear()
      ..add(MoleculeEntry(id: 'p0'));
    _catalysts
      ..clear()
      ..add(MoleculeEntry(id: 'c0'));
    
    _activeTemplate = template;
    _navDest = NavDestination.newReaction;
    _triggerAutoRun();
    notifyListeners();
  }

  void clearTemplate() {
    _activeTemplate = null;
    notifyListeners();
  }

  void addMolecule(MoleculeRole role) {
    String prefix;
    List<MoleculeEntry> targetList;
    switch (role) {
      case MoleculeRole.reactant: prefix = 'r'; targetList = _reactants; break;
      case MoleculeRole.product: prefix = 'p'; targetList = _products; break;
      case MoleculeRole.catalyst: prefix = 'c'; targetList = _catalysts; break;
    }
    targetList.add(MoleculeEntry(id: '$prefix${_entryCounter++}'));
    _activeTemplate = null;
    notifyListeners();
  }

  void removeMolecule(MoleculeRole role, MoleculeEntry entry) {
    entry.dispose();
    List<MoleculeEntry> targetList;
    String prefix;
    switch (role) {
      case MoleculeRole.reactant: prefix = 'r'; targetList = _reactants; break;
      case MoleculeRole.product: prefix = 'p'; targetList = _products; break;
      case MoleculeRole.catalyst: prefix = 'c'; targetList = _catalysts; break;
    }
    targetList.remove(entry);
    if (targetList.isEmpty) {
      targetList.add(MoleculeEntry(id: '$prefix${_entryCounter++}'));
    }
    notifyListeners();
  }

  Future<void> pickFileForEntry(MoleculeEntry entry, FilePickerService picker) async {
    final result = await picker.pickStructureFile();
    if (result != null) {
      entry.file = result;
      entry.ctrl.text = result.name.replaceAll('.xyz', '');
      entry.suggestions = [];
      _activeTemplate = null;
      _triggerAutoRun();
      notifyListeners();
    }
  }

  void setManualFile(MoleculeEntry entry, PickedFile file) {
    entry.file = file;
    entry.ctrl.text = file.name.replaceAll('.xyz', '');
    entry.suggestions = [];
    _activeTemplate = null;
    _triggerAutoRun();
    notifyListeners();
  }

  bool canDispatch(bool isLoading, bool isRunning) {
    if (isLoading || isRunning) return false;
    if (_activeTemplate != null) return true;
    final rOk = _reactants.any((e) => e.resolved);
    final pOk = _products.any((e) => e.resolved);
    // Catalysts are optional, so we don't require cOk unless we want to enforce it.
    return rOk && pOk;
  }

  PickedFile mergeXyz(List<MoleculeEntry> entries, String label) {
    final resolved = entries.where((e) => e.file != null).toList();
    if (resolved.length == 1) return resolved.first.file!;

    int totalAtoms = 0;
    final atomLines = <String>[];
    for (final e in resolved) {
      final bytes = e.file!.bytes;
      if (bytes == null) continue;
      // utf8.decode (not String.fromCharCodes) — atom labels and titles are
      // routinely non-ASCII (Å, Greek subscripts in atom names).
      final raw = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(raw).map((l) => l.trim()).toList();
      if (lines.length < 3) continue;
      final count = int.tryParse(lines[0]) ?? 0;
      for (final line in lines.skip(2).take(count)) {
        if (line.isEmpty) continue;
        atomLines.add(line);
        totalAtoms++;
      }
    }
    final combined = '$totalAtoms\nCombined $label\n${atomLines.join('\n')}\n';
    final bytes = Uint8List.fromList(utf8.encode(combined));
    return PickedFile(name: 'combined_$label.xyz', size: bytes.length, bytes: bytes);
  }

  Future<void> resolveChemical(MoleculeEntry entry, ChemicalResolverService resolver, {String? query}) async {
    final q = query ?? entry.ctrl.text.trim();
    if (q.isEmpty) return;

    entry.isResolving = true;
    notifyListeners();

    try {
      final xyzData = await resolver.resolveToXyz(q);

      if (xyzData != null) {
        final bytes = Uint8List.fromList(utf8.encode(xyzData));
        final picked = PickedFile(
          name: '${q.replaceAll(RegExp(r'[^\w\-.]'), '_')}.xyz',
          size: bytes.length,
          bytes: bytes,
        );
        entry.file = picked;
        entry.suggestions = [];
        _activeTemplate = null;
        _triggerAutoRun();
        notifyListeners();
      } else {
        throw Exception('No 3D structure found for "$q".');
      }
    } finally {
      entry.isResolving = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String val, MoleculeEntry entry, ChemicalResolverService resolver) {
    entry.debounce?.cancel();

    if (val.trim().length < 2) {
      entry.suggestions = [];
      entry.suggestionsLoading = false;
      notifyListeners();
      return;
    }

    entry.suggestionsLoading = true;
    notifyListeners();

    final timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await resolver.getSuggestions(val.trim());
        entry.suggestions = results;
        entry.suggestionsLoading = false;
        notifyListeners();
      } catch (_) {
        entry.suggestionsLoading = false;
        notifyListeners();
      }
    });

    entry.debounce = timer;
  }

  void onSuggestionSelected(String suggestion, MoleculeEntry entry, ChemicalResolverService resolver) {
    entry.ctrl.text = suggestion;
    entry.suggestions = [];
    notifyListeners();
    resolveChemical(entry, resolver, query: suggestion);
  }

  void clearEntry(MoleculeEntry entry) {
    entry.file = null;
    entry.ctrl.clear();
    entry.suggestions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeEntries(_reactants);
    _disposeEntries(_products);
    _disposeEntries(_catalysts);
    super.dispose();
  }

  static void _disposeEntries(List<MoleculeEntry> entries) {
    for (final entry in entries) {
      entry.dispose();
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _saveState();
  }

  Future<void> _saveState() async {
    final state = <String, dynamic>{
      'activeTemplate': _activeTemplate?.id,
      'reactants': _serializeEntries(_reactants),
      'products': _serializeEntries(_products),
      'catalysts': _serializeEntries(_catalysts),
    };
    await _sessionService.saveDashboardState(state);
  }

  List<Map<String, dynamic>> _serializeEntries(List<MoleculeEntry> entries) {
    return entries.map((e) {
      String? base64Bytes;
      if (e.file?.bytes != null) {
        base64Bytes = base64Encode(e.file!.bytes!);
      }
      return {
        'id': e.id,
        'text': e.ctrl.text,
        'fileName': e.file?.name,
        'fileBytes': base64Bytes,
      };
    }).toList();
  }

  Future<void> loadState() async {
    final state = await _sessionService.loadDashboardState();
    if (state == null) return;

    if (state['activeTemplate'] != null) {
      final tId = state['activeTemplate'] as String;
      // Resolve against the curated set first (cheap), then fall back to the full
      // library so a DERIVED variant still resolves. Looking only at the curated
      // list would silently load the first unrelated reaction instead.
      ReactionTemplate? found;
      for (final t in kReactionTemplates) {
        if (t.id == tId) {
          found = t;
          break;
        }
      }
      if (found == null) {
        // Only pay for building the generated library when actually needed.
        for (final t in allReactionTemplates) {
          if (t.id == tId) {
            found = t;
            break;
          }
        }
      }
      _activeTemplate = found ?? kReactionTemplates.first;
    }

    if (state['reactants'] != null) {
      _deserializeEntries(state['reactants'] as List, _reactants);
    }
    if (state['products'] != null) {
      _deserializeEntries(state['products'] as List, _products);
    }
    if (state['catalysts'] != null) {
      _deserializeEntries(state['catalysts'] as List, _catalysts);
    }
    
    if (_reactants.isEmpty) _reactants.add(MoleculeEntry(id: 'r0'));
    if (_products.isEmpty) _products.add(MoleculeEntry(id: 'p0'));
    if (_catalysts.isEmpty) _catalysts.add(MoleculeEntry(id: 'c0'));

    super.notifyListeners(); // Call super to update UI without triggering a save
  }

  void _deserializeEntries(List dynamicList, List<MoleculeEntry> targetList) {
    _disposeEntries(targetList);
    targetList.clear();
    for (var item in dynamicList) {
      final map = item as Map<String, dynamic>;
      final entry = MoleculeEntry(id: map['id'] ?? 'u${_entryCounter++}');
      entry.ctrl.text = map['text'] ?? '';
      if (map['fileName'] != null && map['fileBytes'] != null) {
        final bytes = base64Decode(map['fileBytes']);
        entry.file = PickedFile(name: map['fileName'], size: bytes.length, bytes: bytes);
      }
      targetList.add(entry);
    }
  }
}
