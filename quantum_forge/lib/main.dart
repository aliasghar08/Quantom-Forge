import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/screens/dashboard_screen.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/services/local_storage_service.dart';
import 'package:quantum_forge/core/services/reaction_repository.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/state/reaction_provider.dart';
import 'package:quantum_forge/core/services/chemical_resolver_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quantum_forge/firebase_options.dart';
import 'package:quantum_forge/core/services/firebase_auth_service.dart';
import 'package:quantum_forge/core/services/firestore_reaction_repository.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/features/reaction_library/data/firestore_library_repository.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Seeding is a developer convenience: it must never block a cold start or
    // take the app down when Firestore is unreachable or the rules reject it.
    unawaited(_seedLibrary());
  } catch (e) {
    debugPrint('Firebase unavailable, continuing without cloud features: $e');
  }

  final authService = FirebaseAuthService();
  final storageService = LocalStorageService();
  final reactionRepository = FirestoreReactionRepository();
  final filePickerService = FilePickerService();

  final settingsNotifier = QuantumSettingsNotifier();
  final reactionNotifier =
      ReactionNotifier(authService, storageService, reactionRepository);
  final chemicalResolverService = ChemicalResolverService();

  final themeNotifier = ThemeNotifier();
  // Previously instantiated nowhere: the workspace-wide preferences existed but
  // were never registered, so nothing in the UI could read or write them.
  final appSettingsNotifier = AppSettingsNotifier();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider<QuantumSettingsNotifier>.value(value: settingsNotifier),
        ChangeNotifierProvider<ReactionNotifier>.value(value: reactionNotifier),
        Provider<FilePickerService>.value(value: filePickerService),
        Provider<ReactionRepository>.value(value: reactionRepository),
        Provider<ChemicalResolverService>.value(value: chemicalResolverService),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
        ChangeNotifierProvider<AppSettingsNotifier>.value(value: appSettingsNotifier),
      ],
      child: const QuantumForgeApp(),
    ),
  );
}

Future<void> _seedLibrary() async {
  // Seeding writes to Firestore, which unauthenticated guests cannot do. Skip
  // silently for them — the library falls back to the bundled templates, so the
  // app stays fully usable without an account and no permission error is raised.
  if (FirebaseAuth.instance.currentUser == null) return;
  final written = await FirestoreLibraryRepository().seedLibrary(kReactionTemplates);
  if (written > 0) {
    debugPrint('Reaction library seed complete ($written templates).');
  }
}
class QuantumForgeApp extends StatefulWidget {
  const QuantumForgeApp({super.key});

  @override
  State<QuantumForgeApp> createState() => _QuantumForgeAppState();
}

class _QuantumForgeAppState extends State<QuantumForgeApp> {
  @override
  Widget build(BuildContext context) {
    // Both notifiers participate in theming: the theme supplies the palette and
    // the app settings supply workspace density.
    return Consumer2<ThemeNotifier, AppSettingsNotifier>(
      builder: (context, themeNotifier, appSettings, _) {
        final palette = themeNotifier.palette;
        final settings = appSettings.settings;
        final themeData = settings.isCompactMode
            ? themeNotifier.themeData.copyWith(
                visualDensity: VisualDensity.compact,
                listTileTheme: themeNotifier.themeData.listTileTheme
                    .copyWith(minVerticalPadding: 4),
              )
            : themeNotifier.themeData;

        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true):
                _CycleThemeIntent(),
          },
          child: Actions(
            actions: {
              _CycleThemeIntent: CallbackAction<_CycleThemeIntent>(
                onInvoke: (_) {
                  themeNotifier.cycleTheme();
                  return null;
                },
              ),
            },
            child: MaterialApp(
              title: 'Quantum Forge',
              debugShowCheckedModeBanner: false,
              theme: themeData,
              builder: (context, child) {
                // Compact mode also tightens the text scale slightly; opt out
                // when the reader has asked for reduced motion *and* is on a
                // large display, where the extra density hurts more than helps.
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: settings.isCompactMode
                      ? media.copyWith(
                          textScaler: media.textScaler.clamp(
                            minScaleFactor: 0.85,
                            maxScaleFactor: 1.15,
                          ),
                        )
                      : media,
                  child: Stack(
                    children: [
                      ?child,
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 6, top: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  palette.scaffold.withValues(alpha: 0),
                                  palette.scaffold.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                            child: Text(
                              'Quantum Forge © Ali Asghar · aliasgharinnocent@yahoo.com',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              home: const DashboardScreen(),
            ),
          ),
        );
      },
    );
  }
}

class _CycleThemeIntent extends Intent {
  const _CycleThemeIntent();
}
