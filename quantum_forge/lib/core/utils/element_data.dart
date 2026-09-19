import 'dart:ui';
import 'package:flutter/material.dart';

class ElementData {
  static const Map<String, Color> colors = {
    'H': Color(0xFFFFFFFF), 'He': Color(0xFFD9FFFF), 'Li': Color(0xFFCC80FF), 'Be': Color(0xFFC2FF00),
    'B': Color(0xFFFFB5B5), 'C': Color(0xFF909090), 'N': Color(0xFF3050F8), 'O': Color(0xFFFF0D0D),
    'F': Color(0xFF90E050), 'Ne': Color(0xFFB3E3F5), 'Na': Color(0xFFAB5CF2), 'Mg': Color(0xFF8AFF00),
    'Al': Color(0xFFBFA6A6), 'Si': Color(0xFFF0C8A0), 'P': Color(0xFFFF8000), 'S': Color(0xFFFFFF30),
    'Cl': Color(0xFF1FF01F), 'Ar': Color(0xFF80D1E3), 'K': Color(0xFF8F40D4), 'Ca': Color(0xFF3DFF00),
    'Sc': Color(0xFFE6E6E6), 'Ti': Color(0xFFBFC2C7), 'V': Color(0xFFA6A6AB), 'Cr': Color(0xFF8A99C7),
    'Mn': Color(0xFF9C7AC7), 'Fe': Color(0xFFE06633), 'Co': Color(0xFFF090A0), 'Ni': Color(0xFF50D050),
    'Cu': Color(0xFFC88033), 'Zn': Color(0xFF7D80B0), 'Ga': Color(0xFFC28F8F), 'Ge': Color(0xFF668F8F),
    'As': Color(0xFFBD80E3), 'Se': Color(0xFFFFA100), 'Br': Color(0xFFA62929), 'Kr': Color(0xFF5CB8D1),
    'Rb': Color(0xFF702EB0), 'Sr': Color(0xFF00FF00), 'Y': Color(0xFF94FFFF), 'Zr': Color(0xFF94E0E0),
    'Nb': Color(0xFF73C2C9), 'Mo': Color(0xFF54B5B5), 'Tc': Color(0xFF3B9E9E), 'Ru': Color(0xFF248F8F),
    'Rh': Color(0xFF0A7D8C), 'Pd': Color(0xFF006985), 'Ag': Color(0xFFC0C0C0), 'Cd': Color(0xFFFFD98F),
    'In': Color(0xFFA67573), 'Sn': Color(0xFF668080), 'Sb': Color(0xFF9E63B5), 'Te': Color(0xFFD47A00),
    'I': Color(0xFF940094), 'Xe': Color(0xFF429EB0), 'Cs': Color(0xFF57178F), 'Ba': Color(0xFF00C900),
    'La': Color(0xFF70D4FF), 'Ce': Color(0xFFFFFFC7), 'Pr': Color(0xFFD9FFC7), 'Nd': Color(0xFFC7FFC7),
    'Pm': Color(0xFFA3FFC7), 'Sm': Color(0xFF8FFFC7), 'Eu': Color(0xFF61FFC7), 'Gd': Color(0xFF45FFC7),
    'Tb': Color(0xFF30FFC7), 'Dy': Color(0xFF1FFFC7), 'Ho': Color(0xFF00FF9C), 'Er': Color(0xFF00E675),
    'Tm': Color(0xFF00D452), 'Yb': Color(0xFF00BF38), 'Lu': Color(0xFF00AB24), 'Hf': Color(0xFF4DC2FF),
    'Ta': Color(0xFF4DA6FF), 'W': Color(0xFF2194D6), 'Re': Color(0xFF267DAB), 'Os': Color(0xFF266696),
    'Ir': Color(0xFF175487), 'Pt': Color(0xFFD0D0E0), 'Au': Color(0xFFFFD123), 'Hg': Color(0xFFB8B8D0),
    'Tl': Color(0xFFA6544D), 'Pb': Color(0xFF575961), 'Bi': Color(0xFF9E4FB5), 'Po': Color(0xFFAB5C00),
    'At': Color(0xFF754F45), 'Rn': Color(0xFF428296), 'Fr': Color(0xFF420066), 'Ra': Color(0xFF007D00),
    'Ac': Color(0xFF70ABFA), 'Th': Color(0xFF00BAFF), 'Pa': Color(0xFF00A1FF), 'U': Color(0xFF008FFF),
    'Np': Color(0xFF0080FF), 'Pu': Color(0xFF006BFF), 'Am': Color(0xFF545CF2), 'Cm': Color(0xFF785CE3),
    'Bk': Color(0xFF8A4FE3), 'Cf': Color(0xFFA136D4), 'Es': Color(0xFFB31FD4), 'Fm': Color(0xFFB31FBA),
    'Md': Color(0xFFB30DA6), 'No': Color(0xFFBD0D87), 'Lr': Color(0xFFC70066), 'Rf': Color(0xFFCC0059),
    'Db': Color(0xFFD1004F), 'Sg': Color(0xFFD90045), 'Bh': Color(0xFFE00038), 'Hs': Color(0xFFE6002E),
    'Mt': Color(0xFFEB0026), 'Ds': Color(0xFFEB0026), 'Rg': Color(0xFFEB0026), 'Cn': Color(0xFFEB0026),
    'Nh': Color(0xFFEB0026), 'Fl': Color(0xFFEB0026), 'Mc': Color(0xFFEB0026), 'Lv': Color(0xFFEB0026),
    'Ts': Color(0xFFEB0026), 'Og': Color(0xFFEB0026),
  };

