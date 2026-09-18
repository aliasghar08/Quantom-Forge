import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'glass_card.dart';

class ReactionProgressCard extends StatefulWidget {
  final ReactionStatusResponse status;

  const ReactionProgressCard({super.key, required this.status});

  @override
  State<ReactionProgressCard> createState() => _ReactionProgressCardState();
}

class _ReactionProgressCardState extends State<ReactionProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine color based on state
    Color activeColor = const Color(0xFF4FC3F7); // Default pending
    if (widget.status.state == ReactionState.optimizing) {
      activeColor = Colors.amber.shade400;
    } else if (widget.status.state == ReactionState.completed) {
      activeColor = Colors.greenAccent;
    } else if (widget.status.state == ReactionState.error) {
      activeColor = Colors.redAccent;
    }

    // Default message
    String displayMessage = widget.status.message ?? 'Warming up quantum engines...';
    if (widget.status.state == ReactionState.pending && widget.status.message == null) {
      displayMessage = 'Queued for compute...';
    }

    final pct = (widget.status.progress * 100).clamp(0, 100).toInt();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated Icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withValues(alpha: 0.1 * _pulseAnimation.value),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.2 * _pulseAnimation.value),
                          blurRadius: 30 * _pulseAnimation.value,
                          spreadRadius: 10 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.status.state == ReactionState.pending
                          ? Icons.cloud_upload_outlined
                          : Icons.science_outlined,
                      size: 64,
                      color: activeColor,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Percentage text
            Text(
              '$pct%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                shadows: [
                  Shadow(color: activeColor.withValues(alpha: 0.5), blurRadius: 20)
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Message
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: widget.status.progress > 0 ? widget.status.progress : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
