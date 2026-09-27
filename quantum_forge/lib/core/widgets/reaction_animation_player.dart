// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationPlayerExt on _ReactionAnimationWidgetState {
  Widget _buildPlayerControls() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1 — `<`  Frame: [N/M]  `>`
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepButton('<', 'Step back one frame (←)', () {
                  _claimKeyboard();
                  _animate(-1);
                }),
                const SizedBox(width: 10),
                Tooltip(
                  message:
                      'Keyboard: Space plays and pauses, ← / → step one '
                      'frame, Shift + ← / → step ten, ↑ jumps to Start and ↓ to '
                      'End. Click a control first to give the player focus.',
                  child: const Text(
                    'Frame:',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 6),
                _SpinBox(
                  key: const Key('qf-frame-spinbox'),
                  label: 'Frame',
                  value: _frame + 1,
                  min: 1,
                  max: _frameCount,
                  suffix: '/$_frameCount',
                  onChanged: (value) {
                    _claimKeyboard();
                    _showFrame(value - 1);
                  },
                ),
                const SizedBox(width: 10),
                _stepButton('>', 'Step forward one frame (→)', () {
                  _claimKeyboard();
                  _animate(1);
                }),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2 — the frame slider.
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF4FC3F7),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.white,
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: _frame.toDouble(),
                      min: 0,
                      max: (_frameCount - 1).toDouble(),
                      divisions: _frameCount > 1 ? _frameCount - 1 : null,
                      label: '${_frame + 1}',
                      onChanged: (value) => _showFrame(value.round()),
                    ),
                  ),
                ),
              ],
            ),

            // Row 3 — Start / End, which bound playback.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Start:',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 6),
                _SpinBox(
                  key: const Key('qf-start-spinbox'),
                  label: 'Start frame',
                  value: _startFrame + 1,
                  min: 1,
                  max: _frameCount,
                  onChanged: _setStartFrame,
                ),
                const SizedBox(width: 18),
                const Text(
                  'End:',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 6),
                _SpinBox(
                  key: const Key('qf-end-spinbox'),
                  label: 'End frame',
                  value: _endFrame + 1,
                  min: 1,
                  max: _frameCount,
                  onChanged: _setEndFrame,
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 4 — Dynamic bonding?
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    key: const Key('qf-dynamic-bonding'),
                    value: _dynamicBonding,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: const Color(0xFF4FC3F7),
                    onChanged: (value) {
                      _claimKeyboard();
                      _setDynamicBonding(value ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Dynamic bonding?',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message:
                      'Re-perceive every bond from the current frame\'s '
                      'coordinates, exactly as Avogadro does: covalent radii plus '
                      'a 0.45 Å tolerance, hydrogen–hydrogen and the noble gases '
                      'excluded. Off, the first frame\'s bonds are reused.',
                  child: Icon(
                    Icons.info_outline,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 5 — Frame rate: [N] FPS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Frame rate:',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 6),
                _SpinBox(
                  key: const Key('qf-framerate-spinbox'),
                  label: 'Frame rate in frames per second',
                  value: _frameRate,
                  min: ReactionAnimationWidget.minFrameRate,
                  max: ReactionAnimationWidget.maxFrameRate,
                  onChanged: _setFrameRate,
                ),
                const SizedBox(width: 6),
                Text(
                  'FPS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 6 — loop mode extension + Play / Pause.
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.loop, size: 14, color: Colors.white38),
                for (final mode in AnimationLoopMode.values) _loopChip(mode),
                const SizedBox(width: 6),
                FilledButton.icon(
                  key: const Key('qf-play-button'),
                  onPressed: () {
                    _claimKeyboard();
                    _togglePlay();
                  },
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 17,
                  ),
                  label: Text(_playing ? 'Pause' : 'Play'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF4FC3F7,
                    ).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFF4FC3F7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

  Widget _stepButton(String glyph, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              glyph,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    }

}
