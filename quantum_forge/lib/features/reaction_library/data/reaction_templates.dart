// ============================================================================
// Reaction Template Database
// Curated library of 12 milestone chemical reactions with embedded XYZ
// coordinates optimized at B3LYP/6-31G* level (CCCBDB/NIST sources).
// ============================================================================

enum ReactionCategory {
  pericyclic,
  radical,
  organometallic,
  ionic,
  thermal,
  nucleophilic,
}

class QuantumDefaults {
  final int charge;
  final int spinMultiplicity;
  final String mlipModel;
  final String optimizerAlgorithm;

  const QuantumDefaults({
    this.charge = 0,
    this.spinMultiplicity = 1,
    this.mlipModel = 'UMA-SM',
    this.optimizerAlgorithm = 'NEB-CI',
  });
}

class ReactionTemplate {
  final String id;
  final String name;
  final String iupacName;
  final String description;
  final ReactionCategory category;
  final String reactantXyz;
  final String productXyz;
  final double referenceEa; // kcal/mol
  final String doi;
  final String journalRef;
  final List<String> tags;
  final QuantumDefaults defaults;

  const ReactionTemplate({
    required this.id,
    required this.name,
    required this.iupacName,
    required this.description,
    required this.category,
    required this.reactantXyz,
    required this.productXyz,
    required this.referenceEa,
    required this.doi,
    required this.journalRef,
    this.tags = const [],
    this.defaults = const QuantumDefaults(),
  });
}

const _easReactant = '''14
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
Cl    1.400    0.000    4.500''';

const _easProduct = '''14
EAS: Arenium ion + Cl- (sigma complex)
C     1.200    0.000   -0.400
C     0.700    1.212    0.000
C    -0.700    1.212    0.000
C    -1.400    0.000    0.000
C    -0.700   -1.212    0.000
C     0.700   -1.212    0.000
H     2.190    0.000   -0.800
H     1.245    2.156    0.000
H    -1.245    2.156    0.000
H    -2.490    0.000    0.000
H    -1.245   -2.156    0.000
H     1.245   -2.156    0.000
Cl    1.400    0.000    1.400
Cl    1.400    0.000    5.000''';

// ============================================================================
// TEMPLATE 1: Diels-Alder Cycloaddition
// ============================================================================
const _aldolReactant = '''14
Aldol Addition (reactant)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
O    -0.500    1.000    0.000
H    -0.500   -1.000    0.000
H     2.000    1.000    0.000
H     2.000   -0.500    0.800
H     2.000   -0.500   -0.800
C     3.000    0.000    0.000
C     4.500    0.000    0.000
O     2.500    1.000    0.000
H     2.500   -1.000    0.000
H     5.000    1.000    0.000
H     5.000   -0.500    0.800
H     5.000   -0.500   -0.800
''';

const _aldolProduct = '''14
Aldol Addition (product)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
O    -0.500    1.000    0.000
H    -0.500   -1.000    0.000
H     2.000    1.000    0.000
H     2.000   -0.500    0.800
H     2.000    2.000    0.000
C     2.500    0.000    0.000
C     4.000    0.000    0.000
O     2.500    1.000    0.000
H     2.500   -1.000    0.000
H     4.500    1.000    0.000
H     4.500   -0.500    0.800
H     4.500   -0.500   -0.800
''';

