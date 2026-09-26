// ============================================================================
// Reaction Template Generator
// ----------------------------------------------------------------------------
// Expands the 41 curated templates into thousands of systematically derived
// variants WITHOUT inventing literature data.
//
// Derivation rule
// ---------------
// A template is a reactant/product PAIR. For a variant we pick a *spectator*
// hydrogen — an H bonded to the same heavy atom index in BOTH structures, so it
// is not the atom being transferred or broken — and replace it with a substituent
// (F, Cl, Br, I, OH, NH2, CH3, CF3 or CN) placed along the original C-H bond
// direction at a standard bond length.
//
// Because the substituent is a spectator, the qualitative shape of the reaction
// path is preserved and the resulting geometry is physically sensible, though it
// is NOT re-optimised. Every generated entry therefore:
//   * is flagged [ReactionTemplate.isDerived],
//   * inherits the parent's referenceEa as a rough starting estimate (stated in
//     its own description),
//   * carries an EMPTY doi and a "Derived from" journalRef, so a generated entry
//     can never be mistaken for a curated, cited result.
//
// Nothing here is fabricated: the only numbers carried over are the parent's own.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

/// Hard cap on variants per curated parent (keeps memory predictable).
const int kMaxVariantsPerParent = 100000;

/// Hard cap on the generated library size.
const int kMaxGeneratedTemplates = 200000;

/// Curated templates + generated variants, built once on first access so app
/// start-up and any code path that never opens the library stay unaffected.
@Deprecated('Use generateAllReactionTemplatesAsync to avoid UI freezes')
List<ReactionTemplate> get allReactionTemplates =>
    _allTemplates ??= buildFullTemplateLibrary(kReactionTemplates);

List<ReactionTemplate>? _allTemplates;

/// Generates the reaction templates async on a background isolate to prevent UI jank.
Future<List<ReactionTemplate>> generateAllReactionTemplatesAsync() async {
  if (_allTemplates != null) return _allTemplates!;
  _allTemplates = await compute(buildFullTemplateLibrary, kReactionTemplates);
  return _allTemplates!;
}

/// Exposed for tests so the cache can be reset between cases.
void resetTemplateLibraryCache() => _allTemplates = null;

/// Builds `curated + derived`.
List<ReactionTemplate> buildFullTemplateLibrary(
  List<ReactionTemplate> curated, {
  int maxGenerated = kMaxGeneratedTemplates,
}) {
  final derived = deriveTemplateVariants(curated, maxTotal: maxGenerated);
  return <ReactionTemplate>[...curated, ...derived];
}

// ─── Substituents ───────────────────────────────────────────────────────────

class _Substituent {
  /// Human label, also used in names, tags and ids.
  final String label;

  /// Element of the atom that takes the hydrogen's place.
  final String attachElement;

  /// Bond length from the parent heavy atom to [attachElement], in Å.
  final double attachLength;

  const _Substituent(this.label, this.attachElement, this.attachLength);
}

const List<_Substituent> _substituents = [
  _Substituent('F', 'F', 1.35),
  _Substituent('Cl', 'Cl', 1.79),
  _Substituent('Br', 'Br', 1.94),
  _Substituent('I', 'I', 2.14),
  _Substituent('OH', 'O', 1.43),
  _Substituent('NH2', 'N', 1.47),
  _Substituent('CH3', 'C', 1.51),
  _Substituent('CF3', 'C', 1.50),
  _Substituent('CN', 'C', 1.46),
];

/// Covalent radii (Å) used for distance-based bond perception.
const Map<String, double> _covalentRadii = {
  'H': 0.31, 'C': 0.76, 'N': 0.71, 'O': 0.66, 'F': 0.57,
  'Cl': 1.02, 'Br': 1.20, 'I': 1.39, 'S': 1.05, 'P': 1.07,
};

// ─── Minimal XYZ handling ───────────────────────────────────────────────────

