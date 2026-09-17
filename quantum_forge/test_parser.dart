import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final res = await XyzParser.parseAsync('''14
EAS: Benzene + Cl2 (reactant)
C     1.400    0.000    0.000
C     0.700    1.212    0.000
C    -0.700    1.212    0.000
C    -1.400    0.000    0.000
C    -0.700   -1.212    0.000
C     0.700   -1.212    0.000
H     2.490    0.000    0.000
H     1.245    2.156    0.000
H    -1.245    2.156    0.000
H    -2.490    0.000    0.000
H    -1.245   -2.156    0.000
H     1.245   -2.156    0.000
Cl    1.400    0.000    2.500
Cl    1.400    0.000    4.500''');
    print('Success: \${res.length} atoms parsed.');
  } catch (e) {
    print('Exception caught: \$e');
  }
}
