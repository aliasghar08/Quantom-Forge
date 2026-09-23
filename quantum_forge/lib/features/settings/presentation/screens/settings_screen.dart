// ============================================================================
// Settings Screen
// ----------------------------------------------------------------------------
// Before this screen existed the only "settings" in Quantum Forge was a theme
// dropdown inside the navigation drawer; the whole AppSettings model was dead
// code. This screen is now the single place to configure appearance, the
// editor/viewer, export defaults and the Avogadro bridge — and every control
// writes through to `AppStorage` immediately.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/services/web_services.dart';
import 'package:quantum_forge/core/settings/app_settings_provider.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/core/utils/avogadro_interchange.dart';
import 'package:quantum_forge/core/utils/element_data.dart';
import 'package:quantum_forge/core/utils/molecular.dart';
import 'package:quantum_forge/state/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
        settings: const RouteSettings(name: '/settings'),
      );

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: palette.textPrimary)),
        backgroundColor: palette.scaffold,
        iconTheme: IconThemeData(color: palette.textSecondary),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmReset(context),
            icon: Icon(Icons.restart_alt, size: 18, color: palette.textSecondary),
            label: Text('Reset', style: TextStyle(color: palette.textSecondary)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: palette.accent,
              labelColor: palette.accent,
              unselectedLabelColor: palette.textMuted,
              tabs: const [
                Tab(text: 'Appearance', icon: Icon(Icons.palette_outlined, size: 18)),
                Tab(text: 'Editor', icon: Icon(Icons.draw_outlined, size: 18)),
                Tab(text: 'Export', icon: Icon(Icons.ios_share, size: 18)),
                Tab(text: 'Avogadro', icon: Icon(Icons.hub_outlined, size: 18)),
                Tab(text: 'Compute', icon: Icon(Icons.memory, size: 18)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AppearanceTab(),
          _EditorTab(),
          _ExportTab(),
          _AvogadroTab(),
          _ComputeTab(),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final settings = context.read<AppSettingsNotifier>();
    final theme = context.read<ThemeNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all settings?'),
        content: const Text(
          'Appearance, editor, export and bridge preferences return to their '
          'factory defaults. Computation parameters are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      settings.resetToDefaults();
      await theme.reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings restored to defaults.')),
        );
      }
    }
  }
}

// ── Shared building blocks ───────────────────────────────────────────────────