class _Frame {
  final List<String> elements;
  final List<List<double>> positions;

  _Frame(this.elements, this.positions);

  int get length => elements.length;
}

_Frame? _parseXyz(String xyz) {
  final lines = xyz.split('\n');
  if (lines.length < 2) return null;
  final declared = int.tryParse(lines.first.trim());
  if (declared == null) return null;

  final elements = <String>[];
  final positions = <List<double>>[];
  for (var i = 2; i < lines.length && elements.length < declared; i++) {
    final parts = lines[i].trim().split(RegExp(r'\s+'));
    if (parts.length < 4) continue;
    final x = double.tryParse(parts[1]);
    final y = double.tryParse(parts[2]);
    final z = double.tryParse(parts[3]);
    if (x == null || y == null || z == null) continue;
    elements.add(parts[0]);
    positions.add([x, y, z]);
  }
  if (elements.length != declared) return null;
  return _Frame(elements, positions);
}

String _writeXyz(_Frame frame, String comment) {
  final buffer = StringBuffer()
    ..writeln(frame.length)
    ..writeln(comment);
  for (var i = 0; i < frame.length; i++) {
    final p = frame.positions[i];
    buffer.writeln(
      '${frame.elements[i].padRight(2)} '
      '${p[0].toStringAsFixed(4).padLeft(10)} '
      '${p[1].toStringAsFixed(4).padLeft(10)} '
      '${p[2].toStringAsFixed(4).padLeft(10)}',
    );
  }
  return buffer.toString();
}

/// Adjacency list from covalent-radius distance criteria.
List<List<int>> _perceiveBonds(_Frame frame) {
  final bonds = List.generate(frame.length, (_) => <int>[]);
  for (var i = 0; i < frame.length; i++) {
    for (var j = i + 1; j < frame.length; j++) {
      final ri = _covalentRadii[frame.elements[i]] ?? 0.8;
      final rj = _covalentRadii[frame.elements[j]] ?? 0.8;
      final cutoff = 1.3 * (ri + rj);
      final d = _distance(frame.positions[i], frame.positions[j]);
      if (d > 0.2 && d < cutoff) {
        bonds[i].add(j);
        bonds[j].add(i);
      }
    }
  }
  return bonds;
}

// ─── Vector helpers ─────────────────────────────────────────────────────────

double _distance(List<double> a, List<double> b) {
  final dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}

List<double> _normalize(List<double> v) {
  final n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  if (n < 1e-9) return [0.0, 0.0, 1.0];
  return [v[0] / n, v[1] / n, v[2] / n];
}

/// Any unit vector perpendicular to [d].
List<double> _perpendicular(List<double> d) {
  final ref = d[0].abs() < 0.9 ? [1.0, 0.0, 0.0] : [0.0, 1.0, 0.0];
  var cx = d[1] * ref[2] - d[2] * ref[1];
  var cy = d[2] * ref[0] - d[0] * ref[2];
  var cz = d[0] * ref[1] - d[1] * ref[0];
  return _normalize([cx, cy, cz]);
}

List<double> _add(List<double> a, List<double> b) =>
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]];

List<double> _scale(List<double> v, double s) => [v[0] * s, v[1] * s, v[2] * s];

// ─── Group geometry ─────────────────────────────────────────────────────────