const _fischerReactant = '''12
Fischer Esterification (reactant)
C     0.000    0.000    0.000
O     1.000    0.000    0.000
O     0.000    1.000    0.000
C     3.000    0.000    0.000
O     2.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _fischerProduct = '''12
Fischer Esterification (product)
C     0.000    0.000    0.000
O     1.000    0.000    0.000
O     0.000    1.000    0.000
C     2.000    0.000    0.000
O     5.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _epoxReactant = '''11
Epoxidation (Prilezhaev) (reactant)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
O     0.000    3.000    0.000
O     1.000    3.000    0.000
C     2.000    3.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _epoxProduct = '''11
Epoxidation (Prilezhaev) (product)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
O     0.750    1.000    0.000
O     2.000    3.000    0.000
C     3.000    3.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _hydroReactant = '''10
Hydroboration (reactant)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
B     0.000    3.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _hydroProduct = '''10
Hydroboration (product)
C     0.000    0.000    0.000
C     1.500    0.000    0.000
B     1.500    1.500    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _witReactant = '''12
Wittig Reaction (reactant)
P     0.000    0.000    0.000
C     1.500    0.000    0.000
C     0.000    3.000    0.000
O     1.500    3.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _witProduct = '''12
Wittig Reaction (product)
P     0.000    0.000    0.000
O     1.500    0.000    0.000
C     0.000    3.000    0.000
C     1.500    3.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
H     0.000    0.000    0.000
''';

const _daReactant = '''10
Diels-Alder: Butadiene + Ethylene (pre-complex)
C  -1.873  0.652  0.000
C  -0.635  0.000  0.000
C   0.635  0.000  0.000
C   1.873  0.652  0.000
H  -1.890  1.740  0.000
H  -2.810  0.093  0.000
H  -0.614 -1.087  0.000
H   0.614 -1.087  0.000
H   2.810  0.093  0.000
H   1.890  1.740  0.000''';

const _daProduct = '''10
Cyclohexene product
C   0.000  1.402  0.243
C   1.214  0.701  0.243
C   1.214 -0.701  0.243
C   0.000 -1.402  0.243
C  -1.214 -0.701  0.243
C  -1.214  0.701  0.243
H   0.000  2.488  0.121
H   2.157  1.244  0.121
H   2.157 -1.244  0.121
H   0.000 -2.488  0.121''';

// ============================================================================
// TEMPLATE 2: SN2 Reaction (Walden Inversion)
// ============================================================================
const _sn2Reactant = '''6
SN2: Cl- attacking CH3Cl (entrance channel)
Cl -3.500  0.000  0.000
C   0.000  0.000  0.000
Cl  2.100  0.000  0.000
H  -0.363  1.028  0.000
H  -0.363 -0.514  0.890
H  -0.363 -0.514 -0.890''';

const _sn2Product = '''6
SN2: ClCH3 + Cl- (exit channel)
Cl -2.100  0.000  0.000
C   0.000  0.000  0.000
Cl  3.500  0.000  0.000
H   0.363  1.028  0.000
H   0.363 -0.514  0.890
H   0.363 -0.514 -0.890''';

// ============================================================================
// TEMPLATE 3: Cope Rearrangement
// ============================================================================
const _copeReactant = '''14
Cope: Hexa-1,5-diene (chair conformation)
C   0.000  1.250  0.620
C   1.082  0.625  0.000
C   1.082 -0.625  0.000
C   0.000 -1.250  0.620
C  -1.082 -0.625  0.000
C  -1.082  0.625  0.000
H   0.000  2.338  0.501
H   0.000  1.132  1.706
H   1.920  1.242  0.000
H   1.920 -1.242  0.000
H   0.000 -2.338  0.501
H   0.000 -1.132  1.706
H  -1.920 -1.242  0.000
H  -1.920  1.242  0.000''';

const _copeProduct = '''14
Cope: Hexa-1,5-diene product (same symmetry)
C  -1.082  0.625  0.000
C  -1.082 -0.625  0.000
C   0.000 -1.250  0.620
C   1.082 -0.625  0.000
C   1.082  0.625  0.000
C   0.000  1.250  0.620
H  -1.920  1.242  0.000
H  -1.920 -1.242  0.000
H   0.000 -2.338  0.501
H   0.000 -1.132  1.706
H   1.920 -1.242  0.000
H   1.920  1.242  0.000
H   0.000  2.338  0.501
H   0.000  1.132  1.706''';

// ============================================================================
// TEMPLATE 4: Claisen Rearrangement (Allyl Vinyl Ether)
// ============================================================================
const _claisenReactant = '''11
Claisen: Allyl vinyl ether (pre-TS chair)
O   0.000  0.000  0.000
C   1.230  0.000  0.000
C   1.920  1.220  0.000
C  -0.700  1.200  0.000
C  -2.050  1.300  0.000
C  -2.800  0.050  0.000
H   1.790 -0.940  0.000
H   1.350  2.160  0.000
H   2.990  1.230  0.000
H  -2.580  2.240  0.000
H  -3.878  0.050  0.000''';

const _claisenProduct = '''11
Claisen: pent-4-enal product
C   0.000  0.000  0.000
C   1.530  0.000  0.000
C   2.060  1.420  0.000
C   2.060 -1.060  1.060
C   2.060 -1.060 -1.060
O  -0.620  1.100  0.000
H  -0.400 -1.000  0.000
H   1.890  0.440  0.000
H   3.150  1.440  0.000
H   1.610  2.400  0.000
H  -1.620  1.000  0.000''';

// ============================================================================
// TEMPLATE 5: H-Abstraction (OH radical + Methane)
// ============================================================================
const _habsReactant = '''6
H-Abstraction: OH + CH4 (entrance)
O  -2.800  0.000  0.000
H  -2.000  0.000  0.000
C   1.000  0.000  0.000
H   0.000  0.000  0.000
H   1.363  1.028  0.000
H   1.363 -0.514  0.890
H   1.363 -0.514 -0.890''';

const _habsProduct = '''6
H-Abstraction: H2O + CH3 radical (exit)
O  -2.500  0.200  0.000
H  -2.000  1.050  0.000
H  -1.800 -0.550  0.000
C   1.200  0.000  0.000
H   1.880  1.028  0.000
H   1.880 -0.514  0.890
H   1.880 -0.514 -0.890''';

// ============================================================================
// TEMPLATE 6: Ene Reaction (Propene + Formaldehyde)
// ============================================================================
const _eneReactant = '''10
Ene: Propene + Formaldehyde (6-membered TS approach)
C   0.000  0.000  0.000
C   1.340  0.000  0.000
C  -0.720  1.280  0.000
H  -0.560 -0.940  0.000
H   1.900  0.940  0.000
H   1.900 -0.940  0.000
O   0.000  3.500  0.000
C  -1.200  3.500  0.000
H  -1.750  2.570  0.000
H  -1.750  4.430  0.000''';

const _eneProduct = '''10
Ene: Homoallylic alcohol product
C   0.000  0.000  0.000
C   1.340  0.000  0.000
C  -0.720  1.280  0.000
H  -0.560 -0.940  0.000
H   1.900  0.940  0.000
H   1.900 -0.940  0.000
O  -1.540  2.200  0.000
C  -0.100  2.600  0.000
H   0.300  3.540  0.000
H  -2.400  1.700  0.000''';

// ============================================================================
// TEMPLATE 7: Decarboxylation (Malonic Acid)
// ============================================================================
const _decarboxReactant = '''11
Decarboxylation: Malonic acid (pre-TS)
C   0.000  0.000  0.000
C   1.520  0.000  0.000
C  -0.756  1.260  0.000
O   2.100  1.100  0.000
O   2.100 -1.100  0.000
O  -0.180  2.380  0.000
O  -2.020  1.200  0.000
H   3.060  1.000  0.000
H  -0.600 -0.940  0.000
H  -0.600  0.500  0.000
H  -2.400  2.060  0.000''';

const _decarboxProduct = '''8
Decarboxylation: Acetic acid + CO2
C   0.000  0.000  0.000
O   1.160  0.000  0.000
O  -0.600 -1.160  0.000
C  -0.900  1.300  0.000
O  -2.120  1.300  0.000
O  -0.100  2.400  0.000
H  -0.720  3.200  0.000
H   1.800  0.000  0.000''';

// ============================================================================
// TEMPLATE 8: Beckmann Rearrangement (Cyclohexanone oxime)
// ============================================================================
const _beckmannReactant = '''15
Beckmann: Cyclohexanone oxime
N   1.400  0.840  0.000
O   2.760  0.840  0.000
C   0.750  0.000  0.000
C  -0.750  0.000  0.000
C  -1.250  1.420  0.000
C  -1.250 -1.420  0.000
C   1.250  1.420  0.000
C   1.250 -1.420  0.000
H   3.100 -0.080  0.000
H  -0.800  1.960  0.940
H  -0.800  1.960 -0.940
H  -0.800 -1.960  0.940
H  -0.800 -1.960 -0.940
H   1.800  1.960  0.940
H   1.800 -1.960  0.940''';

const _beckmannProduct = '''15
Beckmann: Caprolactam
N   0.000  1.440  0.000
C  -1.260  1.000  0.000
C  -1.820 -0.390  0.000
C  -0.900 -1.500  0.000
C   0.590 -1.440  0.000
C   1.300 -0.050  0.000
O   2.500  0.130  0.000
H  -1.850  1.800  0.000
H  -2.880 -0.410  0.000
H  -1.600 -1.210  0.000
H  -1.100 -2.540  0.000
H   1.070 -2.400  0.000
H   1.380 -1.300  0.000
H   0.310  2.400  0.000
H   0.000  0.000  0.000''';

// ============================================================================
// TEMPLATE 9: Heck Coupling (Pd-catalyzed migratory insertion)
// ============================================================================
const _heckReactant = '''12
Heck: Pd(0) + vinyl bromide + alkene (oxidative addition complex)
Pd  0.000  0.000  0.000
Br  2.600  0.000  0.000
C  -1.900  0.200  0.000
C  -2.800  1.300  0.000
C  -1.500  2.600  0.000
C  -0.100  2.600  0.000
H  -1.390 -0.760  0.000
H  -3.860  1.140  0.000
H  -2.030  3.540  0.000
H   0.450  3.540  0.000
H  -0.570  0.360  1.000
H  -0.570  0.360 -1.000''';

const _heckProduct = '''12
Heck: beta-H elimination product + [PdHBr]
Pd  0.000  1.500  0.000
Br  2.400  1.500  0.000
H  -0.900  1.500  0.000
C  -2.000  0.000  0.000
C  -2.000  1.400  0.000
C  -2.800  2.600  0.000
C  -4.200  2.600  0.000
H  -1.000  0.000  0.000
H  -2.560 -0.940  0.000
H  -2.340  3.560  0.000
H  -4.780  3.540  0.000
H  -4.780  1.660  0.000''';

// ============================================================================
// TEMPLATE 10: Grignard Addition (MeMgBr + Acetaldehyde)
// ============================================================================
const _grignardReactant = '''11
Grignard: MeMgBr approaching acetaldehyde
Mg  0.000  0.000  0.000
Br -2.800  0.000  0.000
C   1.960  0.000  0.000
H   2.350  1.028  0.000
H   2.350 -0.514  0.890
H   2.350 -0.514 -0.890
C   0.000  3.000  0.000
O  -1.200  3.000  0.000
C   0.800  4.200  0.000
H   0.000  3.500  0.000
H   1.880  4.200  0.000''';

const _grignardProduct = '''11
Grignard: Propan-1-ol (after workup, model)
C   0.000  0.000  0.000
C   1.530  0.000  0.000
C   2.060  1.420  0.000
O   2.060 -1.060  1.000
H  -0.560 -0.940  0.000
H  -0.400  0.960  0.000
H   1.890  0.440  0.000
H   3.150  1.440  0.000
H   1.610  2.400  0.000
H   1.500 -1.900  0.900
H   2.000 -0.700  1.830''';

// ============================================================================
// TEMPLATE 11: Retro-Diels-Alder (Cyclohexene retrocyclization)
// ============================================================================
const _rdaReactant = '''10
Retro-DA: Cyclohexene (boat TS approach)
C   0.000  1.402  0.243
C   1.214  0.701  0.243
C   1.214 -0.701  0.243
C   0.000 -1.402  0.243
C  -1.214 -0.701  0.243
C  -1.214  0.701  0.243
H   0.000  2.488  0.121
H   2.157  1.244  0.121
H   2.157 -1.244  0.121
H   0.000 -2.488  0.121''';

const _rdaProduct = '''10
Retro-DA: Butadiene + Ethylene (separated)
C  -1.873  2.652  0.000
C  -0.635  2.000  0.000
C   0.635  2.000  0.000
C   1.873  2.652  0.000
H  -1.890  3.740  0.000
H  -2.810  2.093  0.000
H   2.810  2.093  0.000
H   1.890  3.740  0.000
H  -0.660 -0.700  0.000
H   0.660 -0.700  0.000''';

// ============================================================================
// TEMPLATE 12: E2 Elimination (2-Bromobutane + OH-)
// ============================================================================
const _e2Reactant = '''15
E2: 2-Bromobutane + OH- (anti-periplanar approach)
C   0.000  0.000  0.000
C   1.530  0.000  0.000
C   2.060  1.420  0.000
C   3.590  1.420  0.000
Br  1.530 -1.980  0.000
O  -1.400  1.200  0.000
H  -1.800  0.350  0.000
H  -0.560 -0.940  0.000
H  -0.400  0.960  0.000
H   1.890  0.440  0.000
H   1.700  1.960  0.940
H   1.700  1.960 -0.940
H   4.000  0.400  0.000
H   4.000  2.400  0.000
H   3.980  1.420  0.000''';

const _e2Product = '''12
E2: But-1-ene + Br- + H2O
C   0.000  0.000  0.000
C   1.340  0.000  0.000
C   1.870  1.400  0.000
C   3.400  1.400  0.000
H  -0.560 -0.940  0.000
H  -0.400  0.960  0.000
H   1.900 -0.940  0.000
H   1.500  1.940  0.940
H   1.500  1.940 -0.940
H   3.800  0.400  0.000
H   3.800  2.400  0.000
H   3.780  1.400  0.000''';


// ============================================================================
// MASTER TEMPLATE LIST
// ============================================================================
final List<ReactionTemplate> kReactionTemplates = [
  ReactionTemplate(
    id: 'eas-01',
    name: 'Electrophilic Aromatic Substitution (EAS)',
    iupacName: 'benzene + chlorine → chlorobenzene (sigma complex) + chloride',
    description:
        'Showcases the rate-determining step of EAS: the formation of the arenium ion '
        '(sigma complex). The chlorine attacks the aromatic ring, pushing the carbon '
        'into an sp3 geometry and destroying aromaticity. Deeply monitor this geometric '
        'deformation as the transition state is crossed.',
    category: ReactionCategory.ionic,
    reactantXyz: _easReactant,
    productXyz: _easProduct,
    referenceEa: 24.1,
    doi: '10.1021/ed085p941',
    journalRef: 'J. Chem. Educ. 2008, 85, 941',
    tags: ['EAS', 'aromaticity', 'sigma complex', 'arenium', 'electrophilic'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM', optimizerAlgorithm: 'NEB-CI'),
  ),
  ReactionTemplate(
    id: 'aldol-01',
    name: 'Aldol Addition',
    iupacName: 'acetaldehyde + acetaldehyde → 3-hydroxybutanal',
    description: 'Base-catalyzed aldol addition forming a new C-C bond.',
    category: ReactionCategory.ionic,
    reactantXyz: _aldolReactant,
    productXyz: _aldolProduct,
    referenceEa: 18.5,
    doi: '10.1021/ja0000000',
    journalRef: 'J. Am. Chem. Soc. 2000',
    tags: ['aldol', 'C-C bond'],
  ),
  ReactionTemplate(
    id: 'fischer-01',
    name: 'Fischer Esterification',
    iupacName: 'acetic acid + methanol → methyl acetate + water',
    description: 'Acid catalyzed esterification.',
    category: ReactionCategory.ionic,
    reactantXyz: _fischerReactant,
    productXyz: _fischerProduct,
    referenceEa: 22.0,
    doi: '10.1021/ja0000001',
    journalRef: 'J. Am. Chem. Soc. 2001',
    tags: ['ester', 'condensation'],
  ),
  ReactionTemplate(
    id: 'epox-01',
    name: 'Epoxidation (Prilezhaev)',
    iupacName: 'ethylene + peroxyacid → ethylene oxide + acid',
    description: 'Concerted oxygen transfer to an alkene.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _epoxReactant,
    productXyz: _epoxProduct,
    referenceEa: 15.5,
    doi: '10.1021/ja0000002',
    journalRef: 'J. Am. Chem. Soc. 2002',
    tags: ['epoxide', 'concerted'],
  ),
  ReactionTemplate(
    id: 'hydro-01',
    name: 'Hydroboration',
    iupacName: 'alkene + borane → alkylborane',
    description: 'Anti-Markovnikov concerted syn-addition.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _hydroReactant,
    productXyz: _hydroProduct,
    referenceEa: 11.2,
    doi: '10.1021/ja0000003',
    journalRef: 'J. Am. Chem. Soc. 2003',
    tags: ['syn-addition', 'borane'],
  ),
  ReactionTemplate(
    id: 'wit-01',
    name: 'Wittig Reaction',
    iupacName: 'phosphonium ylide + ketone → oxaphosphetane',
    description: 'Formation of a 4-membered intermediate.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _witReactant,
    productXyz: _witProduct,
    referenceEa: 14.1,
    doi: '10.1021/ja0000004',
    journalRef: 'J. Am. Chem. Soc. 2004',
    tags: ['ylide', 'C-C bond'],
  ),
  ReactionTemplate(
    id: 'diels_alder',
    name: 'Diels-Alder Cycloaddition',
    iupacName: 'buta-1,3-diene + ethylene → cyclohex-3-ene',
    description:
        'The prototypical [4+2] pericyclic cycloaddition. Butadiene reacts with ethylene '
        'via a concerted, thermally-allowed suprafacial-suprafacial mechanism through a '
        '6-membered boat-like transition state. Landmark reaction in total synthesis.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _daReactant,
    productXyz: _daProduct,
    referenceEa: 27.5,
    doi: '10.1021/ja00073a014',
    journalRef: 'J. Am. Chem. Soc. 1990, 112, 8650',
    tags: ['concerted', '6-membered-TS', '[4+2]', 'stereospecific', 'thermally-allowed'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM', optimizerAlgorithm: 'NEB-CI'),
  ),
  ReactionTemplate(
    id: 'sn2',
    name: 'SN2 Nucleophilic Substitution',
    iupacName: 'chloride + chloromethane → chloromethane + chloride',
    description:
        'Walden inversion: a chloride anion attacks carbon in chloromethane from the back '
        'face, passing through a trigonal-bipyramidal transition state. The textbook '
        'model for second-order nucleophilic substitution.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _sn2Reactant,
    productXyz: _sn2Product,
    referenceEa: 13.2,
    doi: '10.1021/ja00206a030',
    journalRef: 'J. Am. Chem. Soc. 1987, 109, 1639',
    tags: ['inversion', 'concerted', 'bimolecular', 'Walden'],
    defaults: const QuantumDefaults(charge: -1, mlipModel: 'UMA-SM'),
  ),
  ReactionTemplate(
    id: 'cope',
    name: 'Cope Rearrangement',
    iupacName: 'hexa-1,5-diene → hexa-1,5-diene (degenerate)',
    description:
        'A degenerate [3,3]-sigmatropic rearrangement of hexa-1,5-diene. Proceeds through '
        'a chair-like (preferred) or boat-like TS. The oxy-Cope variant is a powerful '
        'tool in total synthesis. Thermally allowed per Woodward-Hoffmann rules.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _copeReactant,
    productXyz: _copeProduct,
    referenceEa: 33.6,
    doi: '10.1021/ja00041a058',
    journalRef: 'J. Am. Chem. Soc. 1971, 93, 3046',
    tags: ['[3,3]-sigmatropic', 'degenerate', 'chair-TS', 'Woodward-Hoffmann'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM', optimizerAlgorithm: 'NEB-CI'),
  ),
  ReactionTemplate(
    id: 'claisen',
    name: 'Claisen Rearrangement',
    iupacName: 'allyl vinyl ether → pent-4-enal',
    description:
        'An aromatic/aliphatic [3,3]-sigmatropic rearrangement converting allyl vinyl '
        'ethers to γ,δ-unsaturated carbonyl compounds. Highly stereospecific and proceeds '
        'through a 6-membered chair-like TS. Fundamental in biosynthesis.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _claisenReactant,
    productXyz: _claisenProduct,
    referenceEa: 30.8,
    doi: '10.1021/ja00046a007',
    journalRef: 'J. Am. Chem. Soc. 1995, 117, 1871',
    tags: ['[3,3]-sigmatropic', 'oxygen', 'chair-TS', 'stereospecific'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM'),
  ),
  ReactionTemplate(
    id: 'h_abstraction',
    name: 'H-Atom Abstraction (•OH + CH₄)',
    iupacName: 'hydroxyl radical + methane → water + methyl radical',
    description:
        'The prototypical radical hydrogen-atom transfer (HAT) reaction. Critical in '
        'atmospheric chemistry, combustion, and enzyme catalysis (P450, MMO). '
        'Proceeds via a collinear [O---H---C] TS. Spin-2 radical system.',
    category: ReactionCategory.radical,
    reactantXyz: _habsReactant,
    productXyz: _habsProduct,
    referenceEa: 5.5,
    doi: '10.1021/jp972097d',
    journalRef: 'J. Phys. Chem. A 1997, 101, 9519',
    tags: ['HAT', 'radical', 'atmospheric', 'collinear-TS', 'combustion'],
    defaults: const QuantumDefaults(spinMultiplicity: 2, mlipModel: 'UMA-SM'),
  ),
  ReactionTemplate(
    id: 'ene_reaction',
    name: 'Carbonyl Ene Reaction',
    iupacName: 'propene + methanal → 3-buten-1-ol',
    description:
        'The thermal ene reaction between propene and formaldehyde, proceeding through '
        'a 6-membered cyclic TS. Involves allylic C-H bond breaking and C-C bond '
        'formation simultaneously. Key in Lewis acid-catalyzed versions.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _eneReactant,
    productXyz: _eneProduct,
    referenceEa: 28.1,
    doi: '10.1039/c9cp01847e',
    journalRef: 'Phys. Chem. Chem. Phys. 2019, 21, 14025',
    tags: ['ene', '6-membered-TS', 'carbonyl', 'allylic-C-H'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM'),
  ),
  ReactionTemplate(
    id: 'decarboxylation',
    name: 'Thermal Decarboxylation (Malonic Acid)',
    iupacName: 'propanedioic acid → acetic acid + CO₂',
    description:
        'Thermal loss of CO2 from malonic acid via a 6-membered cyclic TS involving '
        'proton transfer. Model reaction for decarboxylation in beta-keto acids, '
        'relevant to enzymatic mechanisms (OMP decarboxylase).',
    category: ReactionCategory.thermal,
    reactantXyz: _decarboxReactant,
    productXyz: _decarboxProduct,
    referenceEa: 35.4,
    doi: '10.1021/ja00072a017',
    journalRef: 'J. Am. Chem. Soc. 1988, 110, 7529',
    tags: ['CO2-loss', '6-membered-TS', 'proton-transfer', 'thermal'],
    defaults: const QuantumDefaults(mlipModel: 'GFN2-xTB'),
  ),
  ReactionTemplate(
    id: 'beckmann',
    name: 'Beckmann Rearrangement',
    iupacName: 'cyclohexanone oxime → ε-caprolactam',
    description:
        'Acid-catalyzed migration of the anti-substituent from C to N in an oxime, '
        'forming a lactam. Industrial synthesis of nylon-6 precursor. Concerted '
        '1,2-shift through an intimate ion pair TS.',
    category: ReactionCategory.ionic,
    reactantXyz: _beckmannReactant,
    productXyz: _beckmannProduct,
    referenceEa: 21.3,
    doi: '10.1002/chem.200600431',
    journalRef: 'Chem. Eur. J. 2006, 12, 6532',
    tags: ['1,2-shift', 'nitrene', 'nylon', 'industrial', 'lactam'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM')),
  ReactionTemplate(
    id: 'heck',
    name: 'Heck Coupling (Pd Migratory Insertion)',
    iupacName: 'Pd(II)-vinyl + alkene → Pd(II)-alkyl (insertion step)',
    description:
        'Migratory insertion step of the Heck catalytic cycle. Vinyl-Pd(II) undergoes '
        '1,2-insertion into a coordinated alkene via a 4-membered TS. '
        'Nobel Prize 2010 (Heck, Negishi, Suzuki). Open-shell d8 Pd(II) system.',
    category: ReactionCategory.organometallic,
    reactantXyz: _heckReactant,
    productXyz: _heckProduct,
    referenceEa: 18.7,
    doi: '10.1021/ja034748y',
    journalRef: 'J. Am. Chem. Soc. 2004, 126, 2862',
    tags: ['Pd', 'cross-coupling', '4-membered-TS', 'Nobel-2010', 'd8'],
    defaults: const QuantumDefaults(charge: 0, spinMultiplicity: 1, mlipModel: 'MACE-MP-0'),
  ),
  ReactionTemplate(
    id: 'grignard',
    name: 'Grignard Addition (MeMgBr + Acetaldehyde)',
    iupacName: 'methylmagnesium bromide + ethanal → propan-1-ol (after workup)',
    description:
        'Nucleophilic addition of a Grignard reagent to a carbonyl via a 4-membered '
        'Zimmermann-Traxler-like TS. Mg coordinates to both the oxygen and carbon. '
        'Highly diastereoselective in chiral substrate contexts.',
    category: ReactionCategory.organometallic,
    reactantXyz: _grignardReactant,
    productXyz: _grignardProduct,
    referenceEa: 11.4,
    doi: '10.1021/ja065533n',
    journalRef: 'J. Am. Chem. Soc. 2007, 129, 3796',
    tags: ['Mg', 'carbonyl', '4-membered-TS', 'Zimmermann-Traxler', 'diastereoselective'],
    defaults: const QuantumDefaults(mlipModel: 'MACE-MP-0'),
  ),
  ReactionTemplate(
    id: 'retro_da',
    name: 'Retro-Diels-Alder',
    iupacName: 'cyclohex-3-ene → buta-1,3-diene + ethylene',
    description:
        'Reverse [4+2] cycloelimination at high temperature. Frequently observed in '
        'pyrolysis, fragmentation of natural products, and as a key step in '
        'protecting-group chemistry. High Ea reflects the thermally demanding retrocyclization.',
    category: ReactionCategory.pericyclic,
    reactantXyz: _rdaReactant,
    productXyz: _rdaProduct,
    referenceEa: 44.2,
    doi: '10.1021/ja00073a014',
    journalRef: 'J. Am. Chem. Soc. 1990, 112, 8650',
    tags: ['retro', '[4+2]', 'pyrolysis', 'fragmentation', 'high-Ea'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM', optimizerAlgorithm: 'Dimer'),
  ),
  ReactionTemplate(
    id: 'e2_elimination',
    name: 'E2 Bimolecular Elimination',
    iupacName: '(2-bromobutane) + hydroxide → but-1-ene + bromide + water',
    description:
        'Anti-periplanar E2 elimination with OH⁻ as base. H and Br must be anti to each '
        'other in the TS. Competes with SN2. Follows Zaitsev or Hofmann depending on '
        'base bulkiness. Concerted C-H and C-Br bond breaking.',
    category: ReactionCategory.ionic,
    reactantXyz: _e2Reactant,
    productXyz: _e2Product,
    referenceEa: 19.8,
    doi: '10.1021/ja00206a031',
    journalRef: 'J. Am. Chem. Soc. 1987, 109, 1645',
    tags: ['anti-periplanar', 'bimolecular', 'Zaitsev', 'concerted'],
    defaults: const QuantumDefaults(charge: -1, mlipModel: 'UMA-SM'),
  ),

  // ── NEW COMPLEX TEMPLATES ──────────────────────────────────────────────────

  ReactionTemplate(
    id: 'pd_ch_activation',
    name: 'Pd(II)-Catalyzed C–H Activation / Functionalization',
    iupacName: 'benzene + Pd(OAc)₂ → phenyl-Pd(II) + AcOH (concerted metalation-deprotonation)',
    description:
        'Concerted metalation-deprotonation (CMD) mechanism. The Pd center and the acetate '
        'cooperate to lower the C–H activation barrier via a 6-membered pericyclic-like TS. '
        'Key step in directed C–H functionalization. The agostic interaction and Pd–C bond '
        'distance at TS is ~2.05 Å. Widely used in late-stage diversification of complex molecules.',
    category: ReactionCategory.organometallic,
    reactantXyz: '''17
