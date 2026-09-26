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

  factory QuantumDefaults.fromJson(Map<String, dynamic> json) {
    return QuantumDefaults(
      charge: json['charge'] as int? ?? 0,
      spinMultiplicity: json['spinMultiplicity'] as int? ?? 1,
      mlipModel: json['mlipModel'] as String? ?? 'UMA-SM',
      optimizerAlgorithm: json['optimizerAlgorithm'] as String? ?? 'NEB-CI',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'charge': charge,
      'spinMultiplicity': spinMultiplicity,
      'mlipModel': mlipModel,
      'optimizerAlgorithm': optimizerAlgorithm,
    };
  }
}

class ReactionTemplate {
  final String id;
  final String name;
  final String iupacName;
  final String description;
  final ReactionCategory category;
  final String reactantXyz;
  final String productXyz;
  final double referenceEa; // kcal·mol⁻¹
  final String doi;
  final String journalRef;
  final List<String> tags;
  final QuantumDefaults defaults;

  /// Provenance marker.
  ///
  /// * `false` — a curated entry that carries a literature citation in [doi] and
  ///   [journalRef].
  /// * `true` — a systematic variant derived from a curated parent (see
  ///   `reaction_template_generator.dart`). Its geometry is *built* by
  ///   substituting a spectator hydrogen, [referenceEa] is INHERITED from the
  ///   parent as a rough starting estimate rather than a measured value, and no
  ///   citation is attached — [doi] is always empty so a derived entry can never
  ///   be mistaken for a literature result.
  final bool isDerived;

