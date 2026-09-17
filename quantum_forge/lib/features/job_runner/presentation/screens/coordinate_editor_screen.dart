import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/molecular_viewer_widget.dart';

class CoordinateEditorScreen extends StatefulWidget {
  const CoordinateEditorScreen({super.key});

  @override
  State<CoordinateEditorScreen> createState() => _CoordinateEditorScreenState();
}

class _CoordinateEditorScreenState extends State<CoordinateEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  String _xyzData = '';
  
  @override
  void initState() {
    super.initState();
    // Default example
    final initial = '''3
Water molecule
O  0.00000  0.00000  0.11779
H  0.00000  0.75545 -0.47116
H  0.00000 -0.75545 -0.47116''';
    _controller.text = initial;
    _xyzData = initial;
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _updateViewer() {
    setState(() {
      _xyzData = _controller.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Coordinate Editor',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI TS Guesser (LST) generating saddle point...')),
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    setState(() {
                      _controller.text = '''3
TS Guess (LST interpolation)
O  0.00000  0.00000  0.20000
H  0.00000  0.90000 -0.50000
H  0.00000 -0.90000 -0.50000''';
                      _xyzData = _controller.text;
                    });
                  });
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI TS Guesser'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _updateViewer,
                icon: const Icon(Icons.refresh),
                label: const Text('Update 3D Preview'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Text Editor
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        color: Colors.greenAccent,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Paste .xyz coordinates here...',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // 3D Viewer
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MolecularViewerWidget(currentXyzData: _xyzData),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