  static const Map<String, double> vdwRadii = {
    'H': 1.20, 'He': 1.40, 'Li': 1.82, 'Be': 1.53, 'B': 1.92, 'C': 1.70, 'N': 1.55, 'O': 1.52,
    'F': 1.47, 'Ne': 1.54, 'Na': 2.27, 'Mg': 1.73, 'Al': 1.84, 'Si': 2.10, 'P': 1.80, 'S': 1.80,
    'Cl': 1.75, 'Ar': 1.88, 'K': 2.75, 'Ca': 2.31, 'Sc': 2.11, 'Ti': 2.00, 'V': 2.00, 'Cr': 2.00,
    'Mn': 2.00, 'Fe': 2.00, 'Co': 2.00, 'Ni': 1.63, 'Cu': 1.40, 'Zn': 1.39, 'Ga': 1.87, 'Ge': 2.11,
    'As': 1.85, 'Se': 1.90, 'Br': 1.85, 'Kr': 2.02, 'Rb': 3.03, 'Sr': 2.49, 'Y': 2.00, 'Zr': 2.00,
    'Nb': 2.00, 'Mo': 2.00, 'Tc': 2.00, 'Ru': 2.00, 'Rh': 2.00, 'Pd': 1.63, 'Ag': 1.72, 'Cd': 1.58,
    'In': 1.93, 'Sn': 2.17, 'Sb': 2.06, 'Te': 2.06, 'I': 1.98, 'Xe': 2.16, 'Cs': 3.43, 'Ba': 2.68,
    'La': 2.00, 'Ce': 2.00, 'Pr': 2.00, 'Nd': 2.00, 'Pm': 2.00, 'Sm': 2.00, 'Eu': 2.00, 'Gd': 2.00,
    'Tb': 2.00, 'Dy': 2.00, 'Ho': 2.00, 'Er': 2.00, 'Tm': 2.00, 'Yb': 2.00, 'Lu': 2.00, 'Hf': 2.00,
    'Ta': 2.00, 'W': 2.00, 'Re': 2.00, 'Os': 2.00, 'Ir': 2.00, 'Pt': 1.72, 'Au': 1.66, 'Hg': 1.55,
    'Tl': 1.96, 'Pb': 2.02, 'Bi': 2.07, 'Po': 1.97, 'At': 2.02, 'Rn': 2.20, 'Fr': 3.48, 'Ra': 2.83,
    'Ac': 2.00, 'Th': 2.00, 'Pa': 2.00, 'U': 1.86, 'Np': 2.00, 'Pu': 2.00, 'Am': 2.00, 'Cm': 2.00,
    'Bk': 2.00, 'Cf': 2.00, 'Es': 2.00, 'Fm': 2.00, 'Md': 2.00, 'No': 2.00, 'Lr': 2.00, 'Rf': 2.00,
    'Db': 2.00, 'Sg': 2.00, 'Bh': 2.00, 'Hs': 2.00, 'Mt': 2.00, 'Ds': 2.00, 'Rg': 2.00, 'Cn': 2.00,
    'Nh': 2.00, 'Fl': 2.00, 'Mc': 2.00, 'Lv': 2.00, 'Ts': 2.00, 'Og': 2.00,
  };