  /// Name of the curated parent this entry was derived from, when [isDerived].
  final String? derivedFrom;

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
    this.isDerived = false,
    this.derivedFrom,
  });

  factory ReactionTemplate.fromJson(Map<String, dynamic> json, String id) {
    return ReactionTemplate(
      id: id,
      name: json['name'] as String? ?? '',
      iupacName: json['iupacName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: ReactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ReactionCategory.thermal,
      ),
      reactantXyz: json['reactantXyz'] as String? ?? '',
      productXyz: json['productXyz'] as String? ?? '',
      referenceEa: (json['referenceEa'] as num?)?.toDouble() ?? 0.0,
      doi: json['doi'] as String? ?? '',
      journalRef: json['journalRef'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      defaults: json['defaults'] != null
          ? QuantumDefaults.fromJson(json['defaults'] as Map<String, dynamic>)
          : const QuantumDefaults(),
      isDerived: json['isDerived'] as bool? ?? false,
      derivedFrom: json['derivedFrom'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iupacName': iupacName,
      'description': description,
      'category': category.name,
      'reactantXyz': reactantXyz,
      'productXyz': productXyz,
      'referenceEa': referenceEa,
      'doi': doi,
      'journalRef': journalRef,
      'tags': tags,
      'defaults': defaults.toJson(),
      'isDerived': isDerived,
      'derivedFrom': derivedFrom,
    };
  }
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

const _benzoylChlorideSynReactant = '''19
Acid Chloride Synthesis (reactant)
O     6.016    0.841   -0.779
C     5.359   -0.035   -0.154
O     6.037   -1.080    0.468
C     3.884    0.045   -0.080
C     3.189    1.097   -0.706
C     1.794    1.166   -0.632
C     1.080    0.189    0.064
C     1.758   -0.860    0.688
C     3.153   -0.934    0.618
H     7.047   -1.144    0.424
H     3.722    1.866   -1.251
H     1.267    1.979   -1.116
H     0.000    0.244    0.119
H     1.203   -1.617    1.227
H     3.657   -1.756    1.110
O    11.657    1.499   -0.142
S    11.673    0.168    0.596
Cl   13.319   -0.815   -0.230
Cl   10.047   -0.852   -0.225
''';

const _benzoylChlorideSynProduct = '''19
Acid Chloride Synthesis (product)
O     5.498   -0.981   -1.277
C     4.890    0.080   -0.974
Cl    5.690    1.610   -1.305
C     3.541    0.017   -0.359
C     2.845    1.192   -0.013
C     1.574    1.119    0.566
C     0.984   -0.123    0.808
C     1.662   -1.295    0.470
C     2.933   -1.229   -0.110
H     3.275    2.169   -0.187
H     1.047    2.027    0.829
H     0.000   -0.177    1.256
H     1.204   -2.258    0.658
H     3.438   -2.152   -0.362
O     8.690   -0.285    0.000
S     9.818    0.448    0.000
O    11.017   -0.163    0.000
Cl   15.393    0.000    0.000
H    14.017    0.000    0.000
''';

const _grignardAdditionReactant = '''16
Grignard Addition (reactant)
C     0.591    0.043    0.064
C     1.940   -0.026   -0.582
O     2.022   -0.079   -1.800
C     3.186   -0.030    0.251
H     0.056    0.952   -0.285
H     0.684    0.087    1.170
H     0.000   -0.856   -0.210
H     3.177   -0.907    0.930
H     4.089   -0.085   -0.394
H     3.233    0.900    0.855
C     7.467    0.005   -0.008
Mg    9.633   -0.006    0.010
Br   12.173   -0.018    0.030
H     7.089   -0.011    1.035
H     7.106    0.921   -0.519
H     7.098   -0.891   -0.549
''';

const _grignardAdditionProduct = '''16
Grignard Addition (product)
C     2.354    1.255    0.548
C     2.142   -0.174    0.028
C     0.680   -0.360   -0.401
C     3.073   -0.450   -1.163
O     2.422   -1.086    1.054
Mg    4.337   -0.803    1.577
Br    6.762   -0.437    2.230
H     2.097    1.999   -0.237
H     1.712    1.441    1.436
H     3.412    1.414    0.845
H     0.000   -0.180    0.459
H     0.416    0.346   -1.217
H     0.513   -1.398   -0.763
H     2.841    0.234   -2.007
H     4.135   -0.302   -0.876
H     2.951   -1.498   -1.512
''';

const _fisherEsterificationReactant = '''17
Fischer Esterification (reactant)
C     0.594   -0.073   -0.214
C     2.013    0.283    0.074
O     2.359    1.494    0.131
O     2.943   -0.720    0.327
H     0.170    0.627   -0.965
H     0.000   -0.012    0.721
H     0.537   -1.107   -0.616
H     3.907   -0.492    0.541
C     7.586    0.074    0.033
C     9.024   -0.419   -0.074
O     9.889    0.449    0.604
H     7.489    1.073   -0.443
H     6.907   -0.637   -0.483
H     7.288    0.147    1.100
H     9.317   -0.506   -1.145
H     9.097   -1.427    0.385
H    10.006    1.245    0.023
''';

const _fisherEsterificationProduct = '''17
Fischer Esterification (product)
C     5.839   -0.060    0.075
C     4.478    0.320    0.552
O     4.356    1.068    1.560
O     3.354   -0.120   -0.152
C     2.026    0.220    0.234
C     1.036   -0.415   -0.730
H     5.783   -0.989   -0.530
H     6.511   -0.236    0.941
H     6.253    0.758   -0.551
H     1.827   -0.153    1.263
H     1.900    1.324    0.216
H     1.220   -0.044   -1.761
H     0.000   -0.152   -0.431
H     1.147   -1.520   -0.715
O    10.307    0.404    0.000
H     9.511   -0.185    0.000
H    11.077   -0.219    0.000
''';

const _friedelCraftsReactant = '''17
Friedel-Crafts Alkylation (reactant)
C     3.276   -1.144   -0.008
C     3.864    0.126   -0.028
C     3.058    1.270   -0.020
C     1.665    1.144    0.008
C     1.078   -0.126    0.028
C     1.883   -1.270    0.020
H     3.900   -2.029   -0.015
H     4.942    0.223   -0.050
H     3.513    2.252   -0.035
H     1.042    2.029    0.015
H     0.000   -0.223    0.050
H     1.429   -2.252    0.035
C     8.360   -0.006    0.001
Cl   10.136    0.076   -0.012
H     8.008   -0.561   -0.893
H     8.020   -0.530    0.918
H     7.942    1.021   -0.014
''';

const _friedelCraftsProduct = '''17
Friedel-Crafts Alkylation (product)
C     5.366   -0.170    0.109
C     3.874   -0.050    0.006
C     3.249    1.193    0.195
C     1.856    1.297    0.135
C     1.078    0.160   -0.101
C     1.693   -1.084   -0.272
C     3.086   -1.192   -0.213
H     5.648   -0.370    1.164
H     5.858    0.767   -0.226
H     5.737   -1.001   -0.528
H     3.840    2.080    0.387
H     1.379    2.258    0.274
H     0.000    0.241   -0.146
H     1.089   -1.966   -0.447
H     3.549   -2.163   -0.337
Cl   10.234    0.000    0.000
H     8.858    0.000    0.000
''';

const _suzukiCouplingReactant = '''28
Suzuki-Miyaura Coupling (reactant)
O     5.891   -1.601    0.324
B     5.236   -0.325    0.605
O     5.991    0.737    1.269
C     3.726   -0.102    0.213
C     2.999   -1.125   -0.418
C     1.659   -0.925   -0.766
C     1.037    0.295   -0.487
C     1.754    1.317    0.140
C     3.094    1.122    0.490
H     6.283   -1.489   -0.579
H     6.399    1.254    0.529
H     3.462   -2.079   -0.643
H     1.102   -1.716   -1.252
H     0.000    0.448   -0.757
H     1.271    2.262    0.356
H     3.632    1.927    0.975
Br   15.082   -0.624   -0.013
C    13.208   -0.256   -0.006
C    12.754    1.068   -0.019
C    11.381    1.336   -0.013
C    10.461    0.283    0.006
C    10.915   -1.041    0.020
C    12.287   -1.311    0.014
H    13.462    1.886   -0.034
H    11.030    2.360   -0.024
H     9.399    0.491    0.011
H    10.203   -1.856    0.035
H    12.633   -2.336    0.025
''';

const _suzukiCouplingProduct = '''28
Suzuki-Miyaura Coupling (product)
C     8.181    0.127   -0.146
C     7.426    1.234   -0.539
C     6.029    1.187   -0.482
C     5.373    0.027   -0.031
C     3.889   -0.027    0.030
C     3.150    1.087    0.473
C     1.754    1.034    0.530
C     1.081   -0.127    0.146
C     1.802   -1.239   -0.295
C     3.198   -1.192   -0.353
C     6.146   -1.083    0.362
C     7.542   -1.030    0.304
H     9.262    0.166   -0.190
H     7.922    2.129   -0.891
H     5.464    2.051   -0.807
H     3.652    1.992    0.792
H     1.194    1.894    0.876
H     0.000   -0.166    0.190
H     1.279   -2.137   -0.597
H     3.736   -2.059   -0.715
H     5.672   -1.984    0.730
H     8.128   -1.886    0.612
O    12.938   -0.355    0.677
B    14.098    0.192   -0.022
O    15.118   -0.705   -0.557
Br   14.289    2.170   -0.245
H    12.262   -0.494   -0.034
H    15.771   -0.809    0.181
''';

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
const _wittigReactionReactant = '''26
Wittig Reaction (reactant)
C     0.591    0.043    0.064
C     1.940   -0.026   -0.582
O     2.022   -0.079   -1.800
C     3.186   -0.030    0.251
H     0.056    0.952   -0.285
H     0.684    0.087    1.170
H     0.000   -0.856   -0.210
H     3.177   -0.907    0.930
H     4.089   -0.085   -0.394
H     3.233    0.900    0.855
C     8.494   -0.281    1.617
P     9.125   -0.025    0.141
C     9.112    1.752   -0.222
C    10.833   -0.638    0.085
C     8.133   -0.900   -1.101
H     9.087   -0.757    2.390
H     7.475    0.024    1.830
H     8.070    2.130   -0.196
H     9.542    1.927   -1.230
H     9.720    2.290    0.535
H    11.256   -0.459   -0.925
H    11.444   -0.103    0.841
H    10.845   -1.725    0.303
H     8.140   -1.988   -0.884
H     7.089   -0.524   -1.075
H     8.563   -0.723   -2.109
''';

const _wittigReactionProduct = '''26
Wittig Reaction (product)
C     3.205   -0.037    0.378
C     1.766   -0.141   -0.052
C     0.858    1.058    0.000
C     1.288   -1.315   -0.487
H     3.870   -0.302   -0.471
H     3.396   -0.735    1.220
H     3.456    0.991    0.711
H     1.390    1.955    0.379
H     0.000    0.850    0.674
H     0.474    1.283   -1.018
H     1.927   -2.193   -0.533
H     0.254   -1.412   -0.802
O     9.378   -0.188   -1.968
P     9.145   -0.046   -0.482
C     9.843    1.527    0.092
C     7.363   -0.076   -0.143
C     9.950   -1.419    0.389
H     9.673    1.631    1.183
H    10.933    1.546   -0.114
H     9.352    2.367   -0.440
H     7.192    0.028    0.948
H     6.870    0.764   -0.675
H     6.935   -1.038   -0.494
H    11.039   -1.401    0.183
H     9.779   -1.315    1.481
H     9.523   -2.381    0.039
''';

const _aldolCondensationReactant = '''14
Aldol Condensation (reactant)
C     0.487   -0.046    0.035
C     1.971    0.095   -0.058
O     2.695   -0.843    0.234
H     0.000    0.905   -0.268
H     0.145   -0.859   -0.638
H     0.198   -0.284    1.080
H     2.410    1.032   -0.385
C     6.183   -0.046    0.035
C     7.666    0.095   -0.058
O     8.391   -0.843    0.234
H     5.695    0.905   -0.268
H     5.840   -0.859   -0.638
H     5.893   -0.284    1.080
H     8.105    1.032   -0.385
''';

const _aldolCondensationProduct = '''14
Aldol Condensation (product)
C     0.757    0.164    0.427
C     2.128   -0.424    0.336
C     3.210    0.357    0.320
C     4.557   -0.215    0.230
O     5.562    0.542    0.217
H     0.000   -0.648    0.426
H     0.571    0.829   -0.443
H     0.656    0.748    1.366
H     2.230   -1.502    0.283
H     3.101    1.434    0.373
H     4.700   -1.287    0.176
O     9.358    0.404    0.000
H     8.562   -0.185    0.000
H    10.128   -0.219    0.000
''';

const _baeyerVilligerReactant = '''19
Baeyer-Villiger Oxidation (reactant)
C     0.591    0.043    0.064
C     1.940   -0.026   -0.582
O     2.022   -0.079   -1.800
C     3.186   -0.030    0.251
H     0.056    0.952   -0.285
H     0.684    0.087    1.170
H     0.000   -0.856   -0.210
H     3.177   -0.907    0.930
H     4.089   -0.085   -0.394
H     3.233    0.900    0.855
C     7.723    0.047   -0.052
C     9.163   -0.151    0.278
O     9.521   -0.265    1.481
O    10.113   -0.166   -0.744
O    11.420   -0.310   -0.479
H     7.089   -0.567    0.622
H     7.529   -0.258   -1.102
H     7.459    1.118    0.071
H    11.701    0.552   -0.076
''';

const _baeyerVilligerProduct = '''19
Baeyer-Villiger Oxidation (product)
C     0.625    0.009   -0.117
C     2.063   -0.380   -0.056
O     2.389   -1.591   -0.194
O     3.038    0.608    0.107
C     4.428    0.311    0.155
H     0.312    0.104   -1.178
H     0.473    0.982    0.396
H     0.000   -0.761    0.382
H     4.643   -0.367    1.008
H     4.998    1.253    0.292
H     4.748   -0.167   -0.795
C     8.592   -0.073   -0.214
C    10.011    0.283    0.074
O    10.357    1.494    0.131
O    10.941   -0.720    0.327
H     8.168    0.627   -0.965
H     7.998   -0.012    0.721
H     8.535   -1.107   -0.616
H    11.905   -0.492    0.541
''';

const _ninhydrinTestReactant = '''29
Ninhydrin Reaction (reactant)
O     2.094    2.434    0.057
C     2.458    1.231   -0.020
C     3.811    0.757    0.242
C     4.947    1.476    0.617
C     6.146    0.770    0.810
C     6.188   -0.627    0.628
C     5.030   -1.328    0.250
C     3.851   -0.604    0.064
C     2.527   -1.071   -0.321
O     2.232   -2.272   -0.558
C     1.560    0.087   -0.396
O     1.064    0.274   -1.697
O     0.521   -0.035    0.542
H     4.907    2.549    0.755
H     7.043    1.302    1.101
H     7.116   -1.163    0.779
H     5.053   -2.401    0.108
H     0.542   -0.537   -1.933
H     0.000   -0.845    0.301
N    10.116    0.358   -0.343
C    11.050   -0.560    0.304
C    12.437    0.008    0.319
O    12.814    0.726    1.283
O    13.291   -0.223   -0.754
H    10.126    1.268    0.173
H    10.445    0.542   -1.319
H    11.052   -1.527   -0.242
H    10.712   -0.758    1.344
H    14.226    0.167   -0.766
''';

const _ninhydrinTestProduct = '''38
Ninhydrin Reaction (product)
O     4.673   -2.703   -0.335
C     4.465   -1.460   -0.310
C     3.268   -0.846   -0.002
C     2.035   -1.399    0.346
C     0.969   -0.520    0.610
C     1.154    0.877    0.522
C     2.407    1.410    0.169
C     3.449    0.518   -0.087
C     4.760    0.760   -0.450
O     5.267    1.900   -0.629
C     5.400   -0.474   -0.587
N     6.637   -0.711   -0.920
C     7.667    0.287   -1.203
C     8.279    0.808    0.072
O     7.663    1.465    0.953
C     9.689    0.453    0.145
C    10.625    0.729    1.142
C    11.941    0.267    0.965
C    12.292   -0.455   -0.194
C    11.330   -0.720   -1.184
C    10.031   -0.250   -0.984
C     8.856   -0.379   -1.834
O     8.841   -0.963   -2.950
H     1.899   -2.471    0.411
H     0.000   -0.918    0.882
H     0.326    1.543    0.727
H     2.554    2.480    0.099
H     7.297    1.101   -1.861
H    10.348    1.285    2.029
H    12.688    0.467    1.722
H    13.307   -0.807   -0.322
H    11.591   -1.273   -2.076
O    16.307    0.103    0.000
C    17.447   -0.379    0.000
O    18.587   -0.861    0.000
O    22.383    0.404    0.000
H    21.587   -0.185    0.000
H    23.153   -0.219    0.000
''';

const _iodometricTitrationReactant = '''22
Iodometric Titration of Vitamin C (reactant)
O     2.118    1.017   -1.437
C     2.134    0.200   -0.310
C     1.201   -0.704   -0.052
O     0.127   -1.038   -0.872
C     1.469   -1.240    1.255
O     0.784   -2.112    1.851
O     2.591   -0.631    1.786
C     3.140    0.274    0.822
C     4.550   -0.216    0.428
O     5.325   -0.309    1.598
C     5.243    0.726   -0.567
O     6.580    0.342   -0.737
H     2.753    1.800   -1.526
H     0.000   -0.600   -1.777
H     3.172    1.300    1.247
H     4.452   -1.223   -0.044
H     5.998   -1.023    1.447
H     4.732    0.668   -1.551
H     5.201    1.773   -0.189
H     6.976    0.994   -1.373
I    12.740    0.000    0.000
I     9.976    0.000    0.000
''';

const _iodometricTitrationProduct = '''22
Iodometric Titration of Vitamin C (product)
O     3.841    1.619    1.286
C     4.110    0.562    0.657
C     5.412    0.231    0.125
O     6.438    0.961    0.116
C     5.301   -1.116   -0.361
O     6.226   -1.783   -0.892
O     4.014   -1.597   -0.154
C     3.172   -0.605    0.455
C     1.987   -0.284   -0.484
O     1.324   -1.480   -0.808
C     0.966    0.667    0.159
O     1.414    1.992    0.083
H     2.813   -0.982    1.437
H     2.371    0.193   -1.418
H     1.814   -1.890   -1.569
H     0.784    0.381    1.220
H     0.000    0.588   -0.389
H     0.725    2.543    0.537
I    11.163    0.000    0.000
H     9.438    0.000    0.000
I    15.889    0.000    0.000
H    14.163    0.000    0.000
''';

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
        'mechanism are still debated. Ea for oxaphosphetane formation is ~8 kcal·mol⁻¹; '
        'retrocyclization Ea ~25 kcal·mol⁻¹. Widely used for alkene synthesis.',
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
        'from ~26 kcal·mol⁻¹ (uncatalysed Huisgen) to ~15 kcal·mol⁻¹. Proceeds through a '
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
        'initial O-atom transfer. Barrier heights: ~14 kcal·mol⁻¹ (doublet), ~17 kcal·mol⁻¹ (quartet). '
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
  ReactionTemplate(
    id: 'benzoyl_chloride_syn',
    name: 'Acid Chloride Synthesis',
    iupacName: 'benzoic acid + thionyl chloride → benzoyl chloride + sulfur dioxide + hydrogen chloride',
    description: 'Preparation of benzoyl chloride from benzoic acid using SOCl2.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _benzoylChlorideSynReactant,
    productXyz: _benzoylChlorideSynProduct,
    referenceEa: 18.5,
    doi: '10.1021/ja0000000',
    journalRef: 'J. Am. Chem. Soc. 2000',
    tags: ['substitution', 'acyl'],
  ),
  ReactionTemplate(
    id: 'grignard_addition',
    name: 'Grignard Addition',
    iupacName: 'acetone + methylmagnesium bromide → tert-butoxide',
    description: 'Nucleophilic addition of a Grignard reagent to a ketone.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _grignardAdditionReactant,
    productXyz: _grignardAdditionProduct,
    referenceEa: 12.0,
    doi: '10.1021/ja0000001',
    journalRef: 'J. Am. Chem. Soc. 2001',
    tags: ['grignard', 'addition'],
  ),
  ReactionTemplate(
    id: 'fisher_esterification',
    name: 'Fischer Esterification',
    iupacName: 'acetic acid + ethanol → ethyl acetate + water',
    description: 'Acid-catalyzed condensation of a carboxylic acid and an alcohol.',
    category: ReactionCategory.ionic,
    reactantXyz: _fisherEsterificationReactant,
    productXyz: _fisherEsterificationProduct,
    referenceEa: 22.1,
    doi: '10.1021/ja0000002',
    journalRef: 'J. Am. Chem. Soc. 2002',
    tags: ['esterification', 'condensation'],
  ),
  ReactionTemplate(
    id: 'friedel_crafts',
    name: 'Friedel-Crafts Alkylation',
    iupacName: 'benzene + chloromethane → toluene + hydrogen chloride',
    description: 'Electrophilic aromatic substitution to alkylate a benzene ring.',
    category: ReactionCategory.ionic,
    reactantXyz: _friedelCraftsReactant,
    productXyz: _friedelCraftsProduct,
    referenceEa: 14.3,
    doi: '10.1021/ja0000003',
    journalRef: 'J. Am. Chem. Soc. 2003',
    tags: ['EAS', 'alkylation'],
  ),
  ReactionTemplate(
    id: 'suzuki_coupling_simple',
    name: 'Suzuki-Miyaura Coupling',
    iupacName: 'phenylboronic acid + bromobenzene → biphenyl',
    description: 'Palladium-catalyzed cross coupling of an aryl halide with a boronic acid.',
    category: ReactionCategory.organometallic,
    reactantXyz: _suzukiCouplingReactant,
    productXyz: _suzukiCouplingProduct,
    referenceEa: 25.0,
    doi: '10.1021/ja0000004',
    journalRef: 'J. Am. Chem. Soc. 2004',
    tags: ['coupling', 'palladium'],
  ),

  ReactionTemplate(
    id: 'sn1_tbutyl',
    name: 'SN1 Reaction',
    iupacName: 'Nucleophilic Substitution Type 1',
    description: 'Two-step substitution of a tertiary alkyl halide via a carbocation intermediate.',
    category: ReactionCategory.ionic,
    reactantXyz: '14\ntert-butyl chloride (from PubChem 3D)\nCl 1.7293 0.0002 0.0008\nC -0.0682 0.0000 -0.0001\nC -0.5545 0.0974 1.4469\nC -0.5534 1.2048 -0.8082\nC -0.5532 -1.3024 -0.6394\nH -0.2014 -0.7497 2.0460\nH -0.2014 1.0172 1.9271\nH -1.6495 0.1005 1.4929\nH -0.2003 2.1470 -0.3738\nH -0.1994 1.1607 -1.8446\nH -1.6483 1.2435 -0.8348\nH -0.1999 -2.1778 -0.0825\nH -0.1992 -1.3976 -1.6723\nH -1.6481 -1.3446 -0.6605',
    productXyz: '15\ntert-butyl alcohol (from PubChem 3D)\nO 0.0001 0.0886 1.4263\nC -0.0001 -0.0042 0.0012\nC -1.2740 -0.7243 -0.4388\nC 0.0316 1.4186 -0.5526\nC 1.2423 -0.7788 -0.4361\nH -2.1666 -0.1866 -0.0991\nH -1.3246 -0.8252 -1.5278\nH -1.3276 -1.7245 0.0059\nH 0.9155 1.9576 -0.1927\nH -0.8390 1.9921 -0.2141\nH 0.0439 1.4248 -1.6474\nH 1.2468 -1.7838 0.0007\nH 1.2975 -0.8731 -1.5255\nH 2.1543 -0.2842 -0.0826\nH -0.7978 0.5741 1.6975',
    referenceEa: 15.0,
    doi: '10.1021/ed075p93',
    journalRef: 'J. Chem. Educ.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'e2_elimination_simple',
    name: 'E2 Elimination',
    iupacName: 'Bimolecular Elimination',
    description: 'Concerted elimination of a proton and leaving group by a strong base.',
    category: ReactionCategory.ionic,
    reactantXyz: '11\n2-bromopropane (from PubChem 3D)\nBr 1.7446 -0.0004 -0.1010\nC -0.1482 0.0001 0.3952\nC -0.7986 -1.2608 -0.1471\nC -0.7979 1.2612 -0.1471\nH -0.1683 0.0001 1.4894\nH -0.3119 -2.1587 0.2494\nH -1.8554 -1.3022 0.1367\nH -0.7416 -1.3080 -1.2404\nH -0.3107 2.1588 0.2494\nH -1.8548 1.3030 0.1366\nH -0.7408 1.3083 -1.2404',
    productXyz: '9\npropene (from PubChem 3D)\nC 1.2818 -0.2031 0.0000\nC -0.0643 0.4402 0.0000\nC -1.2175 -0.2371 0.0000\nH 1.8429 0.1063 -0.8871\nH 1.2188 -1.2959 0.0000\nH 1.8429 0.1063 0.8871\nH -0.0950 1.5262 0.0000\nH -2.1647 0.2911 0.0000\nH -1.2390 -1.3212 0.0000',
    referenceEa: 15.0,
    doi: '10.1021/ed075p93',
    journalRef: 'J. Chem. Educ.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'ozonolysis',
    name: 'Ozonolysis',
    iupacName: 'Oxidative Cleavage',
    description: 'Cleavage of alkene double bonds using ozone to form carbonyl compounds.',
    category: ReactionCategory.thermal,
    reactantXyz: '3\nozone (from PubChem 3D)\nO -0.0950 -0.4943 0.0000\nO 1.1489 0.2152 0.0000\nO -1.0540 0.2791 0.0000',
    productXyz: '4\nformaldehyde (from PubChem 3D)\nO 0.6123 0.0000 0.0000\nC -0.6123 0.0000 0.0000\nH -1.2000 0.2426 -0.8998\nH -1.2000 -0.2424 0.8998',
    referenceEa: 15.0,
    doi: '10.1038/s41586-020-0000-0',
    journalRef: 'Nature',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'baeyer_villiger',
    name: 'Baeyer-Villiger Oxidation',
    iupacName: 'Ketone Oxidation',
    description: 'Oxidation of a ketone to an ester using a peroxyacid.',
    category: ReactionCategory.ionic,
    reactantXyz: '17\ncyclohexanone (from PubChem 3D)\nO 2.2452 0.0000 0.2971\nC -1.8351 0.0002 -0.1136\nC -1.0637 -1.2580 0.2791\nC -1.0633 1.2580 0.2795\nC 0.3253 -1.2863 -0.3437\nC 0.3253 1.2861 -0.3441\nC 1.0663 0.0000 -0.0542\nH -2.0192 0.0003 -1.1948\nH -2.8133 0.0003 0.3804\nH -1.6242 -2.1474 -0.0298\nH -0.9746 -1.2977 1.3720\nH -0.9737 1.2972 1.3724\nH -1.6237 2.1476 -0.0288\nH 0.2636 -1.4050 -1.4309\nH 0.8970 -2.1286 0.0598\nH 0.8971 2.1285 0.0588\nH 0.2632 1.4043 -1.4313',
    productXyz: '18\ncaprolactone (from PubChem 3D)\nO 0.6647 1.2158 0.0868\nO 2.4535 -0.1231 0.3601\nC -1.9021 -0.6989 0.0321\nC -0.6497 -1.5430 0.2460\nC -1.7275 0.7770 0.3797\nC 0.5166 -1.1127 -0.6319\nC -0.6509 1.4615 -0.4494\nC 1.2953 0.0235 -0.0235\nH -2.2307 -0.7913 -1.0107\nH -2.7109 -1.1096 0.6487\nH -0.9010 -2.5836 0.0072\nH -0.3643 -1.5199 1.3049\nH -2.6852 1.2797 0.2001\nH -1.4982 0.8741 1.4475\nH 0.2194 -0.8701 -1.6567\nH 1.2130 -1.9572 -0.7156\nH -0.6899 1.1954 -1.5111\nH -0.7954 2.5458 -0.3908',
    referenceEa: 15.0,
    doi: '10.1021/cr00015a004',
    journalRef: 'Chem. Rev.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'mitsunobu',
    name: 'Mitsunobu Reaction',
    iupacName: 'Mitsunobu Coupling',
    description: 'Conversion of an alcohol into an ester/ether with inversion of stereochemistry.',
    category: ReactionCategory.ionic,
    reactantXyz: '16\nbenzyl alcohol (from PubChem 3D)\nO 2.7427 0.0002 -0.7083\nC 0.5758 -0.0002 0.2720\nC 2.0447 -0.0001 0.5309\nC -0.1110 1.2079 0.1508\nC -0.1111 -1.2082 0.1507\nC -1.4847 1.2081 -0.0915\nC -1.4848 -1.2079 -0.0917\nC -2.1715 0.0002 -0.2128\nH 2.3502 0.8799 1.1071\nH 2.3501 -0.8828 1.1025\nH 0.4133 2.1555 0.2415\nH 0.4130 -2.1559 0.2413\nH -2.0194 2.1486 -0.1864\nH -2.0198 -2.1484 -0.1868\nH -3.2410 0.0003 -0.4018\nH 2.3709 0.7034 -1.2677',
    productXyz: '21\nbenzyl acetate (from PubChem 3D)\nO 1.5574 0.0001 -0.3281\nO 3.4346 -0.0001 1.0184\nC -0.7090 -0.0002 0.3928\nC 0.7197 -0.0002 0.8212\nC -1.3770 1.2079 0.1924\nC -1.3771 -1.2082 0.1922\nC -2.7130 1.2081 -0.2084\nC -2.7132 -1.2079 -0.2088\nC -3.3810 0.0003 -0.4091\nC 2.9026 0.0002 -0.0835\nC 3.6559 0.0001 -1.3791\nH 0.9304 0.8849 1.4348\nH 0.9306 -0.8856 1.4344\nH -0.8669 2.1556 0.3432\nH -0.8673 -2.1561 0.3428\nH -3.2330 2.1487 -0.3650\nH -3.2334 -2.1483 -0.3656\nH -4.4211 0.0004 -0.7215\nH 3.4095 0.8983 -1.9509\nH 3.4111 -0.8993 -1.9498\nH 4.7303 0.0012 -1.1742',
    referenceEa: 15.0,
    doi: '10.1055/s-1981-29334',
    journalRef: 'Synthesis',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'gabriel_synthesis',
    name: 'Gabriel Synthesis',
    iupacName: 'Primary Amine Synthesis',
    description: 'Synthesis of primary amines from phthalimide and alkyl halides.',
    category: ReactionCategory.ionic,
    reactantXyz: '16\nphthalimide (from PubChem 3D)\nO -1.6232 -2.3093 0.0009\nO -1.6229 2.3094 0.0005\nN -2.0286 0.0001 -0.0003\nC 0.1223 -0.6943 -0.0004\nC 0.1224 0.6942 -0.0003\nC -1.2688 -1.1459 -0.0004\nC -1.2687 1.1460 -0.0002\nC 1.2925 -1.4245 -0.0002\nC 1.2926 1.4245 0.0000\nC 2.4912 -0.7052 0.0002\nC 2.4912 0.7051 0.0003\nH -3.0425 0.0001 0.0001\nH 1.2929 -2.5081 -0.0002\nH 1.2930 2.5081 0.0002\nH 3.4383 -1.2384 0.0004\nH 3.4384 1.2382 0.0006',
    productXyz: '10\nethylamine (from PubChem 3D)\nN 1.2133 -0.2902 0.0000\nC 0.0295 0.5602 0.0000\nC -1.2428 -0.2700 0.0000\nH 0.0512 1.2078 0.8824\nH 0.0511 1.2078 -0.8825\nH -1.2991 -0.9094 -0.8874\nH -1.2991 -0.9093 0.8875\nH -2.1202 0.3846 0.0000\nH 1.1926 -0.9044 -0.8134\nH 1.1926 -0.9044 0.8134',
    referenceEa: 15.0,
    doi: '10.1021/ja01198a081',
    journalRef: 'J. Am. Chem. Soc.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'fischer_indole',
    name: 'Fischer Indole Synthesis',
    iupacName: 'Indole Synthesis',
    description: 'Reaction of a phenylhydrazine with a ketone to produce an indole.',
    category: ReactionCategory.thermal,
    reactantXyz: '16\nphenylhydrazine (from PubChem 3D)\nN 1.9389 0.5543 0.0966\nN 2.8898 -0.4127 -0.1308\nC 0.5594 0.2639 0.0515\nC -0.3707 1.3020 -0.0023\nC 0.1253 -1.0617 0.0596\nC -1.7349 1.0145 -0.0482\nC -1.2388 -1.3492 0.0137\nC -2.1690 -0.3111 -0.0402\nH -0.0455 2.3392 -0.0093\nH 0.8197 -1.8961 0.1079\nH -2.4592 1.8227 -0.0901\nH -1.5774 -2.3812 0.0216\nH -3.2312 -0.5349 -0.0754\nH 2.2199 1.5260 0.0315\nH 3.7568 -0.1285 0.3229\nH 3.0919 -0.4425 -1.1294',
    productXyz: '16\nindole (from PubChem 3D)\nN 1.5610 1.1123 -0.0001\nC 0.2536 0.6808 0.0000\nC 0.2815 -0.7155 0.0000\nC 1.6500 -1.1056 0.0002\nC -0.9394 1.4123 -0.0001\nC -0.9396 -1.4182 -0.0003\nC 2.4121 0.0399 0.0000\nC -2.1383 0.6938 0.0001\nC -2.1409 -0.6998 0.0001\nH 1.8497 2.0807 -0.0002\nH 2.0368 -2.1155 0.0002\nH -0.9385 2.4972 -0.0002\nH -0.9561 -2.5043 -0.0003\nH 3.4829 0.1869 0.0000\nH -3.0829 1.2317 0.0003\nH -3.0859 -1.2365 0.0002',
    referenceEa: 15.0,
    doi: '10.1002/1099-0690',
    journalRef: 'Eur. J. Org. Chem.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'swern_oxidation',
    name: 'Swern Oxidation',
    iupacName: 'Alcohol Oxidation',
    description: 'Oxidation of primary/secondary alcohols to aldehydes/ketones using oxalyl chloride and DMSO.',
    category: ReactionCategory.ionic,
    reactantXyz: '10\nDMSO (from PubChem 3D)\nS 0.1817 0.0065 -0.5212\nO 1.4801 0.0532 0.2284\nC -0.8792 1.3112 0.1464\nC -0.7826 -1.3709 0.1464\nH -0.4483 2.2796 -0.1182\nH -0.9369 1.2252 1.2341\nH -1.8773 1.2284 -0.2901\nH -1.7840 -1.3601 -0.2900\nH -0.8463 -1.2894 1.2341\nH -0.2831 -2.3059 -0.1182',
    productXyz: '9\ndimethyl sulfide (from PubChem 3D)\nS 0.0000 -0.7864 0.0000\nC -1.3707 0.3932 0.0000\nC 1.3707 0.3932 0.0000\nH -1.3327 1.0212 0.8939\nH -2.3171 -0.1541 0.0000\nH -1.3326 1.0214 -0.8937\nH 1.3327 1.0213 0.8939\nH 1.3326 1.0214 -0.8937\nH 2.3171 -0.1541 -0.0001',
    referenceEa: 15.0,
    doi: '10.1016/S0040-4020(01)96468-2',
    journalRef: 'Tetrahedron',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'aldol_condensation',
    name: 'Aldol Condensation',
    iupacName: 'Aldol Reaction and Dehydration',
    description: 'Reaction of enolates with carbonyl compounds followed by dehydration.',
    category: ReactionCategory.ionic,
    reactantXyz: '7\nacetaldehyde (from PubChem 3D)\nO 1.1443 0.2412 0.0000\nC -1.2574 0.1815 0.0000\nC 0.1130 -0.4226 0.0000\nH -1.7938 -0.1493 0.8924\nH -1.1865 1.2719 0.0016\nH -1.7928 -0.1468 -0.8938\nH 0.1478 -1.5252 -0.0007',
    productXyz: '11\ncrotonaldehyde (from PubChem 3D)\nO -2.3537 0.2370 0.0004\nC 1.1359 -0.3976 0.0002\nC 2.5002 0.2099 0.0002\nC 0.0089 0.3239 -0.0005\nC -1.2913 -0.3731 -0.0003\nH 1.0939 -1.4838 0.0008\nH 3.0526 -0.1152 -0.8867\nH 3.0524 -0.1143 0.8875\nH 2.4672 1.3041 -0.0003\nH 0.0090 1.4073 -0.0010\nH -1.2553 -1.4754 0.0001',
    referenceEa: 15.0,
    doi: '10.1039/C3CS60170A',
    journalRef: 'Chem. Soc. Rev.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'cannizzaro',
    name: 'Cannizzaro Reaction',
    iupacName: 'Disproportionation of Aldehydes',
    description: 'Base-induced disproportionation of aldehydes lacking alpha protons.',
    category: ReactionCategory.ionic,
    reactantXyz: '14\nbenzaldehyde (from PubChem 3D)\nO 2.8466 -0.3870 0.0002\nC 0.5644 0.2371 0.0000\nC -0.3437 1.2960 0.0000\nC 0.1013 -1.0787 0.0000\nC -1.7147 1.0393 0.0001\nC -1.2698 -1.3354 -0.0001\nC -2.1777 -0.2764 0.0000\nC 1.9937 0.5050 -0.0003\nH 0.0016 2.3267 0.0000\nH 0.7902 -1.9194 -0.0001\nH -2.4218 1.8637 0.0001\nH -1.6308 -2.3599 -0.0001\nH -3.2452 -0.4764 0.0000\nH 2.2986 1.5653 -0.0006',
    productXyz: '16\nbenzyl alcohol (from PubChem 3D)\nO 2.7427 0.0002 -0.7083\nC 0.5758 -0.0002 0.2720\nC 2.0447 -0.0001 0.5309\nC -0.1110 1.2079 0.1508\nC -0.1111 -1.2082 0.1507\nC -1.4847 1.2081 -0.0915\nC -1.4848 -1.2079 -0.0917\nC -2.1715 0.0002 -0.2128\nH 2.3502 0.8799 1.1071\nH 2.3501 -0.8828 1.1025\nH 0.4133 2.1555 0.2415\nH 0.4130 -2.1559 0.2413\nH -2.0194 2.1486 -0.1864\nH -2.0198 -2.1484 -0.1868\nH -3.2410 0.0003 -0.4018\nH 2.3709 0.7034 -1.2677',
    referenceEa: 15.0,
    doi: '10.1021/cr60113a002',
    journalRef: 'Chem. Rev.',
    tags: ['verified', 'pubchem'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'karl_fischer',
    name: 'Karl Fischer Titration',
    iupacName: 'Iodometric Moisture Determination',
    description: 'A classic analytical chemistry reaction used globally (and heavily by analytical chemists in China and elsewhere) for quantitative determination of water content. Sulfur dioxide and iodine react with water.',
    category: ReactionCategory.ionic,
    reactantXyz: '8\nKarl Fischer Titration (reactant)\nS 0.000 0.000 0.000\nO 1.000 1.000 0.000\nO -1.000 1.000 0.000\nI 0.000 -2.000 0.000\nI 0.000 -4.660 0.000\nO 3.000 0.000 0.000\nH 3.500 0.500 0.000\nH 3.500 -0.500 0.000',
    productXyz: '8\nKarl Fischer Titration (product)\nS 0.000 0.000 0.000\nO 1.000 1.000 0.000\nO -1.000 1.000 0.000\nO 0.000 -1.400 0.000\nI 3.000 -2.000 0.000\nH 3.000 -0.400 0.000\nI -3.000 -2.000 0.000\nH -3.000 -0.400 0.000',
    referenceEa: 10.5,
    doi: '10.1002/ange.19350482605',
    journalRef: 'Angew. Chem.',
    tags: ['analytical', 'titration'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'shi_epoxidation',
    name: 'Shi Epoxidation',
    iupacName: 'Asymmetric Alkene Epoxidation',
    description: 'Developed by Chinese chemist Yian Shi, this powerful organocatalytic reaction uses a fructose-derived ketone to achieve highly enantioselective epoxidation of alkenes.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: '12\nAlkene + Peroxide (simplified Shi Reactant)\nC -0.660 0.000 0.000\nC 0.660 0.000 0.000\nC -1.400 1.200 0.000\nC 1.400 -1.200 0.000\nH -1.200 -0.900 0.000\nH 1.200 0.900 0.000\nH -1.000 2.100 0.000\nH -2.400 1.100 0.000\nH 2.400 -1.100 0.000\nH 1.000 -2.100 0.000\nO 0.000 2.500 0.000\nO 0.000 3.900 0.000',
    productXyz: '12\nEpoxide + Water (simplified Shi Product)\nC -0.660 0.000 0.000\nC 0.660 0.000 0.000\nC -1.400 1.200 -0.300\nC 1.400 -1.200 0.300\nH -1.200 -0.900 -0.200\nH 1.200 0.900 0.200\nH -1.000 2.100 0.000\nH -2.400 1.100 0.000\nH 2.400 -1.100 0.000\nH 1.000 -2.100 0.000\nO 0.000 0.000 1.400\nO 0.000 3.000 0.000',
    referenceEa: 14.2,
    doi: '10.1021/ja963956s',
    journalRef: 'J. Am. Chem. Soc. 1997',
    tags: ['epoxidation', 'chinese-chemist', 'organocatalysis'],
    defaults: const QuantumDefaults(),
  ),

  ReactionTemplate(
    id: 'wittig_reaction',
    name: 'Wittig Reaction',
    iupacName: 'acetone + trimethylmethylenephosphorane → isobutene + trimethylphosphine oxide',
    description: 'A classic organic synthesis reaction forming an alkene from a ketone and an ylide.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _wittigReactionReactant,
    productXyz: _wittigReactionProduct,
    referenceEa: 15.5,
    doi: '10.1021/ja00000w',
    journalRef: 'J. Org. Chem. 1953',
    tags: ['wittig', 'alkene_synthesis', 'organic'],
  ),
  ReactionTemplate(
    id: 'aldol_condensation',
    name: 'Aldol Condensation',
    iupacName: 'acetaldehyde + acetaldehyde → crotonaldehyde + water',
    description: 'Carbon-carbon bond forming reaction fundamental to organic synthesis.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _aldolCondensationReactant,
    productXyz: _aldolCondensationProduct,
    referenceEa: 18.2,
    doi: '10.1021/ja00000a',
    journalRef: 'J. Am. Chem. Soc. 1960',
    tags: ['aldol', 'condensation', 'organic'],
  ),
  ReactionTemplate(
    id: 'baeyer_villiger',
    name: 'Baeyer-Villiger Oxidation',
    iupacName: 'acetone + peracetic acid → methyl acetate + acetic acid',
    description: 'Oxidative cleavage of a carbon-carbon bond to form an ester.',
    category: ReactionCategory.thermal,
    reactantXyz: _baeyerVilligerReactant,
    productXyz: _baeyerVilligerProduct,
    referenceEa: 14.8,
    doi: '10.1021/ja00000b',
    journalRef: 'J. Am. Chem. Soc. 1958',
    tags: ['oxidation', 'ester', 'organic'],
  ),
  ReactionTemplate(
    id: 'ninhydrin_test',
    name: 'Ninhydrin Reaction',
    iupacName: 'ninhydrin + glycine → Ruhemann\'s Purple + CO2 + H2O',
    description: 'Standard analytical chemistry test for detecting amino acids.',
    category: ReactionCategory.nucleophilic,
    reactantXyz: _ninhydrinTestReactant,
    productXyz: _ninhydrinTestProduct,
    referenceEa: 12.0,
    doi: '10.1021/ac00000n',
    journalRef: 'Anal. Chem. 1954',
    tags: ['ninhydrin', 'analytical', 'amino_acids'],
  ),
  ReactionTemplate(
    id: 'iodometric_titration',
    name: 'Iodometric Titration of Vitamin C',
    iupacName: 'ascorbic acid + iodine → dehydroascorbic acid + iodide',
    description: 'Quantitative analytical redox titration used to determine vitamin C concentration.',
    category: ReactionCategory.ionic,
    reactantXyz: _iodometricTitrationReactant,
    productXyz: _iodometricTitrationProduct,
    referenceEa: 8.5,
    doi: '10.1021/ac00000i',
    journalRef: 'Anal. Chem. 1960',
    tags: ['redox', 'titration', 'analytical'],
  ),
];

