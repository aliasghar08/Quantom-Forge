// ============================================================================
// Unicode math helper tests
// ----------------------------------------------------------------------------
// Pins the subscript/superscript mapping and scientific-notation formatting so
// display strings stay journal-grade (and file formats stay plain ASCII).
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/unicode_math.dart';

void main() {
  group('superscript', () {
    test('maps digits, sign and parentheses', () {
      expect(toSuperscript('0'), '⁰');
      expect(toSuperscript('9'), '⁹');
      expect(toSuperscript('-3'), '⁻³');
      expect(toSuperscript('+2'), '⁺²');
      expect(toSuperscript('(n)'), '⁽ⁿ⁾');
    });
  });

  group('subscript', () {
    test('maps digits', () {
      expect(toSubscript('2'), '₂');
      expect(toSubscript('10'), '₁₀');
    });

    test('converts chemical formula digit counts to subscripts', () {
      expect(subscriptFormula('H2O'), 'H₂O');
      expect(subscriptFormula('C8H10N4O2'), 'C₈H₁₀N₄O₂');
      expect(subscriptFormula('CH4'), 'CH₄');
      expect(subscriptFormula('He2'), 'He₂');
    });
  });

  group('scientific notation', () {
    test('formats positive and negative values', () {
      expect(scientificNotation(0.00034, significant: 2), '3.4×10⁻⁴');
      expect(scientificNotation(-0.00034, significant: 2), '−3.4×10⁻⁴');
      expect(scientificNotation(3.4e-5, significant: 1), '3×10⁻⁵');
      expect(scientificNotation(0), '0');
    });

    test('large exponents use a superscript plus sign', () {
      expect(scientificNotation(1.23e8, significant: 3), '1.23×10⁸');
    });
  });

  group('unicode minus', () {
    test('replaces ASCII hyphen with typographic minus', () {
      expect(unicodeMinus('-2.3'), '−2.3');
      expect(unicodeMinus('10^(-2.3)'), '10^(−2.3)');
    });
  });
}