/// Section heading used across the settings tabs.
///
/// Public (rather than `_SectionHeader`) so widget tests can anchor on it —
/// several family names also occur as labels elsewhere on screen.
class ThemeFamilyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const ThemeFamilyHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: palette.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    // A plain Container/DecoratedBox here hides ListTile ink splashes, because
    // ListTile paints its background on the nearest Material ancestor. Using
    // Material for the card surface keeps ripples visible (Flutter asserts on
    // the DecoratedBox variant).
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: palette.accent,
      secondary: icon == null ? null : Icon(icon, color: palette.textMuted, size: 20),
      title: Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: palette.textMuted, fontSize: 12, height: 1.35),
            ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: palette.textMuted, size: 20),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: palette.textPrimary, fontSize: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: TextStyle(
                          color: palette.textMuted, fontSize: 12, height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<T>(
            value: value,
            onChanged: onChanged,
            dropdownColor: palette.panelAlt,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox.shrink(),
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            items: items,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(color: palette.textPrimary, fontSize: 14)),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: palette.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Appearance ───────────────────────────────────────────────────────────────

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final palette = themeNotifier.palette;
    final settings = context.watch<AppSettingsNotifier>().settings;
    final families = QuantumThemes.byFamily;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        const ThemeFamilyHeader(
          title: 'Scientific themes',
          icon: Icons.science_outlined,
          subtitle:
              'Each preset encodes a convention from spectroscopy or scientific '
              'publishing — including the palette used by the energy, Arrhenius '
              'and IR plots.',
        ),
        for (final entry in families.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(
              entry.key,
              // Stable key: the family name can also appear as a preset label
              // ("Spectroscopy"), so tests need an unambiguous handle.
              key: ValueKey('theme-family-${entry.key}'),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 980
                  ? 3
                  : constraints.maxWidth > 640
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.1 : 1.85,
                children: [
                  for (final t in entry.value)
                    ThemeCard(
                      theme: AppTheme.fromId(t.id),
                      selected: themeNotifier.currentTheme.id == t.id,
                      onSelect: () => themeNotifier.setTheme(AppTheme.fromId(t.id)),
                    ),
                ],
              );
            },
          ),
        ],
        const ThemeFamilyHeader(
          title: 'Workspace density',
          icon: Icons.density_medium_outlined,
        ),
        _SettingsCard(
          children: [
            _SwitchRow(
              icon: Icons.compress,
              title: 'Compact mode',
              subtitle:
                  'Tightens paddings across the dashboard and rail — useful on '
                  'laptops when the 3-pane workspace feels cramped.',
              value: settings.isCompactMode,
              onChanged: context.read<AppSettingsNotifier>().setCompactMode,
            ),
            _SwitchRow(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduce motion',
              subtitle:
                  'Shortens the reaction animation and disables decorative '
                  'fades. Recommended for motion sensitivity and screen shares.',
              value: settings.reduceMotion,
              onChanged: context.read<AppSettingsNotifier>().setReduceMotion,
            ),
            _SwitchRow(
              icon: Icons.info_outline,
              title: 'Show tooltips',
              subtitle: 'Hover hints on icon-only controls in the rail and editor.',
              value: settings.showTooltips,
              onChanged: context.read<AppSettingsNotifier>().setShowTooltips,
            ),
          ],
        ),
        _SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.tune, color: palette.textMuted, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick cycle',
                            style: TextStyle(
                                color: palette.textPrimary, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(
                          'Active preset: ${themeNotifier.currentTheme.label} '
                          '(${themeNotifier.currentTheme.family})',
                          style: TextStyle(
                              color: palette.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: themeNotifier.cycleTheme,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next theme'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single selectable theme preset card.
///
/// Public so widget tests can scope text lookups to a card.
class ThemeCard extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onSelect;

  const ThemeCard({
    super.key,
    required this.theme,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme.preset;
    final outline = context.watch<ThemeNotifier>().palette;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? outline.accent : outline.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: outline.accent.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: t.backgroundGradient),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(theme.icon, size: 15, color: t.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 17, color: outline.accent),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in t.plotPalette.take(6))
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: t.border),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t.description,
              style: TextStyle(color: t.textSecondary, fontSize: 11.5, height: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                _Chip(label: t.family, color: t.accent),
                const SizedBox(width: 6),
                _Chip(
                  label: t.isLight ? 'Light' : 'Dark',
                  color: t.bondColor,
                ),
                const SizedBox(width: 6),
                _Chip(label: t.atomStyle.name, color: t.accentAlt),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Editor / viewer ──────────────────────────────────────────────────────────

class _EditorTab extends StatelessWidget {
  const _EditorTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsNotifier>().settings;
    final notifier = context.read<AppSettingsNotifier>();
    final elements = ElementData.colors.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        const ThemeFamilyHeader(
          title: 'Builder defaults',
          icon: Icons.draw_outlined,
          subtitle: 'Applied whenever the coordinate editor is opened.',
        ),
        _SettingsCard(
          children: [
            _ChoiceRow<String>(
              icon: Icons.science,
              title: 'Default element',
              subtitle: 'Pre-selected in the element picker of the 3D builder.',
              value: elements.contains(settings.defaultElement)
                  ? settings.defaultElement
                  : elements.first,
              items: [
                for (final symbol in elements)
                  DropdownMenuItem(value: symbol, child: Text(symbol)),
              ],
              onChanged: (v) {
                if (v != null) notifier.setDefaultElement(v);
              },
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.auto_fix_high,
              title: 'Auto-optimise while drawing',
              subtitle:
                  'Runs the built-in force-field relaxation as atoms are placed. '
                  'Turn off for exact manual coordinates.',
              value: settings.defaultAutoOptimize,
              onChanged: notifier.setDefaultAutoOptimize,
            ),
          ],
        ),
        const ThemeFamilyHeader(
          title: 'Rendering',
          icon: Icons.blur_on,
          subtitle: 'Affects the 3D builder, the trajectory viewer and the '
              'template previews.',
        ),
        _SettingsCard(
          children: [
            _ChoiceRow<AtomScale>(
              icon: Icons.circle_outlined,
              title: 'Atom representation',
              value: settings.atomScale,
              items: [
                for (final s in AtomScale.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) {
                if (v != null) notifier.setAtomScale(v);
              },
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.timeline,
              title: 'Draw bonds',
              subtitle: 'Connectivity is perceived from covalent radii.',
              value: settings.showBonds,
              onChanged: notifier.setShowBonds,
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.filter_alt_outlined,
              title: 'Show hydrogens',
              subtitle:
                  'Hide hydrogens to declutter large ligands. Exports always keep '
                  'every atom.',
              value: settings.showHydrogens,
              onChanged: notifier.setShowHydrogens,
            ),
            const Divider(height: 1),
            _SliderRow(
              title: 'Bond perception tolerance',
              valueLabel: '${settings.bondTolerance.toStringAsFixed(2)} × Σ r(cov)',
              value: settings.bondTolerance,
              min: 1.05,
              max: 1.9,
              divisions: 17,
              onChanged: notifier.setBondTolerance,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Lower it to stop spurious bonds in loosely packed clusters; '
                'raise it for stretched bonds near a transition state.',
                style: TextStyle(
                  color: context.watch<ThemeNotifier>().palette.textMuted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const ThemeFamilyHeader(
          title: 'Persistence',
          icon: Icons.save_outlined,
        ),
        _SettingsCard(
          children: [
            _SliderRow(
              title: 'Auto-save interval',
              valueLabel: '${settings.autoSaveIntervalMinutes} min',
              value: settings.autoSaveIntervalMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (v) => notifier.setAutoSaveIntervalMinutes(v.round()),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Export ───────────────────────────────────────────────────────────────────

class _ExportTab extends StatelessWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsNotifier>().settings;
    final notifier = context.read<AppSettingsNotifier>();
    final palette = context.watch<ThemeNotifier>().palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        const ThemeFamilyHeader(
          title: 'Structure format',
          icon: Icons.ios_share,
          subtitle: 'Used by “Export structure” in the editor and by the '
              'Avogadro hand-off.',
        ),
        _SettingsCard(
          children: [
            _ChoiceRow<ExportFormat>(
              icon: Icons.description_outlined,
              title: 'Default format',
              subtitle: settings.defaultExportFormat.isAvogadroNative
                  ? 'CJSON is Avogadro 2’s native format — bonds and metadata '
                      'survive the round trip.'
                  : settings.defaultExportFormat.label,
              value: settings.defaultExportFormat,
              items: [
                for (final f in ExportFormat.values)
                  DropdownMenuItem(value: f, child: Text(f.shortLabel)),
              ],
              onChanged: (v) {
                if (v != null) notifier.setDefaultExportFormat(v);
              },
            ),
            const Divider(height: 1),
            _SliderRow(
              title: 'Coordinate precision',
              valueLabel: '${settings.exportPrecision} decimals',
              value: settings.exportPrecision.toDouble(),
              min: 3,
              max: 8,
              divisions: 5,
              onChanged: (v) => notifier.setExportPrecision(v.round()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                '5 decimals matches the 1e-5 Å noise floor of most MLIP '
                'optimisers; more digits only inflate the file.',
                style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.35),
              ),
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.title,
              title: 'Write title line',
              subtitle:
                  'XYZ/SDF comment line carrying the structure name. Avogadro '
                  'shows it in the title bar and the frame list.',
              value: settings.includeTitleLine,
              onChanged: notifier.setIncludeTitleLine,
            ),
          ],
        ),
        const ThemeFamilyHeader(
          title: 'Live preview',
          icon: Icons.preview_outlined,
          subtitle:
              'Exactly what a water molecule looks like with the settings above.',
        ),
        _SettingsCard(children: [_ExportPreview(settings: settings)]),
      ],
    );
  }
}

/// Renders a real export of a small molecule with the current preferences, so
/// "precision"/"title line" stop being abstract numbers.
class _ExportPreview extends StatelessWidget {
  final AppSettings settings;
  const _ExportPreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    final atoms = [
      atomFor('O', 0.00000, 0.00000, 0.11779),
      atomFor('H', 0.00000, 0.75545, -0.47116),
      atomFor('H', 0.00000, -0.75545, -0.47116),
    ];
    final structure = AvogadroInterchange.structure(atoms, title: 'Water (H₂O)');
    final preview = switch (settings.defaultExportFormat) {
      ExportFormat.cjson => AvogadroInterchange.toCjson(structure),
      ExportFormat.cml => AvogadroInterchange.toCml(structure),
      ExportFormat.sdf => AvogadroInterchange.toSdf(structure),
      ExportFormat.xyz => AvogadroInterchange.toXyz(
          structure,
          precision: settings.exportPrecision,
          includeTitleLine: settings.includeTitleLine,
        ),
    };
    final lines = preview.split('\n');
    final shown = lines.take(14).join('\n');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.viewport,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  'water.${settings.defaultExportFormat.extension}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  '${lines.length} lines',
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              shown + (lines.length > 14 ? '\n…' : ''),
              style: TextStyle(
                color: palette.success,
                fontSize: 11,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avogadro ─────────────────────────────────────────────────────────────────

class _AvogadroTab extends StatefulWidget {
  const _AvogadroTab();

  @override
  State<_AvogadroTab> createState() => _AvogadroTabState();
}

class _AvogadroTabState extends State<_AvogadroTab> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: context.read<AppSettingsNotifier>().settings.customBaseUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsNotifier>().settings;
    final notifier = context.read<AppSettingsNotifier>();
    final palette = context.watch<ThemeNotifier>().palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        const ThemeFamilyHeader(
          title: 'Structure bridge',
          icon: Icons.hub_outlined,
          subtitle:
              'Avogadro 2 has no URL-open hook, so Quantum Forge transports '
              'structures two ways: a deep link (push from Avogadro) and file '
              'export (pull into Avogadro).',
        ),
        _SettingsCard(
          children: [
            _SwitchRow(
              icon: Icons.link,
              title: 'Enable deep-link import',
              subtitle:
                  'Accept ?import_struct= payloads on startup. Disable if you '
                  'open Quantum Forge with untrusted query strings.',
              value: settings.avogadroBridgeEnabled,
              onChanged: notifier.setAvogadroBridgeEnabled,
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.auto_mode,
              title: 'Auto-load on arrival',
              subtitle:
                  'Push an incoming structure straight into the editor. When off '
                  'you get a banner with a “Load” button instead.',
              value: settings.autoImportDeepLink,
              onChanged: notifier.setAutoImportDeepLink,
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.cleaning_services_outlined,
              title: 'Clean the URL after import',
              subtitle:
                  'Removes the payload from the address bar so a refresh does not '
                  're-import (and re-run) the same structure.',
              value: settings.cleanUrlAfterImport,
              onChanged: notifier.setCleanUrlAfterImport,
            ),
          ],
        ),
        const ThemeFamilyHeader(
          title: 'Bridge endpoint',
          icon: Icons.dns_outlined,
          subtitle:
              'Which Quantum Forge instance the Avogadro plugin should open. '
              'Use localhost while developing the web app.',
        ),
        _SettingsCard(
          children: [
            _ChoiceRow<BridgeTarget>(
              icon: Icons.public,
              title: 'Target',
              value: settings.bridgeTarget,
              items: [
                for (final t in BridgeTarget.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) {
                if (v != null) notifier.setBridgeTarget(v);
              },
            ),
            if (settings.bridgeTarget == BridgeTarget.custom) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _urlController,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Custom base URL',
                    hintText: 'https://my-host/quantum-forge',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  onChanged: notifier.setCustomBaseUrl,
                ),
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: palette.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Active endpoint: ${settings.bridgeBaseUrl}',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => WebServices.openUrl(settings.bridgeBaseUrl),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Test'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const ThemeFamilyHeader(
          title: 'Install the Avogadro 2 plugin',
          icon: Icons.extension_outlined,
        ),
        _SettingsCard(
          children: [
            const _CodeBlock(
              title: 'Windows',
              code: r'%LOCALAPPDATA%\OpenChemistry\Avogadro\plugins\python\quantom-forge',
            ),
            const Divider(height: 1),
            const _CodeBlock(
              title: 'macOS',
              code:
                  '~/Library/Application Support/OpenChemistry/Avogadro/plugins/python/quantom-forge',
            ),
            const Divider(height: 1),
            const _CodeBlock(
              title: 'Linux',
              code:
                  '~/.local/share/OpenChemistry/Avogadro/plugins/python/quantom-forge',
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Copy the repository’s `avogadro_plugin/` folder there — it '
                'already contains the Avogadro metadata (pyproject.toml + '
                'avogadro.toml) plus the export command. Restart Avogadro, then '
                'use Extensions ▸ Quantum Forge ▸ Export to Quantum Forge Web.',
                style: TextStyle(color: palette.textMuted, fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String title;
  final String code;
  const _CodeBlock({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeNotifier>().palette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(title,
                style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: SelectableText(
              code,
              style: TextStyle(
                color: palette.accentAlt,
                fontSize: 11.5,
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compute ──────────────────────────────────────────────────────────────────

class _ComputeTab extends StatelessWidget {
  const _ComputeTab();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<QuantumSettingsNotifier>();
    final s = notifier.value;
    final palette = context.watch<ThemeNotifier>().palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        const ThemeFamilyHeader(
          title: 'DMF/UMA compute backend',
          icon: Icons.hub,
          subtitle:
              'Optional. Point this at the ColabReaction FastAPI service to run '
              'the real Direct MaxFlux + UMA reaction-path optimisation. Leave '
              'empty to use the built-in illustrative simulation.',
        ),
        const _SettingsCard(children: [_BackendUrlField()]),
        const ThemeFamilyHeader(
          title: 'Default computation parameters',
          icon: Icons.memory,
          subtitle:
              'These mirror the Quantum Controls panel for quick edits. Every '
              'change is persisted and picked up by the next dispatch.',
        ),
        _SettingsCard(
          children: [
            _SliderRow(
              title: 'Temperature',
              valueLabel: '${s.temperatureK.toStringAsFixed(2)} K',
              value: s.temperatureK.clamp(100, 1000),
              min: 100,
              max: 1000,
              divisions: 180,
              onChanged: (v) => notifier.update((c) => c.copyWith(temperatureK: v)),
            ),
            const Divider(height: 1),
            _SliderRow(
              title: 'Max optimisation steps',
              valueLabel: '${s.maxSteps}',
              value: s.maxSteps.toDouble().clamp(50, 2000),
              min: 50,
              max: 2000,
              divisions: 39,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(maxSteps: v.round())),
            ),
            const Divider(height: 1),
            _SliderRow(
              title: 'NEB images',
              valueLabel: '${s.nebImages}',
              value: s.nebImages.toDouble().clamp(3, 40),
              min: 3,
              max: 40,
              divisions: 37,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(nebImages: v.round())),
            ),
            const Divider(height: 1),
            _SliderRow(
              title: 'Force convergence (max |F|)',
              valueLabel: s.maxForceNorm.toStringAsFixed(3),
              value: s.maxForceNorm.clamp(0.005, 0.5),
              min: 0.005,
              max: 0.5,
              divisions: 99,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(maxForceNorm: v)),
            ),
          ],
        ),
        _SettingsCard(
          children: [
            _SwitchRow(
              icon: Icons.thermostat,
              title: 'ZPE correction',
              value: s.zpeCorrection,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(zpeCorrection: v)),
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.analytics_outlined,
              title: 'Thermochemistry',
              value: s.computeThermochemistry,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(computeThermochemistry: v)),
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.graphic_eq,
              title: 'Frequency analysis',
              value: s.frequencyAnalysis,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(frequencyAnalysis: v)),
            ),
            const Divider(height: 1),
            _SwitchRow(
              icon: Icons.route_outlined,
              title: 'Run IRC',
              value: s.runIrc,
              onChanged: (v) => notifier.update((c) => c.copyWith(runIrc: v)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            'Credentials (Hugging Face token) stay in the Quantum Controls '
            'panel so they are never rendered on a wide settings surface.',
            style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Editor for the ColabReaction (DMF/UMA) backend base URL.
class _BackendUrlField extends StatefulWidget {
  const _BackendUrlField();

  @override
  State<_BackendUrlField> createState() => _BackendUrlFieldState();
}

class _BackendUrlFieldState extends State<_BackendUrlField> {
  late final TextEditingController _controller;

  /// True while a "Test connection" probe is in flight.
  bool _testing = false;

  /// Result of the most recent probe, or null before one has run.
  BackendHealth? _health;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AppSettingsNotifier>().settings.backendUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Probes the configured backend and reports the result inline.
  Future<void> _testConnection() async {
    final url = context.read<AppSettingsNotifier>().settings.backendUrl;
    setState(() {
      _testing = true;
      _health = null;
    });
    final result = await const BackendComputeService().healthCheck(url);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _health = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    final settings = context.watch<AppSettingsNotifier>().settings;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Backend base URL',
              hintText: 'https://aliasgharinnocent-uma-backend.hf.space',
              prefixIcon: Icon(Icons.dns_outlined, size: 18),
            ),
            onChanged: context.read<AppSettingsNotifier>().setBackendUrl,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                settings.hasComputeBackend
                    ? Icons.check_circle_outline
                    : Icons.science_outlined,
                size: 15,
                color: settings.hasComputeBackend ? palette.success : palette.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settings.hasComputeBackend
                      ? 'Real DMF/UMA backend active — reactions are optimised '
                          'server-side.'
                      : 'No backend configured — using the built-in illustrative '
                          'simulation.',
                  style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 16),
                label: Text(_testing ? 'Testing…' : 'Test connection'),
              ),
              if (_health != null) ...[
                const SizedBox(width: 12),
                Icon(
                  _health!.ok ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: _health!.ok ? palette.success : palette.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _health!.detail,
                    style: TextStyle(
                      color: _health!.ok ? palette.success : palette.danger,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