/// Extra atoms (beyond the attachment atom itself) for a substituent, placed in
/// a local frame where [dir] points from the parent atom toward the attachment.
List<(String, List<double>)> _groupAtoms(
  String label,
  List<double> attachPos,
  List<double> dir,
  List<double> u,
  List<double> v,
) {
  switch (label) {
    case 'OH':
      // O-H at ~108° from the O->C axis.
      const angle = 108.0 * math.pi / 180.0;
      return [
        (
          'H',
          _add(
            attachPos,
            _scale(
              _add(_scale(dir, -math.cos(angle)), _scale(u, math.sin(angle))),
              0.96,
            ),
          ),
        ),
      ];
    case 'NH2':
      // Two N-H at a 107° H-N-H angle; each sits 126.5° from the N->C axis.
      const halfFromAxis = (180.0 - 107.0 / 2.0) * math.pi / 180.0;
      return [
        for (final sign in [1.0, -1.0])
          (
            'H',
            _add(
              attachPos,
              _scale(
                _add(
                  _scale(dir, -math.cos(halfFromAxis)),
                  _scale(u, sign * math.sin(halfFromAxis)),
                ),
                1.01,
              ),
            ),
          ),
      ];
    case 'CH3':
      return _tetrahedral('H', attachPos, dir, u, v, 1.09);
    case 'CF3':
      return _tetrahedral('F', attachPos, dir, u, v, 1.33);
    case 'CN':
      // Linear C≡N pointing away from the parent.
      return [('N', _add(attachPos, _scale(dir, 1.16)))];
    default:
      return const [];
  }
}

/// Three substituents tetrahedrally arranged around [centre], angled away from
/// the parent along [dir]. The remaining tetrahedral direction (-[dir]/3) points
/// back at the parent, so the three offsets use +[dir]/3.
List<(String, List<double>)> _tetrahedral(
  String element,
  List<double> centre,
  List<double> dir,
  List<double> u,
  List<double> v,
  double bondLength,
) {
  const cosTheta = -1.0 / 3.0;
  final sinTheta = math.sqrt(8.0) / 3.0;
  return [
    for (var k = 0; k < 3; k++)
      () {
        final phi = k * 2.0 * math.pi / 3.0;
        final offset = _add(
          _scale(dir, -cosTheta),
          _add(_scale(u, sinTheta * math.cos(phi)),
               _scale(v, sinTheta * math.sin(phi))),
        );
        return (element, _add(centre, _scale(offset, bondLength)));
      }(),
  ];
}

// ─── Derivation ─────────────────────────────────────────────────────────────

/// A curated parent that can be substituted safely, plus its spectator H sites.
class _DerivableParent {
  final ReactionTemplate parent;
  final _Frame reactant;
  final _Frame product;

  /// Original H atom index -> index of the carbon it hangs off (identical in
  /// both structures, which is what makes it a spectator).
  final Map<int, int> sites;

  _DerivableParent(this.parent, this.reactant, this.product, this.sites);
}

/// Generates systematic variants for every curated template that can be derived
/// safely.
///
/// Only parents whose reactant and product list their atoms in the *same order*
/// are used. Substitution happens at a fixed atom index in both structures, so if
/// the orderings disagreed the substituent would land on a different atom in the
/// product and the resulting "reaction" would be meaningless. 31 of the 39
/// curated templates are bimolecular pairs with reordered atoms, so they are left
/// untouched rather than guessed at.
///
/// Combinatorics: every single substitution, then every *pair* of substitutions.
/// Extra substituents are still spectators, so the reaction itself is unchanged -
/// this is what lifts the library from hundreds into thousands without inventing
/// a single new number.
List<ReactionTemplate> deriveTemplateVariants(
  List<ReactionTemplate> curated, {
  int maxTotal = kMaxGeneratedTemplates,
}) {
  final derivable = <_DerivableParent>[];
  for (final parent in curated) {
    final analysed = _analyseParent(parent);
    if (analysed != null) derivable.add(analysed);
  }
  if (derivable.isEmpty) return const [];

  // Spread the budget across parents instead of letting the first one fill it.
  final perParent =
      (maxTotal / derivable.length).ceil().clamp(1, kMaxVariantsPerParent);

  final out = <ReactionTemplate>[];
  for (final d in derivable) {
    if (out.length >= maxTotal) break;
    _emitVariants(d, perParent, maxTotal, out);
  }
  return out;
}

