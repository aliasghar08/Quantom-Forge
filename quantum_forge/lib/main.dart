import 'dart:math' as math;
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
import 'package:quantum_forge/core/services/chemical_resolver_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:quantum_forge/firebase_options.dart';
import 'package:quantum_forge/features/auth/presentation/screens/auth_screen.dart';
import 'package:quantum_forge/core/services/firebase_auth_service.dart';
import 'package:quantum_forge/core/services/firestore_job_repository.dart';
import 'package:quantum_forge/core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final authService = FirebaseAuthService();
  final storageService = LocalStorageService();
  final jobRepository = FirestoreJobRepository();
  final filePickerService = FilePickerService();
  
  final settingsNotifier = QuantumSettingsNotifier();
  final jobNotifier = JobNotifier(authService, storageService, jobRepository);
  final chemicalResolverService = ChemicalResolverService();
  
  runApp(ProviderScope(
    dependencies: {
      AuthService: authService,
      QuantumSettingsNotifier: settingsNotifier,
      JobNotifier: jobNotifier,
      FilePickerService: filePickerService,
      JobRepository: jobRepository,
      ChemicalResolverService: chemicalResolverService,
    },
    child: const QuantumForgeApp(),
  ));
}

class QuantumForgeApp extends StatefulWidget {
  const QuantumForgeApp({super.key});

  @override
  State<QuantumForgeApp> createState() => _QuantumForgeAppState();
}

class _QuantumForgeAppState extends State<QuantumForgeApp> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = ProviderScope.read<AuthService>(context);
    final isAuth = await authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantom Forge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Deep Blue
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            Positioned(
              bottom: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Text(
                    'Quantom Forge © Ali Asghar\naliasgharinnocent@yahoo.com',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      home: _isAuthenticated 
          ? const DashboardScreen() 
          : AuthScreen(onLoginSuccess: _checkAuth),
    );
  }
}