  static const Map<String, double> covalentRadii = {
    'H': 0.31, 'He': 0.28, 'Li': 1.28, 'Be': 0.96, 'B': 0.84, 'C': 0.76, 'N': 0.71, 'O': 0.66,
    'F': 0.57, 'Ne': 0.58, 'Na': 1.66, 'Mg': 1.41, 'Al': 1.21, 'Si': 1.11, 'P': 1.07, 'S': 1.05,
    'Cl': 1.02, 'Ar': 1.06, 'K': 2.03, 'Ca': 1.76, 'Sc': 1.70, 'Ti': 1.60, 'V': 1.53, 'Cr': 1.39,
    'Mn': 1.39, 'Fe': 1.32, 'Co': 1.26, 'Ni': 1.24, 'Cu': 1.32, 'Zn': 1.22, 'Ga': 1.22, 'Ge': 1.20,
    'As': 1.19, 'Se': 1.20, 'Br': 1.20, 'Kr': 1.16, 'Rb': 2.20, 'Sr': 1.95, 'Y': 1.90, 'Zr': 1.75,
    'Nb': 1.64, 'Mo': 1.54, 'Tc': 1.47, 'Ru': 1.46, 'Rh': 1.42, 'Pd': 1.39, 'Ag': 1.45, 'Cd': 1.44,
    'In': 1.42, 'Sn': 1.39, 'Sb': 1.39, 'Te': 1.38, 'I': 1.39, 'Xe': 1.40, 'Cs': 2.44, 'Ba': 2.15,
    'La': 2.07, 'Ce': 2.04, 'Pr': 2.03, 'Nd': 2.01, 'Pm': 1.99, 'Sm': 1.98, 'Eu': 1.98, 'Gd': 1.96,
    'Tb': 1.94, 'Dy': 1.92, 'Ho': 1.92, 'Er': 1.89, 'Tm': 1.90, 'Yb': 1.87, 'Lu': 1.87, 'Hf': 1.75,
    'Ta': 1.70, 'W': 1.62, 'Re': 1.51, 'Os': 1.44, 'Ir': 1.41, 'Pt': 1.36, 'Au': 1.36, 'Hg': 1.32,
    'Tl': 1.45, 'Pb': 1.46, 'Bi': 1.48, 'Po': 1.40, 'At': 1.50, 'Rn': 1.50, 'Fr': 2.60, 'Ra': 2.21,
    'Ac': 2.15, 'Th': 2.06, 'Pa': 2.00, 'U': 1.96, 'Np': 1.90, 'Pu': 1.87, 'Am': 1.80, 'Cm': 1.69,
    'Bk': 1.60, 'Cf': 1.60, 'Es': 1.60, 'Fm': 1.60, 'Md': 1.60, 'No': 1.60, 'Lr': 1.60, 'Rf': 1.60,
    'Db': 1.60, 'Sg': 1.60, 'Bh': 1.60, 'Hs': 1.60, 'Mt': 1.60, 'Ds': 1.60, 'Rg': 1.60, 'Cn': 1.60,
    'Nh': 1.60, 'Fl': 1.60, 'Mc': 1.60, 'Lv': 1.60, 'Ts': 1.60, 'Og': 1.60,
  };

