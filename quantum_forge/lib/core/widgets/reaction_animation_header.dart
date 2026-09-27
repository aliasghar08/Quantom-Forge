// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationHeaderExt on _ReactionAnimationWidgetState {
  Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _phaseChip(),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _phaseProgress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation(_phaseColor),
                ),
              ),
            ),
            _fragmentChip(),
            _displayTypePicker(),
            _palettePicker(),
            _iconButton(
              (_showBondNumbers && _showBondEnergies)
                  ? Icons.analytics
                  : Icons.analytics_outlined,
              () {
                _claimKeyboard();
                final newState = !(_showBondNumbers && _showBondEnergies);
                setState(() => _showBondEnergies = newState);
                _setShowBondNumbers(newState);
              },
              tooltip: 'Toggle Analysis Overlay (Bond Numbers & Energies)',
              key: const Key('qf-analysis-overlay'),
            ),
            _iconButton(Icons.center_focus_strong, () {
              _claimKeyboard();
              _viewerKey.currentState?.resetView();
            }, tooltip: 'Reset view (fit molecule)'),
          ],
        ),
      );
    }

  Widget _phaseChip() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _phaseColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _phaseColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_phaseIcon, color: _phaseColor, size: 14),
            const SizedBox(width: 6),
            Text(
              _phaseName,
              style: TextStyle(
                color: _phaseColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

  Widget _fragmentChip() {
      return Tooltip(
        message:
            'Distinct molecules, from the bonds Avogadro\'s perception rule '
            'produces on the first and last frame',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            '$_reactantFragments R → $_productFragments P',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
      );
    }

  Widget _displayTypePicker() {
      return PopupMenuButton<AvogadroDisplayType>(
        key: const Key('qf-display-type'),
        tooltip: 'Display type (Avogadro)',
        color: const Color(0xFF1B1B22),
        onSelected: (type) {
          _claimKeyboard();
          _setDisplayType(type);
        },
        itemBuilder: (context) => [
          for (final type in AvogadroDisplayType.values)
            CheckedPopupMenuItem<AvogadroDisplayType>(
              value: type,
              checked: type == _displayType,
              child: Text(
                type.label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.category_outlined,
                size: 13,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                _displayType.label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white38),
            ],
          ),
        ),
      );
    }

  Widget _palettePicker() {
      return PopupMenuButton<NglPalette>(
        key: const Key('qf-palette'),
        tooltip: 'Element colours',
        color: const Color(0xFF1B1B22),
        onSelected: (palette) {
          _claimKeyboard();
          _setPalette(palette);
        },
        itemBuilder: (context) => [
          for (final palette in NglPalette.values)
            CheckedPopupMenuItem<NglPalette>(
              value: palette,
              checked: palette == _palette,
              child: Text(
                palette.label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.palette_outlined, size: 13, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                _palette.label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white38),
            ],
          ),
        ),
      );
    }

}
