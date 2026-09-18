// ============================================================================
// Left Navigation Rail — sidebar nav for the Dashboard
// ============================================================================

import 'package:flutter/material.dart';

enum NavDestination { library, newJob, editor, history }

class LeftNavRail extends StatelessWidget {
  final NavDestination current;
  final ValueChanged<NavDestination> onDestinationSelected;
  final bool controlsPanelOpen;
  final VoidCallback onToggleControls;

  const LeftNavRail({
    super.key,
    required this.current,
    required this.onDestinationSelected,
    required this.controlsPanelOpen,
    required this.onToggleControls,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ColabRxn',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),

          _navItem(Icons.auto_stories_outlined, 'Library', NavDestination.library),
          _navItem(Icons.add_circle_outline, 'New Job', NavDestination.newJob),
          _navItem(Icons.edit_document, 'Editor', NavDestination.editor),
          _navItem(Icons.history, 'History', NavDestination.history),

          const Spacer(),

          // Toggle controls panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: onToggleControls,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune, color: Color(0xFF4FC3F7), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      controlsPanelOpen ? 'Hide Controls' : 'Show Controls',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, NavDestination dest) {
    final active = current == dest;
    return InkWell(
      onTap: () => onDestinationSelected(dest),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? const Color(0xFF4FC3F7).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? const Color(0xFF4FC3F7) : Colors.white38,
                size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