  static const Map<String, double> atomicMasses = {
    'H': 1.008, 'He': 4.0026, 'Li': 6.94, 'Be': 9.0122, 'B': 10.81, 'C': 12.011, 'N': 14.007, 'O': 15.999,
    'F': 18.998, 'Ne': 20.180, 'Na': 22.990, 'Mg': 24.305, 'Al': 26.982, 'Si': 28.085, 'P': 30.974, 'S': 32.06,
    'Cl': 35.45, 'Ar': 39.948, 'K': 39.098, 'Ca': 40.078, 'Sc': 44.956, 'Ti': 47.867, 'V': 50.942, 'Cr': 51.996,
    'Mn': 54.938, 'Fe': 55.845, 'Co': 58.933, 'Ni': 58.693, 'Cu': 63.546, 'Zn': 65.38, 'Ga': 69.723, 'Ge': 72.630,
    'As': 74.922, 'Se': 78.971, 'Br': 79.904, 'Kr': 83.798, 'Rb': 85.468, 'Sr': 87.62, 'Y': 88.906, 'Zr': 91.224,
    'Nb': 92.906, 'Mo': 95.95, 'Tc': 98.0, 'Ru': 101.07, 'Rh': 102.91, 'Pd': 106.42, 'Ag': 107.87, 'Cd': 112.41,
    'In': 114.82, 'Sn': 118.71, 'Sb': 121.76, 'Te': 127.60, 'I': 126.90, 'Xe': 131.29, 'Cs': 132.91, 'Ba': 137.33,
    'La': 138.91, 'Ce': 140.12, 'Pr': 140.91, 'Nd': 144.24, 'Pm': 145.0, 'Sm': 150.36, 'Eu': 151.96, 'Gd': 157.25,
    'Tb': 158.93, 'Dy': 162.50, 'Ho': 164.93, 'Er': 167.26, 'Tm': 168.93, 'Yb': 173.05, 'Lu': 174.97, 'Hf': 178.49,
    'Ta': 180.95, 'W': 183.84, 'Re': 186.21, 'Os': 190.23, 'Ir': 192.22, 'Pt': 195.08, 'Au': 196.97, 'Hg': 200.59,
    'Tl': 204.38, 'Pb': 207.2, 'Bi': 208.98, 'Po': 209.0, 'At': 210.0, 'Rn': 222.0, 'Fr': 223.0, 'Ra': 226.0,
    'Ac': 227.0, 'Th': 232.04, 'Pa': 231.04, 'U': 238.03, 'Np': 237.0, 'Pu': 244.0, 'Am': 243.0, 'Cm': 247.0,
    'Bk': 247.0, 'Cf': 251.0, 'Es': 252.0, 'Fm': 257.0, 'Md': 258.0, 'No': 259.0, 'Lr': 266.0, 'Rf': 267.0,
    'Db': 268.0, 'Sg': 269.0, 'Bh': 270.0, 'Hs': 270.0, 'Mt': 278.0, 'Ds': 281.0, 'Rg': 282.0, 'Cn': 285.0,
    'Nh': 286.0, 'Fl': 289.0, 'Mc': 290.0, 'Lv': 293.0, 'Ts': 294.0, 'Og': 294.0,
  };

  /// Element symbols ordered by atomic number (Z = index + 1).
  ///
  /// This mirrors the key order of [colors], which is already Z-ordered; it is
  /// materialised once so CJSON/SDF writers can map symbol ⇄ Z without a second
  /// lookup table drifting out of sync.
  static final List<String> symbolsByAtomicNumber = colors.keys.toList(growable: false);

  /// Atomic number for an element symbol, or 0 when unknown.
  static int atomicNumber(String symbol) {
    final index = symbolsByAtomicNumber.indexOf(_canonical(symbol));
    return index < 0 ? 0 : index + 1;
  }

  /// Element symbol for an atomic number, or `'X'` when out of range.
  static String symbolForAtomicNumber(int z) {
    if (z < 1 || z > symbolsByAtomicNumber.length) return 'X';
    return symbolsByAtomicNumber[z - 1];
  }

  /// `c` / `CL` → `C` / `Cl` (first letter upper case, rest lower case).
  static String _canonical(String symbol) {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  /// Normalises an element symbol, falling back to hydrogen for garbage input.
  static String canonicalSymbol(String symbol) {
    final canonical = _canonical(symbol);
    if (canonical.isEmpty) return 'H';
    if (colors.containsKey(canonical)) return canonical;
    // Avogadro occasionally emits "*" for dummy atoms.
    return canonical == '*' ? 'H' : canonical;
  }
}