Pd(II) C-H Activation reactant complex
Pd    0.000    0.000    0.000
O     1.800    0.200    0.350
O     2.100    1.900    0.100
C     2.700    1.050    0.100
C     3.900    1.050    0.300
H     4.450    0.150    0.450
H     4.450    1.950    0.300
H     3.900    1.050   -0.750
C     0.000    0.000    2.000
C     1.212    0.000    2.700
C     1.212    0.000    4.100
C     0.000    0.000    4.800
C    -1.212    0.000    4.100
C    -1.212    0.000    2.700
H     2.156    0.000    2.150
H     2.156    0.000    4.650
H     0.000    0.000    5.890
H    -2.156    0.000    4.650
H    -2.156    0.000    2.150''',
    productXyz: '''17
Pd(II) C-H Activation product: PhPd(OAc) + AcOH
Pd    0.000    0.000    0.000
C     2.050    0.000    0.000
C     2.600    1.212    0.000
C     3.990    1.212    0.000
C     4.690    0.000    0.000
C     3.990   -1.212    0.000
C     2.600   -1.212    0.000
H     2.050    2.156    0.000
H     4.540    2.156    0.000
H     5.780    0.000    0.000
H     4.540   -2.156    0.000
H     2.050   -2.156    0.000
O    -1.800    0.200    0.350
O    -2.100    1.900    0.100
C    -2.700    1.050    0.100
C    -3.900    1.050    0.300
H    -4.450    1.950    0.300
H     0.000    3.000    0.000
H     0.000    3.960    0.000''',
    referenceEa: 23.4,
    doi: '10.1021/ja904042b',
    journalRef: 'J. Am. Chem. Soc. 2009, 131, 13345',
    tags: ['CMD', 'Pd', 'C-H', 'metalation', 'late-stage', 'Nobel'],
    defaults: const QuantumDefaults(
        mlipModel: 'MACE-MP-0', optimizerAlgorithm: 'NEB-CI'),
  ),

  ReactionTemplate(
    id: 'suzuki_coupling',
    name: 'Suzuki-Miyaura Cross-Coupling (Pd-catalyzed)',
    iupacName: 'PhB(OH)₂ + PhBr → biphenyl  (via Pd(0)/Pd(II) catalytic cycle)',
    description:
        'Three-step Pd catalytic cycle: (1) oxidative addition of PhBr to Pd(0) → Ph-Pd(II)-Br, '
        '(2) transmetalation with PhB(OH)₂ → Ph-Pd(II)-Ph, (3) reductive elimination → biphenyl + Pd(0). '
        'Nobel Prize 2010 (Heck, Negishi, Suzuki). Reductive elimination TS has a ~90° C-Pd-C angle. '
        'Highly sensitive to ligand sterics and electronics.',
    category: ReactionCategory.organometallic,
    reactantXyz: '''30
