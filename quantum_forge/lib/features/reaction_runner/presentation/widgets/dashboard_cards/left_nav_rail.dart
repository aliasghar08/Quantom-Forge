// ============================================================================
// Professional Navigation Drawer
// ----------------------------------------------------------------------------
// Now theme-aware and settings-aware: colours come from the active quantum
// theme instead of hard-coded navy, the theme picker rebuilds live, and the
// gear icon opens the real settings screen rather than a single-dropdown dialog.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/auth/presentation/screens/auth_screen.dart';
import 'package:quantum_forge/features/settings/presentation/screens/settings_screen.dart';

enum NavDestination { library, newReaction, editor, history, methodValidation }

class ProfessionalDrawer extends StatelessWidget {
  final NavDestination current;
  final ValueChanged<NavDestination> onDestinationSelected;
  final bool controlsPanelOpen;
  final VoidCallback onToggleControls;

  const ProfessionalDrawer({
    super.key,
    required this.current,
    required this.onDestinationSelected,
    required this.controlsPanelOpen,
    required this.onToggleControls,
  });

  /// Auth state, or an empty stream when Firebase never came up.
  ///
  /// `FirebaseAuth.instance` throws `[core/no-app]` if
  /// `Firebase.initializeApp` has not completed — which happens when the Firebase
  /// JS SDK cannot be fetched (offline, blocked CDN) now that the app boots
  /// without waiting for it. A `StreamBuilder` whose stream getter throws takes
  /// down the whole rail, so the unavailable case is turned into "signed out"
  /// here: the rail offers the sign-in action, which is what a signed-out user
  /// sees anyway.
  Stream<User?> _authStateChanges() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (error) {
      debugPrint('Auth state unavailable, treating as signed out: $error');
      return const Stream<User?>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    final settings = context.watch<AppSettingsNotifier>().settings;
    final showTooltips = settings.showTooltips;
    final gap = settings.gap;

    return Drawer(
      backgroundColor: palette.drawer,
      width: 288,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.drawerGradient,
          ),
          border: Border(right: BorderSide(color: palette.border)),
        ),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ───────────────────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(20, gap(40), 20, gap(20)),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.accent, palette.accentAlt],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.science, color: palette.onAccent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QuantumForge',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          palette.family,
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: gap(16)),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: gap(8)),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _navItem(context, Icons.auto_stories_outlined, 'Library',
                NavDestination.library, showTooltips,
                'Browse the cloud reaction template library.'),
            _navItem(context, Icons.add_circle_outline, 'New Reaction',
                NavDestination.newReaction, showTooltips,
                'Set up reactants/products and dispatch an optimisation.'),
            _navItem(context, Icons.edit_document, 'Editor',
                NavDestination.editor, showTooltips,
                'Draw, import and export structures — including Avogadro 2 exchange.'),
            _navItem(context, Icons.history, 'History',
                NavDestination.history, showTooltips,
                'Previously dispatched reactions and their results.'),
            // Reachable entry point for the validation screen: without one the whole
            // screen is tree-shaken out of the release build.
            _navItem(context, Icons.verified_outlined, 'Method validation',
                NavDestination.methodValidation, showTooltips,
                'UMA barriers against known literature values — the table a reviewer asks for.'),

            const Spacer(),

            // ── Quick theme switcher ─────────────────────────────────────────
            Container(
              margin: EdgeInsets.symmetric(horizontal: gap(16)),
              padding: EdgeInsets.symmetric(horizontal: gap(12), vertical: gap(8)),
              decoration: BoxDecoration(
                color: palette.panel.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 16, color: palette.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.watch<ThemeNotifier>().currentTheme.label,
                      style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: showTooltips ? 'Next scientific theme' : null,
                    onPressed: context.read<ThemeNotifier>().cycleTheme,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    color: palette.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            SizedBox(height: gap(12)),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(gap(16)),
              decoration: BoxDecoration(
                color: palette.panel.withValues(alpha: 0.4),
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: onToggleControls,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: gap(16), vertical: gap(12)),
                      decoration: BoxDecoration(
                        color: controlsPanelOpen
                            ? palette.accent.withValues(alpha: 0.1)
                            : palette.panelAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: controlsPanelOpen
                              ? palette.accent.withValues(alpha: 0.3)
                              : palette.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            color: controlsPanelOpen
                                ? palette.accent
                                : palette.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            controlsPanelOpen
                                ? 'Hide Parameters'
                                : 'Show Parameters',
                            style: TextStyle(
                              color: controlsPanelOpen
                                  ? palette.textPrimary
                                  : palette.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap(14)),
                  StreamBuilder<User?>(
                    stream: _authStateChanges(),
                    builder: (context, snapshot) {
                      final user = snapshot.data;

                      // Signed out → offer to sync history, without blocking use.
                      if (user == null) {
                        return InkWell(
                          onTap: () => _openAuth(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: gap(14), vertical: gap(10)),
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.login,
                                    color: palette.accent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sign in to sync history',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Everything else works without an account',
                                        style: TextStyle(
                                          color: palette.textMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final name = user.displayName ?? 'Researcher';
                      final email = user.email ?? 'Signed in';

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: palette.panelAlt,
                            child: Icon(Icons.person,
                                color: palette.textSecondary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: showTooltips
                                ? 'Settings — themes, editor, export, Avogadro'
                                : null,
                            icon: Icon(Icons.settings,
                                color: palette.textSecondary, size: 20),
                            onPressed: () {
                              Navigator.pop(context); // close the drawer
                              Navigator.of(context).push(SettingsScreen.route());
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
      ),
    );
  }

  /// Opens sign-in as a pushed route — never as a gate. The app is fully usable
  /// without an account; signing in only enables synced history.
  void _openAuth(BuildContext context) {
    Navigator.pop(context); // close the drawer
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => AuthScreen(
          onLoginSuccess: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    NavDestination dest,
    bool showTooltips,
    String hint,
  ) {
    final palette = context.watch<ThemeNotifier>().palette;
    final settings = context.watch<AppSettingsNotifier>().settings;
    final active = current == dest;

    final tile = InkWell(
      onTap: () => onDestinationSelected(dest),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuint,
        margin: EdgeInsets.symmetric(
          horizontal: settings.gap(16),
          vertical: settings.gap(4),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: settings.gap(16),
          vertical: settings.gap(12),
        ),
        decoration: BoxDecoration(
          color: active ? palette.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? palette.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? palette.accent : palette.textMuted, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: active ? palette.textPrimary : palette.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );

    return showTooltips ? Tooltip(message: hint, child: tile) : tile;
  }
}
