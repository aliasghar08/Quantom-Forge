// ============================================================================
// Settings screen widget tests
// ----------------------------------------------------------------------------
// The previous "settings" surface (a theme dropdown inside an AlertDialog) read
// the theme notifier without listening, so it never rebuilt. These tests mount
// the real screen with real providers and assert that controls actually write
// through to the notifier *and* to storage.
//
// Note on surface size: a settings screen is mostly below the fold, and a
// ListView does not build off-screen children, so `find.text` would miss them.
// The default test surface here is deliberately tall; the small-surface case is
// covered by its own scroll-aware test at the end.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/features/settings/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness({
    required AppSettingsNotifier appSettings,
    required ThemeNotifier theme,
    QuantumSettingsNotifier? quantum,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsNotifier>.value(value: appSettings),
        ChangeNotifierProvider<ThemeNotifier>.value(value: theme),
        ChangeNotifierProvider<QuantumSettingsNotifier>.value(
          value: quantum ?? QuantumSettingsNotifier(),
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, notifier, _) => MaterialApp(
          theme: notifier.themeData,
          home: const SettingsScreen(),
        ),
      ),
    );
  }

  /// Gives the test a surface tall enough for the whole settings page.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders with every tab and the full theme catalogue',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(initialSettings: const AppSettings()),
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
    ));
    await tester.pumpAndSettle();

    // Header + all five tabs. Assert against Tab widgets specifically: the tab
    // *labels* also occur in the content below (a theme chip reads
    // "Spectroscopy"), so a bare text finder is ambiguous.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));
    for (final tab in const [
      'Appearance',
      'Editor',
      'Export',
      'Avogadro',
      'Compute',
    ]) {
      expect(find.widgetWithText(Tab, tab), findsOneWidget,
          reason: 'missing tab $tab');
    }

    // Every scientific preset is offered by name. Matched against the card
    // widget rather than a bare text finder, because a preset's *label* can
    // equal another preset's *family* ("Spectroscopy" is both). Note that
    // ThemeCard widgets nest (the grid is rebuilt per family), so the count is
    // not meaningful — only that each label appears somewhere in a card.
    final cards = find.byType(ThemeCard);
    expect(cards, findsWidgets);
    for (final theme in QuantumThemes.all) {
      expect(
        find.descendant(of: cards, matching: find.text(theme.label)),
        findsWidgets,
        reason: 'preset ${theme.label} missing from the catalogue',
      );
    }
    // ...and they are grouped into scientific families, each rendered with a
    // stable key (a family name can equal a preset label).
    for (final family in QuantumThemes.byFamily.keys) {
      expect(
        find.byKey(ValueKey('theme-family-$family')),
        findsOneWidget,
        reason: 'missing family label $family',
      );
    }
  });

  testWidgets('the compute tab edits the quantum settings notifier',
      (tester) async {
    useTallSurface(tester);
    final quantum = QuantumSettingsNotifier();
    addTearDown(quantum.dispose);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(initialSettings: const AppSettings()),
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
      quantum: quantum,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Compute'));
    await tester.pumpAndSettle();

    // The Appearance tab's catalogue must be gone, and the Compute tab's
    // content present — proving the TabBarView actually switched.
    expect(find.byType(ThemeCard), findsNothing,
        reason: 'the Appearance tab is still showing');
    expect(
      find.text('DEFAULT COMPUTATION PARAMETERS'),
      findsOneWidget,
      reason: 'section headings render upper-case',
    );
    // The switches mirror the Quantum Controls panel and must write through.
    final ircSwitch = find.widgetWithText(SwitchListTile, 'Run IRC');
    await tester.ensureVisible(ircSwitch);
    await tester.pumpAndSettle();
    expect(quantum.value.runIrc, isFalse);
    await tester.tap(ircSwitch);
    await tester.pumpAndSettle();
    expect(quantum.value.runIrc, isTrue);
    await quantum.flush();
  });

  testWidgets('selecting a theme switches the palette and persists it',
      (tester) async {
    useTallSurface(tester);
    final notifier = ThemeNotifier(initialTheme: AppTheme.darkMatter);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(initialSettings: const AppSettings()),
      theme: notifier,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Neon Synth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neon Synth'));
    await tester.pumpAndSettle();

    expect(notifier.currentTheme, AppTheme.neonSynth);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeNotifier.storageKey), 'neon_synth');
  });

  testWidgets('a toggle writes through to the notifier and to storage',
      (tester) async {
    useTallSurface(tester);
    final appSettings =
        AppSettingsNotifier(initialSettings: const AppSettings());
    await tester.pumpWidget(harness(
      appSettings: appSettings,
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
    ));
    await tester.pumpAndSettle();

    expect(appSettings.settings.isCompactMode, isFalse);

    // The first switch on the Appearance tab is "Compact mode".
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(appSettings.settings.isCompactMode, isTrue);
    await appSettings.flush();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('app_settings_compact_mode'), isTrue);
  });

  testWidgets('the export tab previews a real, regenerated document',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(
        initialSettings:
            const AppSettings(defaultExportFormat: ExportFormat.cjson),
      ),
      theme: ThemeNotifier(initialTheme: AppTheme.scientificLight),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Export'));
    await tester.pumpAndSettle();

    // The preview renders the actual serialised molecule, filename included.
    expect(find.text('water.cjson'), findsOneWidget);
    expect(find.textContaining('chemicalJson'), findsOneWidget);

    // Switching format regenerates the preview — proof it is produced by the
    // real writer rather than being static text.
    await tester.tap(find.byType(DropdownButton<ExportFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XYZ').last);
    await tester.pumpAndSettle();
    expect(find.text('water.xyz'), findsOneWidget);
    // The CJSON preview is gone: the format really changed.
    expect(find.text('water.cjson'), findsNothing);
  });

  testWidgets('the Avogadro tab reports the active bridge endpoint',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(
        initialSettings:
            const AppSettings(bridgeTarget: BridgeTarget.localhost),
      ),
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Avogadro'));
    await tester.pumpAndSettle();

    expect(
      find.text('Active endpoint: http://localhost:8080'),
      findsOneWidget,
    );
  });

  testWidgets('the editor tab exposes the bridge-relevant viewer settings',
      (tester) async {
    useTallSurface(tester);
    final appSettings =
        AppSettingsNotifier(initialSettings: const AppSettings());
    await tester.pumpWidget(harness(
      appSettings: appSettings,
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Editor'));
    await tester.pumpAndSettle();

    expect(find.text('Default element'), findsOneWidget);
    expect(find.text('Atom representation'), findsOneWidget);
    expect(find.text('Bond perception tolerance'), findsOneWidget);

    // Changing the default element must reach the notifier. The dropdown is
    // opened explicitly: its menu items do not exist until it is.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('N').last);
    await tester.pumpAndSettle();
    expect(appSettings.settings.defaultElement, 'N');
  });

  testWidgets('renders on a light theme without exceptions', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(initialSettings: const AppSettings()),
      theme: ThemeNotifier(initialTheme: AppTheme.journalMono),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Journal Mono'), findsOneWidget);
  });

  testWidgets('scrolls and stays laid out on a small screen', (tester) async {
    // The compact/laptop case: a single-column grid that must scroll rather
    // than overflow.
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(
      appSettings: AppSettingsNotifier(initialSettings: const AppSettings()),
      theme: ThemeNotifier(initialTheme: AppTheme.darkMatter),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dark Matter'), findsOneWidget);

    // Neon Synth is below the fold on this surface; scrolling must reach it.
    await tester.scrollUntilVisible(
      find.text('Neon Synth'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Neon Synth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