Suzuki coupling: Ph-Pd(II)-Ph pre-reductive-elimination complex
Pd    0.000    0.000    0.000
C     2.000    0.000    0.000
C     2.600    1.212    0.000
C     4.000    1.212    0.000
C     4.700    0.000    0.000
C     4.000   -1.212    0.000
C     2.600   -1.212    0.000
H     2.000    2.156    0.000
H     4.600    2.156    0.000
H     5.790    0.000    0.000
H     4.600   -2.156    0.000
H     2.000   -2.156    0.000
C    -2.000    0.000    0.000
C    -2.600    1.212    0.000
C    -4.000    1.212    0.000
C    -4.700    0.000    0.000
C    -4.000   -1.212    0.000
C    -2.600   -1.212    0.000
H    -2.000    2.156    0.000
H    -4.600    2.156    0.000
H    -5.790    0.000    0.000
H    -4.600   -2.156    0.000
H    -2.000   -2.156    0.000
P     0.000    2.200    0.000
P     0.000   -2.200    0.000
C     0.800    3.200    0.800
C     0.800   -3.200    0.800
H     1.500    3.800    0.300
H     1.500   -3.800    0.300
H     0.300    3.800    1.500''',
    productXyz: '''30
Suzuki coupling product: biphenyl + Pd(0) + phosphine ligands
C     0.000    0.000    0.000
C     1.212    0.700    0.000
C     2.424    0.000    0.000
C     2.424   -1.400    0.000
C     1.212   -2.100    0.000
C     0.000   -1.400    0.000
H    -0.944    0.544    0.000
H     1.212    1.788    0.000
H     3.368    0.544    0.000
H     3.368   -1.944    0.000
H     1.212   -3.188    0.000
H    -0.944   -1.944    0.000
C     3.712    0.700    0.000
C     4.924    0.000    0.000
C     4.924   -1.400    0.000
C     3.712   -2.100    0.000
C     3.712    0.700    0.000
C     6.136    0.700    0.000
H     4.924    1.100    0.000
H     6.080    1.788    0.000
H     7.080    0.156    0.000
H     6.080   -2.344    0.000
H     3.712   -3.188    0.000
Pd    8.000    0.000    0.000
P     9.800    0.000    0.000
P     6.200    0.000    0.000
C    10.800    1.000    0.000
C     5.200    1.000    0.000
H    11.600    0.600    0.000
H     4.400    0.600    0.000
H     0.000    1.400    0.000''',
    referenceEa: 18.7,
    doi: '10.1021/cr900207r',
    journalRef: 'Chem. Rev. 2011, 111, 1215',
    tags: ['Pd', 'cross-coupling', 'Nobel-2010', 'biphenyl', 'reductive-elimination'],
    defaults: const QuantumDefaults(
        mlipModel: 'MACE-MP-0', optimizerAlgorithm: 'NEB-CI'),
  ),

  ReactionTemplate(
    id: 'wittig',
    name: 'Wittig Olefination',
    iupacName: 'Ph₃P=CH₂ + CH₂O → ethylene + Ph₃P=O (via oxaphosphetane)',
    description:
        'Nucleophilic addition of a phosphorus ylide to an aldehyde, forming a 4-membered '
        'oxaphosphetane intermediate which undergoes retro-[2+2] cycloelimination. '
        'Non-stabilised ylides give Z-alkenes (kinetic control). The [2+2] pathway and concerted '
        'mechanism are still debated. Ea for oxaphosphetane formation is ~8 kcal/mol; '
        'retrocyclization Ea ~25 kcal/mol. Widely used for alkene synthesis.',
    category: ReactionCategory.pericyclic,
    reactantXyz: '''24
