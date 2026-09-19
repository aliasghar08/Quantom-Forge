import re

path = r'c:\Quantom Forge Repo\Quantom-Forge\quantum_forge\lib\features\reaction_runner\presentation\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# We need to replace the desktop layout part.
# It starts at `if (isDesktop && _viewModel.controlsPanelOpen) {`
# and ends at the end of the file.

idx = content.find('            if (isDesktop && _viewModel.controlsPanelOpen) {')
if idx == -1:
    print("Cannot find anchor")
    exit(1)

content = content[:idx] + '''            if (isDesktop && _viewModel.controlsPanelOpen) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(child: mainContent),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: QuantumControlsPanel(activeTemplate: _viewModel.activeTemplate),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: mainContent,
            );
          }
        );
      },
    );
  }

  // ── Setup card ─────────────────────────────────────────────────────────────
  Widget _buildSetupCard() {
    final isTemplate = _viewModel.activeTemplate != null;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTemplate ? Icons.check_circle : Icons.science_outlined,
                  color: isTemplate
                      ? Colors.greenAccent.shade200
                      : Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  isTemplate
                      ? 'Loaded Template: ${_viewModel.activeTemplate!.name}'
                      : 'System Coordinates',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMoleculeList(MoleculeRole.reactant),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Icon(Icons.arrow_forward, color: Colors.white38),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMoleculeList(MoleculeRole.product),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _viewModel.catalysts.isNotEmpty
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.white10,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: _viewModel.catalysts.isNotEmpty
                            ? Colors.amber.shade300
                            : Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Catalysts (Optional)',
                        style: TextStyle(
                          color: _viewModel.catalysts.isNotEmpty
                              ? Colors.amber.shade200
                              : Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMoleculeList(MoleculeRole.catalyst),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoleculeList(MoleculeRole role) {
    List<MoleculeEntry> list;
    switch (role) {
      case MoleculeRole.reactant:
        list = _viewModel.reactants;
        break;
      case MoleculeRole.product:
        list = _viewModel.products;
        break;
      case MoleculeRole.catalyst:
        list = _viewModel.catalysts;
        break;
    }

    final String label = switch (role) {
      MoleculeRole.reactant => 'Reactant',
      MoleculeRole.product => 'Product',
      MoleculeRole.catalyst => 'Catalyst',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...list.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _moleculeInputCard('$label ${i + 1}', entry, role),
                ),
                if (list.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red.withValues(alpha: 0.5),
                    onPressed: () => _viewModel.removeMolecule(i, role),
                  ),
                ],
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _viewModel.addMolecule(role),
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add $label'),
        ),
      ],
    );
  }

  Widget _moleculeInputCard(
      String placeholder, MoleculeEntry entry, MoleculeRole role) {
    final uploaded = entry.file != null;
    final suggestions = entry.suggestions;
    final suggestionsLoading = entry.suggestionsLoading;

    return Container(
      decoration: BoxDecoration(
        color: uploaded
            ? Colors.greenAccent.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploaded
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  uploaded ? Icons.check_circle : Icons.science,
                  size: 16,
                  color: uploaded
                      ? Colors.greenAccent.shade200
                      : const Color(0xFF4FC3F7),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: entry.ctrl,
                  decoration: InputDecoration(
                    hintText: '$placeholder name or SMILES...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    if (uploaded) _viewModel.clearEntry(entry);
                    _viewModel.onSearchChanged(val, entry, context.read<ChemicalResolverService>());
                  },
                ),
              ),
              if (uploaded)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _viewModel.clearEntry(entry),
                  color: Colors.white54,
                ),
              if (!uploaded && entry.isResolving)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (!uploaded)
                Tooltip(
                  message: 'Upload XYZ structure',
                  child: IconButton(
                    icon: const Icon(Icons.upload_file, size: 18),
                    color: Colors.white54,
                    onPressed: () async {
                      final file = await FilePickerService.pickXyzFile();
                      if (file != null) {
                        entry.file = file;
                        entry.ctrl.text = file.name;
                        _viewModel.notifyListeners();
                      }
                    },
                  ),
                ),
            ],
          ),

          // ── Live suggestions dropdown ──────────────────────────────
          if (!uploaded && (suggestions.isNotEmpty || suggestionsLoading)) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: const Border(
                  top: BorderSide(color: Colors.white10),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: suggestionsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return InkWell(
                          onTap: () => _viewModel.onSuggestionSelected(
                            suggestion,
                            entry,
                            context.read<ChemicalResolverService>(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.science_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.35)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Results area ───────────────────────────────────────────────────────────
  Widget _buildResultsArea(ReactionStatusResponse status) {
    if (status.state == ReactionState.idle) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              'Or try a sample reaction to test the engine:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _sampleReactionChip('Diels-Alder (C4H6 + C2H4)'),
                _sampleReactionChip('SN2 (CH3Cl + OH-)'),
                _sampleReactionChip('E2 Elimination'),
              ],
            ),
          ],
        ),
      );
    }

    final summary = status.resultsSummary;
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Column(
          children: [
            // Status and Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: ReactionStatusCard(status: status)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: summary != null
                      ? ResultsHeaderCard(summary: summary)
                      : Container(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main metrics row (Barriers, Reaction Energy)
            if (summary != null) ...[
              HeroMetricsRow(metrics: summary.activationMetrics),
              const SizedBox(height: 16),

              // Left: Energy Profile, Right: Arrhenius
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: EnergyProfileCard(
                      metrics: summary.activationMetrics,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: ArrheniusPlotCard(
                      metrics: summary.activationMetrics,
                      tempRangeK: const [273.15, 298.15, 310.15, 330.15, 350.15],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thermo properties grid
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
          ],
        );
      },
    );
  }
}
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
