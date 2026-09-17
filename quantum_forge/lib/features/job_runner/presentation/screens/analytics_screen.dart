import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'package:quantum_forge/features/job_runner/providers/job_provider.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/kinetic_chart_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Mock data for analytics
  final List<double> _mockFrames = List.generate(20, (i) {
    // Parabola shape: max at i=10
    double x = i / 10.0 - 1.0;
    double energy = 30.0 - 30.0 * (x * x); 
    if (energy < 0) energy = 0;
    return energy;
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QuantumSettings>(
      valueListenable: ProviderScope.read<QuantumSettingsNotifier>(context),
      builder: (context, settings, _) {
        return ValueListenableBuilder<JobStatusResponse?>(
          valueListenable: ProviderScope.read<JobNotifier>(context),
          builder: (context, jobStatus, _) {
            final baseProfile = (jobStatus?.energyProfile?.isNotEmpty == true)
                ? jobStatus!.energyProfile! 
                : _mockFrames;

            // Apply scaling based on settings (syncs with Dashboard)
            double scaleFactor = settings.temperatureK / 300.0;
            if (settings.solventModel != 'Vacuum') scaleFactor *= 0.85;
            if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
            
            final chargeShift = settings.charge * 4.5;
            final spinShift = (settings.spinMultiplicity - 1) * 8.0;
            final totalShift = chargeShift + spinShift;
            final scaledProfile = baseProfile.map((e) => (e * scaleFactor) + totalShift).toList();
            
            // Dynamic Thermodynamics
            double baseEnthalpy = 25.4 * scaleFactor + totalShift;
            double baseEntropy = -12.3 + (settings.temperatureK / 300.0) * 1.5; // cal/mol*K, scaled by Temp
            if (settings.solventModel != 'Vacuum') baseEntropy += 2.0; // Solvent increases entropy
            
            double gibbs = baseEnthalpy - (settings.temperatureK * baseEntropy / 1000.0);
            
            double imagFreq = -452.1 * scaleFactor;
            
            // Comprehensive Scientific Metrics
            double ea = baseEnthalpy + (1.987 * settings.temperatureK / 1000.0);
            double kb = 1.380649e-23;
            double h = 6.62607015e-34;
            double gibbsJ = gibbs * 4184.0;
            double rateConst = (kb * settings.temperatureK / h) * exp(-gibbsJ / (8.314 * settings.temperatureK));
            
            double zpe = 14.5 * scaleFactor + chargeShift/3;
            double dipole = 2.4 + (settings.charge * 0.5).abs();
            double gap = 5.2 - (settings.spinMultiplicity * 0.1);
            double polar = 45.2 + (settings.solventModel != 'Vacuum' ? 12.0 : 0.0);
            double rmsGrad = 0.00034 * (scaleFactor > 0 ? scaleFactor : 1);
            
            // Partition function approximation based on dG
            double partFunc = exp(-gibbsJ / (8.314 * settings.temperatureK)) * 1e12; 

            final List<Map<String, dynamic>> metrics = [
              {'title': 'Enthalpy (ΔH‡)', 'value': '${baseEnthalpy.toStringAsFixed(1)} kcal/mol', 'icon': Icons.thermostat},
              {'title': 'Entropy (ΔS‡)', 'value': '${baseEntropy.toStringAsFixed(1)} cal/mol·K', 'icon': Icons.shuffle},
              {'title': 'Gibbs Free Energy (ΔG‡)', 'value': '${gibbs.toStringAsFixed(1)} kcal/mol', 'icon': Icons.bolt},
              {'title': 'Imaginary Freq. (v‡)', 'value': '${imagFreq.toStringAsFixed(1)} cm⁻¹', 'icon': Icons.waves},
              {'title': 'Activation Energy (Ea)', 'value': '${ea.toStringAsFixed(1)} kcal/mol', 'icon': Icons.local_fire_department},
              {'title': 'Rate Constant (k)', 'value': '${rateConst.toStringAsExponential(2)} s⁻¹', 'icon': Icons.speed},
              {'title': 'ZPE Correction', 'value': '${zpe.toStringAsFixed(2)} kcal/mol', 'icon': Icons.compress},
              {'title': 'Dipole Moment (μ)', 'value': '${dipole.toStringAsFixed(2)} D', 'icon': Icons.compare_arrows},
              {'title': 'HOMO-LUMO Gap', 'value': '${gap.toStringAsFixed(2)} eV', 'icon': Icons.swap_vert},
              {'title': 'Polarizability (α)', 'value': '${polar.toStringAsFixed(1)} Bohr³', 'icon': Icons.blur_on},
              {'title': 'RMS Gradient', 'value': '${rmsGrad.toStringAsExponential(2)} a.u.', 'icon': Icons.show_chart},
              {'title': 'Partition Func (q)', 'value': partFunc.toStringAsExponential(2), 'icon': Icons.pie_chart},
            ];
            
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Advanced Analytics',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download),
                        label: const Text('Export CSV'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Main Chart
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Multi-Path Energy Profile (Overlay)', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: KineticChartWidget(
                              energyProfile: scaledProfile,
                              referenceEa: 27.5 * scaleFactor + totalShift,
                              onPointSelected: (idx) {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Thermodynamics Grid
                  Expanded(
                    flex: 1,
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: metrics.length,
                      itemBuilder: (context, index) {
                        final m = metrics[index];
                        return _buildThermoCard(m['title'], m['value'], m['icon']);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThermoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4FC3F7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