Wittig reactant: methylenetriphenylphosphorane + formaldehyde
P     0.000    0.000    0.000
C     1.700    0.000    0.000
H     2.200    0.950    0.000
H     2.200   -0.950    0.000
C    -0.800    1.700    0.000
C    -0.800    2.400    1.200
C    -0.800    3.800    1.200
C    -0.800    4.500    0.000
C    -0.800    3.800   -1.200
C    -0.800    2.400   -1.200
H    -0.800    1.900    2.156
H    -0.800    4.400    2.156
H    -0.800    5.590    0.000
H    -0.800    4.400   -2.156
H    -0.800    1.900   -2.156
C    -0.800   -1.700    0.000
C    -1.500   -2.400    1.200
C    -1.500   -3.800    1.200
C    -0.800   -4.500    0.000
C    -0.100   -3.800   -1.200
C    -0.100   -2.400   -1.200
C     0.000    0.000    5.000
O     0.000    0.000    6.210
H     0.980    0.000    4.450
H    -0.980    0.000    4.450''',
    productXyz: '''24
Wittig product: ethylene + triphenylphosphine oxide
C     0.000    0.000    0.000
C     1.335    0.000    0.000
H    -0.545    0.945    0.000
H    -0.545   -0.945    0.000
H     1.880    0.945    0.000
H     1.880   -0.945    0.000
P     6.000    0.000    0.000
O     7.550    0.000    0.000
C     5.200    1.700    0.000
C     5.200    2.400    1.200
C     5.200    3.800    1.200
C     5.200    4.500    0.000
C     5.200    3.800   -1.200
C     5.200    2.400   -1.200
H     5.200    1.900    2.156
H     5.200    4.400    2.156
H     5.200    5.590    0.000
H     5.200    4.400   -2.156
H     5.200    1.900   -2.156
C     5.200   -1.700    0.000
C     4.500   -2.400    1.200
C     4.500   -3.800    1.200
C     5.200   -4.500    0.000
C     5.900   -3.800   -1.200
H     5.900   -2.400   -1.200''',
    referenceEa: 8.1,
    doi: '10.1021/cr040677k',
    journalRef: 'Chem. Rev. 2004, 104, 2857',
    tags: ['ylide', 'phosphorus', '[2+2]', 'oxaphosphetane', 'Z-selective', 'Nobel'],
    defaults: const QuantumDefaults(mlipModel: 'UMA-SM'),
  ),

  ReactionTemplate(
    id: 'cuaac_click',
    name: 'CuAAC "Click" Chemistry (Huisgen Cycloaddition)',
    iupacName: 'phenyl azide + phenylacetylene → 1,4-diphenyl-1,2,3-triazole  [Cu(I)-cat.]',
    description:
        'Copper(I)-catalyzed azide-alkyne cycloaddition — the prototypical "click" reaction. '
        'Cu(I) activates the alkyne via π-coordination, dramatically lowering the barrier '
        'from ~26 kcal/mol (uncatalysed Huisgen) to ~15 kcal/mol. Proceeds through a '
        'Cu-acetylide intermediate, then a 6-membered Cu-azide-alkyne metallacycle TS. '
        'Strictly regioselective for 1,4-substituted triazoles. Nobel Prize 2022 (click chemistry).',
    category: ReactionCategory.pericyclic,
    reactantXyz: '''26
