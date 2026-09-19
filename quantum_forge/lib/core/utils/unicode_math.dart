// ============================================================================
// Unicode math helpers — subscripts, superscripts and scientific notation
// ----------------------------------------------------------------------------
// Used to render numbers the way a journal does: chemical formulae with
// subscript digit counts (C₈H₁₀N₄O₂), powers as superscripts (10⁻⁴, s⁻¹), and
// scientific notation as `3.4×10⁻⁴`.
//
// These are display-only helpers. File formats (XYZ/CJSON/CML/SDF) keep plain
// ASCII so they stay valid for Avogadro and other parsers.
// ============================================================================

import 'dart:math' as math;

const Map<String, String> _superscript = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'n': 'ⁿ', 'i': 'ⁱ',
};

const Map<String, String> _subscript = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
};

/// Maps every supported character to its superscript form.
String toSuperscript(String value) =>
    value.split('').map((c) => _superscript[c] ?? c).join();

/// Maps every supported character to its subscript form.
String toSubscript(String value) =>
    value.split('').map((c) => _subscript[c] ?? c).join();

/// Converts digit counts in a chemical formula to subscript digits
/// (e.g. `C8H10N4O2` → `C₈H₁₀N₄O₂`). Element symbols are untouched.
String subscriptFormula(String formula) =>
    formula.split('').map((c) => _subscript[c] ?? c).join();

/// Replaces an ASCII minus with the typographic minus sign (for exponents).
String unicodeMinus(String value) => value.replaceAll('-', '−');

/// Formats a number as `mantissa × 10^exponent` with a Unicode superscript,
/// e.g. `0.00034` → `3.4×10⁻⁴`. [significant] is the number of significant
/// figures in the mantissa (which lies in [1, 10)).
String scientificNotation(double value, {int significant = 2}) {
  if (value == 0 || !value.isFinite) return '0';
  final sign = value < 0 ? '−' : '';
  final abs = value.abs();
  final exponent = (math.log(abs) / math.ln10).floor();
  final mantissa = abs / math.pow(10, exponent).toDouble();
  final decimals = (significant - 1).clamp(0, 6);
  return '$sign${mantissa.toStringAsFixed(decimals)}×10'
      '${toSuperscript('$exponent')}';
}