_DerivableParent? _analyseParent(ReactionTemplate parent) {
  final reactant = _parseXyz(parent.reactantXyz);
  final product = _parseXyz(parent.productXyz);
  // Atom ordering must agree between the two structures, otherwise index-based
  // substitution silently changes which atom is being replaced.
  if (reactant == null || product == null) return null;
  if (reactant.length != product.length) return null;
  if (!_sameElements(reactant, product)) return null;

  final rBonds = _perceiveBonds(reactant);
  final pBonds = _perceiveBonds(product);

  final sites = <int, int>{};
  for (var i = 0; i < reactant.length; i++) {
    if (reactant.elements[i] != 'H' || product.elements[i] != 'H') continue;
    if (rBonds[i].length != 1 || pBonds[i].length != 1) continue;
    final heavy = rBonds[i].first;
    if (heavy != pBonds[i].first) continue; // different partner -> not a spectator
    if (reactant.elements[heavy] != 'C') continue; // substituent chemistry stays on carbon
    if ((rBonds[heavy].length + pBonds[heavy].length) / 2 < 2) continue; // needs a heavy neighbour
    sites[i] = heavy;
  }
  if (sites.isEmpty) return null;
  return _DerivableParent(parent, reactant, product, sites);
}

void _emitVariants(
  _DerivableParent d,
  int perParent,
  int maxTotal,
  List<ReactionTemplate> out,
) {
  final siteIndices = d.sites.keys.toList()..sort();
  var made = 0;

  void emit(List<int> sites, List<_Substituent> subs) {
    if (made >= perParent || out.length >= maxTotal) return;
    out.add(_buildVariant(d, sites, subs));
    made++;
  }

  // Singles.
  for (final site in siteIndices) {
    for (final sub in _substituents) {
      emit([site], [sub]);
    }
  }

  // Pairs - both substituents are still spectators, so the reaction is unchanged.
  for (var a = 0; a < siteIndices.length; a++) {
    for (var b = a + 1; b < siteIndices.length; b++) {
      for (final first in _substituents) {
        for (final second in _substituents) {
          if (made >= perParent || out.length >= maxTotal) return;
          emit([siteIndices[a], siteIndices[b]], [first, second]);
        }
      }
    }
  }

  // Triples - massive combinatorial explosion
  for (var a = 0; a < siteIndices.length; a++) {
    for (var b = a + 1; b < siteIndices.length; b++) {
      for (var c = b + 1; c < siteIndices.length; c++) {
        for (final first in _substituents) {
          for (final second in _substituents) {
            for (final third in _substituents) {
              if (made >= perParent || out.length >= maxTotal) return;
              emit([siteIndices[a], siteIndices[b], siteIndices[c]], [first, second, third]);
            }
          }
        }
      }
    }
  }

  // Quads - true theoretical limit explosion
  for (var a = 0; a < siteIndices.length; a++) {
    for (var b = a + 1; b < siteIndices.length; b++) {
      for (var c = b + 1; c < siteIndices.length; c++) {
        for (var d = c + 1; d < siteIndices.length; d++) {
          for (final first in _substituents) {
            for (final second in _substituents) {
              for (final third in _substituents) {
                for (final fourth in _substituents) {
                  if (made >= perParent || out.length >= maxTotal) return;
                  emit([siteIndices[a], siteIndices[b], siteIndices[c], siteIndices[d]], [first, second, third, fourth]);
                }
              }
            }
          }
        }
      }
    }
  }

  // Quints - maximum theoretical exhaustion
  for (var a = 0; a < siteIndices.length; a++) {
    for (var b = a + 1; b < siteIndices.length; b++) {
      for (var c = b + 1; c < siteIndices.length; c++) {
        for (var d = c + 1; d < siteIndices.length; d++) {
          for (var e = d + 1; e < siteIndices.length; e++) {
            for (final first in _substituents) {
              for (final second in _substituents) {
                for (final third in _substituents) {
                  for (final fourth in _substituents) {
                    for (final fifth in _substituents) {
                      if (made >= perParent || out.length >= maxTotal) return;
                      emit([siteIndices[a], siteIndices[b], siteIndices[c], siteIndices[d], siteIndices[e]], [first, second, third, fourth, fifth]);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

bool _sameElements(_Frame a, _Frame b) {
  for (var i = 0; i < a.length; i++) {
    if (a.elements[i] != b.elements[i]) return false;
  }
  return true;
}

ReactionTemplate _buildVariant(
  _DerivableParent d,
  List<int> sites,
  List<_Substituent> subs,
) {
  var reactant = d.reactant;
  var product = d.product;
  for (var k = 0; k < sites.length; k++) {
    final heavy = d.sites[sites[k]]!;
    reactant = _applySubstitution(reactant, sites[k], heavy, subs[k]);
    product = _applySubstitution(product, sites[k], heavy, subs[k]);
  }

  final parent = d.parent;
  final labels = subs.map((s) => s.label).join('+');
  final humanSites = sites.map((s) => 'H${s + 1}').join(', ');
  final idSuffix = subs.map((s) => s.label.toLowerCase()).join('-');
  final numbering = sites.map((s) => s + 1).join('_');

  return ReactionTemplate(
    id: '${parent.id}-$idSuffix-$numbering',
    name: '${parent.name} [$labels @ $humanSites]',
    iupacName: '${parent.iupacName} ($labels-substituted)',
    description:
        '${parent.description}\n\n'
        '[Derived variant] $labels replace spectator hydrogen $humanSites. Each is '
        'bonded to the same carbon in both structures and so takes no part in the '
        'reaction itself. The geometry was built by substitution on the curated '
        'parent and is NOT re-optimised; the barrier shown is the parent value '
        '(${parent.referenceEa} kcal·mol⁻¹) carried over as a starting estimate. '
        'No literature value is claimed for this variant.',
    category: parent.category,
    reactantXyz: _writeXyz(reactant, '${parent.name} [$labels] reactant'),
    productXyz: _writeXyz(product, '${parent.name} [$labels] product'),
    // Inherited as an estimate only - never presented as a measured value.
    referenceEa: parent.referenceEa,
    // Deliberately EMPTY: a derived entry must never look like a cited result.
    doi: '',
    journalRef: 'Derived from: ${parent.name}',
    tags: [...parent.tags, ...subs.map((s) => s.label), 'derived'],
    defaults: parent.defaults,
    isDerived: true,
    derivedFrom: parent.name,
  );
}

/// Replaces the hydrogen at [site] with [sub], appending the substituent's extra
/// atoms.
///
/// Existing atom indices are preserved — the hydrogen's slot becomes the
/// attachment atom and any group atoms are appended — so several substitutions
/// can be applied in sequence without invalidating earlier indices.
_Frame _applySubstitution(
  _Frame frame,
  int site,
  int heavy,
  _Substituent sub,
) {
  final heavyPos = frame.positions[heavy];
  final hPos = frame.positions[site];

  var dir = _normalize([
    hPos[0] - heavyPos[0],
    hPos[1] - heavyPos[1],
    hPos[2] - heavyPos[2],
  ]);
  if (dir[0].isNaN || dir[1].isNaN || dir[2].isNaN) {
    dir = const [0.0, 0.0, 1.0];
  }

  final u = _perpendicular(dir);
  final v = _normalize([
    dir[1] * u[2] - dir[2] * u[1],
    dir[2] * u[0] - dir[0] * u[2],
    dir[0] * u[1] - dir[1] * u[0],
  ]);

  final attachPos = _add(heavyPos, _scale(dir, sub.attachLength));
  final elements = <String>[...frame.elements];
  final positions = <List<double>>[...frame.positions];

  elements[site] = sub.attachElement;
  positions[site] = attachPos;

  for (final (element, position) in _groupAtoms(sub.label, attachPos, dir, u, v)) {
    elements.add(element);
    positions.add(position);
  }

  return _Frame(elements, positions);
}