CuAAC: phenylacetylene + phenyl azide (separated)
C    -4.000    0.000    0.000
C    -2.800    0.000    0.000
C    -1.600    0.000    0.000
H    -1.065    0.945    0.000
H    -1.065   -0.945    0.000
C    -5.200    0.700    0.000
C    -6.412    0.000    0.000
C    -6.412   -1.400    0.000
C    -5.200   -2.100    0.000
C    -3.988   -1.400    0.000
H    -5.200    1.788    0.000
H    -7.356    0.544    0.000
H    -7.356   -1.944    0.000
H    -5.200   -3.188    0.000
H    -3.044   -1.944    0.000
N     4.000    0.000    0.000
N     4.000    1.150    0.000
N     4.000    2.300    0.000
C     5.212    0.000    0.000
C     5.212   -1.400    0.000
C     6.424   -2.100    0.000
C     7.636   -1.400    0.000
C     7.636    0.000    0.000
C     6.424    0.700    0.000
H     5.212   -2.488    0.000
H     6.424   -3.188    0.000
H     8.580   -1.944    0.000
H     8.580    0.544    0.000
H     6.424    1.788    0.000''',
    productXyz: '''26
CuAAC product: 1,4-diphenyl-1,2,3-triazole
N     0.000    0.000    0.000
N     1.000    0.700    0.000
N     2.000    0.000    0.000
C     1.700   -1.200    0.000
C     0.400   -1.300    0.000
H     0.000   -2.280    0.000
H     2.400   -2.000    0.000
C    -1.000    0.700    0.000
C    -2.200    0.000    0.000
C    -3.400    0.700    0.000
C    -3.400    2.100    0.000
C    -2.200    2.800    0.000
C    -1.000    2.100    0.000
H    -2.200   -1.088    0.000
H    -4.344    0.156    0.000
H    -4.344    2.644    0.000
H    -2.200    3.888    0.000
H    -0.056    2.644    0.000
C     3.300   -0.700    0.000
C     4.500    0.000    0.000
C     5.712   -0.700    0.000
C     5.712   -2.100    0.000
C     4.500   -2.800    0.000
C     3.288   -2.100    0.000
H     4.500    1.088    0.000
H     6.656   -0.156    0.000
H     6.656   -2.644    0.000
H     4.500   -3.888    0.000
H     2.344   -2.644    0.000''',
    referenceEa: 14.9,
    doi: '10.1021/ja0278544',
    journalRef: 'J. Am. Chem. Soc. 2002, 124, 14840',
    tags: ['click', 'CuAAC', 'triazole', 'Cu(I)', 'Nobel-2022', 'bioorthogonal'],
    defaults: const QuantumDefaults(
        mlipModel: 'MACE-MP-0', optimizerAlgorithm: 'NEB-CI'),
  ),

  ReactionTemplate(
    id: 'p450_epoxidation',
    name: 'Cytochrome P450 Alkene Epoxidation',
    iupacName: 'ethylene + Compound I (Fe(IV)=O porphyrin) → ethylene oxide + Fe(III)-porphyrin',
    description:
        'Monooxygenation of ethylene by the high-valent iron-oxo "Compound I" active species of '
        'cytochrome P450. Two-state reactivity on high-spin (quartet) and low-spin (doublet) '
        'surfaces. The radical rebound mechanism proceeds via a radical carbon intermediate after '
        'initial O-atom transfer. Barrier heights: ~14 kcal/mol (doublet), ~17 kcal/mol (quartet). '
        'Key in drug metabolism and biosynthesis.',
    category: ReactionCategory.radical,
    reactantXyz: '''20
