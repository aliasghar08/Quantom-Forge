import re

path = r'c:\Quantom Forge Repo\Quantom-Forge\quantum_forge\lib\features\reaction_runner\presentation\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's truncate everything from // Thermo properties grid onwards, and replace it properly.
idx = content.find('            // Thermo properties grid')
if idx == -1:
    print("Cannot find anchor")
    exit(1)

content = content[:idx] + '''            // Thermo properties grid
            ThermoPropertiesGrid(metrics: summary.thermoMetrics),
            const SizedBox(height: 16),

            // Molecular data
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              MolecularDataCards(trajectoryFrames: status.trajectoryFrames!),
              const SizedBox(height: 16),
            ],

            // Distinct reactants
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              DistinctMoleculesViewer(
                title: 'Distinct Reactants',
                atoms: XyzParser.parse(status.trajectoryFrames!.first),
              ),
              const SizedBox(height: 16),
            ],

            // Distinct products
            if (status.trajectoryFrames != null &&
                status.trajectoryFrames!.isNotEmpty) ...[
              DistinctMoleculesViewer(
                title: 'Distinct Products',
                atoms: XyzParser.parse(status.trajectoryFrames!.last),
              ),
              const SizedBox(height: 16),
            ],

            // Reaction animation card (extracted widget)
            ReactionAnimationCard(status: status),
            const SizedBox(height: 16),

            // Vibrational Analysis Card
            if (status.vibrationalModes != null && status.vibrationalModes!.isNotEmpty) ...[
              VibrationalAnalysisCard(status: status),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _DraggableControlPanel extends StatefulWidget {
  final Widget child;
  const _DraggableControlPanel({required this.child});

  @override
  State<_DraggableControlPanel> createState() => _DraggableControlPanelState();
}

class _DraggableControlPanelState extends State<_DraggableControlPanel> {
  Offset position = const Offset(800, 24);
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      position = Offset(size.width - 350 - 24, 24); // Place it on the right
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 350,
          child: GestureDetector(
            // We put the pan gesture detector on the whole block, but we only 
            // want it to drag when hitting empty space or headers if possible.
            // Using HitTestBehavior.deferToChild means it won't block taps on 
            // buttons, text fields, and dropdowns.
            behavior: HitTestBehavior.deferToChild,
            onPanUpdate: (details) {
              setState(() {
                position += details.delta;
                final size = MediaQuery.of(context).size;
                position = Offset(
                  position.dx.clamp(0.0, size.width - 100.0),
                  position.dy.clamp(0.0, size.height - 100.0),
                );
              });
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
