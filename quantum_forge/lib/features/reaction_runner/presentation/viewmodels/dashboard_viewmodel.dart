import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/left_nav_rail.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:quantum_forge/core/services/chemical_resolver_service.dart';

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

  void setNavDestination(NavDestination dest) {
    _navDest = dest;
    notifyListeners();
  }

  void toggleControlsPanel() {
    _controlsPanelOpen = !_controlsPanelOpen;
    notifyListeners();
  }

  void loadTemplate(ReactionTemplate template) {
    for (final e in _reactants) e.dispose();
    for (final e in _products) e.dispose();
    for (final e in _catalysts) e.dispose();
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
      notifyListeners();
    }
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
    for (final e in _reactants) e.dispose();
    for (final e in _products) e.dispose();
    for (final e in _catalysts) e.dispose();
    super.dispose();
  }
}