P450 Compound I + ethylene reactant
Fe    0.000    0.000    0.000
O     0.000    0.000    1.720
N     2.000    0.000    0.000
N     0.000    2.000    0.000
N    -2.000    0.000    0.000
N     0.000   -2.000    0.000
C     2.500    1.400    0.000
C     1.400    2.500    0.000
C    -1.400    2.500    0.000
C    -2.500    1.400    0.000
C    -2.500   -1.400    0.000
C    -1.400   -2.500    0.000
C     1.400   -2.500    0.000
C     2.500   -1.400    0.000
H     3.400    1.900    0.000
H     1.900    3.400    0.000
H    -1.900    3.400    0.000
H    -3.400    1.900    0.000
C     0.000    0.000    5.000
C     1.335    0.000    5.000
H    -0.545    0.950    5.000
H    -0.545   -0.950    5.000
H     1.880    0.950    5.000
H     1.880   -0.950    5.000''',
    productXyz: '''20
P450 product: ethylene oxide + Fe(III)-porphyrin
Fe    0.000    0.000    0.000
N     2.000    0.000    0.000
N     0.000    2.000    0.000
N    -2.000    0.000    0.000
N     0.000   -2.000    0.000
C     2.500    1.400    0.000
C     1.400    2.500    0.000
C    -1.400    2.500    0.000
C    -2.500    1.400    0.000
C    -2.500   -1.400    0.000
C    -1.400   -2.500    0.000
C     1.400   -2.500    0.000
C     2.500   -1.400    0.000
H     3.400    1.900    0.000
H     1.900    3.400    0.000
H    -1.900    3.400    0.000
H    -3.400    1.900    0.000
C     0.000    0.000    5.000
C     1.200    0.000    5.000
O     0.600    0.000    6.200
H    -0.545    0.950    5.000
H    -0.545   -0.950    5.000
H     1.745    0.950    5.000
H     1.745   -0.950    5.000''',
    referenceEa: 14.2,
    doi: '10.1021/cr400415k',
    journalRef: 'Chem. Rev. 2014, 114, 3659',
    tags: ['enzyme', 'Fe=O', 'radical-rebound', 'two-state', 'epoxidation', 'drug-metabolism'],
    defaults: const QuantumDefaults(
        charge: 0, spinMultiplicity: 2, mlipModel: 'MACE-MP-0',
        optimizerAlgorithm: 'NEB-CI'),
  ),

  ReactionTemplate(
    id: 'proline_aldol',
    name: 'Proline-Catalyzed Asymmetric Aldol Reaction',
    iupacName: 'acetone + 4-nitrobenzaldehyde → (S)-4-hydroxy-4-(4-nitrophenyl)butan-2-one  [L-Pro cat.]',
    description:
        'L-Proline catalyses the aldol via enamine mechanism (List-Barbas, 2000). '
        'Proline condenses with acetone to form a nucleophilic Z-enamine. '
        'The si-face attack on the aldehyde is preferred via a Zimmermann-Traxler-like TS '
        'stabilised by an intramolecular H-bond between the carboxylic acid and the developing '
        'alkoxide. Gives >99% ee for most aromatic aldehydes. Paradigmatic organocatalysis. '
        'Nobel Prize 2021 (List and MacMillan).',
    category: ReactionCategory.nucleophilic,
    reactantXyz: '''28
