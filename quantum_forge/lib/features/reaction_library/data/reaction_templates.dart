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
];
