import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/presentation/screens/dashboard_screen.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/core/services/local_auth_service.dart';
import 'package:quantum_forge/core/services/local_storage_service.dart';
import 'package:quantum_forge/core/services/local_job_repository.dart';
import 'package:quantum_forge/core/services/job_repository.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/job_runner/providers/job_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authService = LocalAuthService();
  final storageService = LocalStorageService();
  final jobRepository = LocalJobRepository();
  final filePickerService = FilePickerService();
  
  final settingsNotifier = QuantumSettingsNotifier();
  final jobNotifier = JobNotifier(authService, storageService, jobRepository);
  
  runApp(ProviderScope(
    dependencies: {
      QuantumSettingsNotifier: settingsNotifier,
      JobNotifier: jobNotifier,
      FilePickerService: filePickerService,
      JobRepository: jobRepository,
    },
    child: const QuantumForgeApp(),
  ));
}

class QuantumForgeApp extends StatelessWidget {
  const QuantumForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum Forge',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Deep Blue
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
