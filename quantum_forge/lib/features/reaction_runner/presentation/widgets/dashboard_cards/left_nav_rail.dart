// ============================================================================
// Professional Navigation Drawer
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NavDestination { library, newReaction, editor, history }

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A), // Darker, more professional hue
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Professional Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0288D1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.science, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QuantomForge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Enterprise Edition',
                          style: TextStyle(
                            color: Color(0xFF4FC3F7),
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
            
            const SizedBox(height: 16),
            
            // Section Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

          _navItem(Icons.auto_stories_outlined, 'Library', NavDestination.library),
          _navItem(Icons.add_circle_outline, 'New Reaction', NavDestination.newReaction),
          _navItem(Icons.edit_document, 'Editor', NavDestination.editor),
          _navItem(Icons.history, 'History', NavDestination.history),

          const Spacer(),

          // Professional Footer (User Profile & Controls)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: onToggleControls,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: controlsPanelOpen 
                          ? const Color(0xFF4FC3F7).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controlsPanelOpen
                            ? const Color(0xFF4FC3F7).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune, 
                             color: controlsPanelOpen ? const Color(0xFF4FC3F7) : Colors.white54, 
                             size: 18),
                        const SizedBox(width: 12),
                        Text(
                          controlsPanelOpen ? 'Hide Parameters' : 'Show Parameters',
                          style: TextStyle(
                            color: controlsPanelOpen ? Colors.white : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final name = user?.displayName ?? 'Researcher';
                    final email = user?.email ?? 'Unauthenticated';

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: Colors.white70, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                email,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                              ),
                            ],
                          ),
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
    ));
  }

  Widget _navItem(IconData icon, String label, NavDestination dest) {
    final active = current == dest;
    return InkWell(
      onTap: () => onDestinationSelected(dest),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuint,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF4FC3F7).withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? const Color(0xFF4FC3F7) : Colors.white38,
                size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
