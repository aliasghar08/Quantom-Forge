import 'dart:async' show unawaited;
import 'dart:convert';

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
import 'package:quantum_forge/core/services/session_state_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = FirebaseAuthService();
  final storageService = LocalStorageService();
  final reactionRepository = FirestoreReactionRepository();
  final filePickerService = FilePickerService();
  final sessionStateService = SessionStateService();

  final settingsNotifier = QuantumSettingsNotifier();
  final chemicalResolverService = ChemicalResolverService();

  final themeNotifier = ThemeNotifier();
  // Previously instantiated nowhere: the workspace-wide preferences existed but
  // were never registered, so nothing in the UI could read or write them.
  final appSettingsNotifier = AppSettingsNotifier();

  // The reaction notifier reads the configured ColabReaction (DMF/UMA) backend
  // lazily, so the setting can change at runtime without rebuilding the app.
  final reactionNotifier = ReactionNotifier(
    authService,
    storageService,
    reactionRepository,
    backendUrlProvider: () => appSettingsNotifier.settings.backendUrl,
    gnnBackendUrlProvider: () => appSettingsNotifier.settings.gnnBackendUrl,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<SessionStateService>.value(value: sessionStateService),
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

  // Firebase is brought up *after* `runApp`, never before it.
  //
  // This used to be `await Firebase.initializeApp(...)` ahead of `runApp`, and
  // that is a white screen waiting to happen: on web, FlutterFire loads its JS
  // SDK with a dynamic `import()` from gstatic, and if that fetch never resolves
  // — offline, a blocked CDN, a flaky network — the `await` never completes, so
  // `runApp` is never reached and the page stays blank. The only clue is a
  // console line like:
  //
  //   TypeError: Failed to fetch dynamically imported module:
  //   https://www.gstatic.com/firebasejs/<version>/firebase-app.js
  //
  // Cloud features are optional by design here — the app is fully usable without
  // an account and the library falls back to bundled templates — so nothing about
  // them should be able to delay or prevent the first frame. If Firebase never
  // arrives, the features that need it report their own failure when used.
  unawaited(initialiseCloudFeatures());
}

/// Brings Firebase up in the background, bounded, and without failing the app.
///
/// The timeout matters as much as the try/catch: a *hung* `initializeApp` is the
/// failure mode that produces a blank page, and it does not throw on its own.
/// The services reach Firebase through lazy getters
/// (`FirebaseAuthService`, `FirestoreReactionRepository`,
/// `FirestoreLibraryRepository`) precisely so that constructing them before this
/// completes is safe.
Future<void> initialiseCloudFeatures() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('Firebase unavailable, continuing without cloud features: $e');
    return;
  }

  // Seeding is a developer convenience: it must never block a cold start or take
  // the app down when Firestore is unreachable or the rules reject it.
  unawaited(_seedLibrary());
}

Future<void> _seedLibrary() async {
  // Seeding writes to Firestore, which unauthenticated guests cannot do. Skip
  // silently for them — the library falls back to the bundled templates, so the
  // app stays fully usable without an account and no permission error is raised.
  if (FirebaseAuth.instance.currentUser == null) return;
  
  List<ReactionTemplate> templatesToSeed = List.from(kReactionTemplates);
  
  try {
    final massiveJsonStr = await rootBundle.loadString('assets/massive_reactions.json');
    final massiveJson = jsonDecode(massiveJsonStr) as List<dynamic>;
    for (var item in massiveJson) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String;
      templatesToSeed.add(ReactionTemplate.fromJson(map, id));
    }
  } catch (e) {
    debugPrint('Could not load massive reactions asset: $e');
  }

  final written = await FirestoreLibraryRepository().seedLibrary(templatesToSeed);
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
