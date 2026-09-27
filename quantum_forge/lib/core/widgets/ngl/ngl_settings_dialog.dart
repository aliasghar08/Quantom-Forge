import 'package:flutter/material.dart';
import 'package:quantum_forge/core/widgets/ngl/ngl_style.dart';

class NglSettingsDialog extends StatefulWidget {
  final NglStyle initialStyle;
  final ValueChanged<NglStyle> onChanged;

  const NglSettingsDialog({
    super.key,
    required this.initialStyle,
    required this.onChanged,
  });

  @override
  State<NglSettingsDialog> createState() => _NglSettingsDialogState();
}

class _NglSettingsDialogState extends State<NglSettingsDialog> {
  late NglStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.initialStyle;
  }

  void _updateStyle(NglStyle newStyle) {
    setState(() => _style = newStyle);
    widget.onChanged(newStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Advanced Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // ── Camera ──────────────────────────────────────────────────
            const Text('Camera Projection', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<NglCameraType>(
              segments: const [
                ButtonSegment(value: NglCameraType.orthographic, label: Text('Orthographic')),
                ButtonSegment(value: NglCameraType.perspective, label: Text('Perspective')),
              ],
              selected: {_style.cameraType},
              onSelectionChanged: (set) => _updateStyle(_style.copyWith(cameraType: set.first)),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) 
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? Colors.blue : Colors.white70;
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── Quality ──────────────────────────────────────────────────
            const Text('Render Quality', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<NglQuality>(
              segments: const [
                ButtonSegment(value: NglQuality.low, label: Text('Low (Fast)')),
                ButtonSegment(value: NglQuality.medium, label: Text('Medium')),
                ButtonSegment(value: NglQuality.high, label: Text('High')),
              ],
              selected: {_style.quality},
              onSelectionChanged: (set) => _updateStyle(_style.copyWith(quality: set.first)),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) 
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? Colors.blue : Colors.white70;
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── Sliders ──────────────────────────────────────────────────
            const Text('Atom Radius Scale', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Slider(
              value: _style.radiusScale,
              min: 0.1,
              max: 2.0,
              divisions: 19,
              label: _style.radiusScale.toStringAsFixed(1),
              onChanged: (v) => _updateStyle(_style.copyWith(radiusScale: v)),
            ),

            const Text('Light Intensity', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Slider(
              value: _style.lightIntensity,
              min: 0.0,
              max: 3.0,
              divisions: 30,
              label: _style.lightIntensity.toStringAsFixed(1),
              onChanged: (v) => _updateStyle(_style.copyWith(lightIntensity: v)),
            ),

            // ── Background ───────────────────────────────────────────────
            const Text('Background Color', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorBtn('#000000', Colors.black),
                _buildColorBtn('#FFFFFF', Colors.white),
                _buildColorBtn('#333333', const Color(0xFF333333)),
                _buildColorBtn('#1B1B22', const Color(0xFF1B1B22)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Toggles ──────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Auto-Spin', style: TextStyle(color: Colors.white)),
              value: _style.spin,
              onChanged: (v) => _updateStyle(_style.copyWith(spin: v)),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: Colors.blue.withValues(alpha: 0.5),
              activeThumbColor: Colors.blue,
            ),

            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBtn(String hex, Color displayColor) {
    final selected = _style.backgroundColor == hex;
    return GestureDetector(
      onTap: () => _updateStyle(_style.copyWith(backgroundColor: hex)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.blue : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 8,
              )
          ],
        ),
      ),
    );
  }
}