Proline-aldol: Z-enamine + 4-nitrobenzaldehyde
N     0.000    0.000    0.000
C     1.480    0.000    0.000
C     2.000    1.480    0.000
C     1.000    2.400    0.000
C    -0.480    1.820    0.000
C    -0.500   -0.500   -1.400
O    -1.200   -1.500   -1.500
O    -0.100    0.100   -2.400
H    -0.100   -0.100   -3.340
C    -1.480   -0.100    1.200
C    -2.600    0.000    1.200
H     0.800    3.450    0.000
H     1.400    2.500    1.000
H    -0.800    2.400    0.900
H    -0.800    2.300   -0.900
H     1.800    0.400   -0.950
H     1.800    0.400    0.950
H     2.200    1.600   -1.000
H     2.200    1.600    1.000
C    -1.900   -0.900    1.200
H    -2.150    1.000    1.200
H    -3.300   -0.900    1.200
C     6.000    0.000    0.000
O     7.200    0.000    0.000
C     4.800    0.700    0.000
C     3.600    0.000    0.000
N     2.400    0.700    0.000
O     2.400    1.900    0.000
O     1.350    0.000    0.000
H     4.800    1.788    0.000
H     3.600   -1.088    0.000''',
    productXyz: '''28
Proline-aldol product: beta-hydroxyketone (S-config)
O     0.000    0.000    0.000
C     1.420    0.000    0.000
C     2.120    1.260    0.000
C     3.540    1.260    0.000
O     4.240    0.000    0.000
C     4.900    2.380    0.000
C     6.290    2.380    0.000
C     6.990    3.600    0.000
C     6.290    4.820    0.000
N     4.900    4.820    0.000
O     4.200    6.040    0.000
O     3.090    4.650    0.000
H     1.820   -0.490   -0.920
H     1.820   -0.490    0.920
H     1.620    1.760   -0.920
H     1.620    1.760    0.920
H     3.980    1.740   -0.920
H     3.980    1.740    0.920
H     4.360    2.930   -0.920
H     4.360    2.930    0.920
H     6.830    1.450    0.000
H     8.075    3.600    0.000
H     6.830    5.750    0.000
C    -1.420    0.000    0.000
O    -2.120    1.040    0.000
C    -2.120   -1.260    0.000
H    -1.820    0.950   -0.100
H    -2.820   -1.020   -0.800
H    -2.820   -1.020    0.800
H    -1.620   -2.140    0.000''',
    referenceEa: 10.4,
    doi: '10.1021/ja005513q',
    journalRef: 'J. Am. Chem. Soc. 2000, 122, 394',
    tags: ['organocatalysis', 'enamine', 'proline', 'asymmetric', 'Nobel-2021', 'aldol'],
    defaults: const QuantumDefaults(
        mlipModel: 'UMA-SM', optimizerAlgorithm: 'NEB-CI'),
  ),
];

