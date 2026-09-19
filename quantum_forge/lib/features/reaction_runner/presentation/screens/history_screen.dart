import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/services/reaction_repository.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/auth/presentation/screens/auth_screen.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ReactionStatusResponse> _reactions = [];
  bool _isLoading = true;

  /// History is the one feature that needs an account; when signed out we show
  /// an invitation instead of querying Firestore with an empty user id.
  bool _requiresAuth = false;

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthService>();
      if (!await auth.isAuthenticated()) {
        if (!mounted) return;
        setState(() {
          _requiresAuth = true;
          _reactions = [];
          _isLoading = false;
        });
        return;
      }
      final userId = await auth.getUserId();
      if (!mounted) return;
      final repo = context.read<ReactionRepository>();
      final reactions = await repo.listReactions(userId);
      if (mounted) {
        setState(() {
          _requiresAuth = false;
          _reactions = reactions;
        });
      }
    } catch (e) {
      debugPrint('Error loading reactions: $e');
      if (mounted) {
        setState(() {
          _reactions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAuth() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => AuthScreen(
          onLoginSuccess: () {
            Navigator.of(ctx).pop();
            _loadReactions();
          },
        ),
      ),
    );
  }

  Future<void> _deleteReaction(String reactionId) async {
    final repo = context.read<ReactionRepository>();
    await repo.deleteReaction(reactionId);
    _loadReactions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requiresAuth) {
      return _AuthPrompt(onSignIn: _openAuth);
    }

    if (_reactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No past reactions found.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reaction History',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: AnimationLimiter(
              child: ListView.separated(
                itemCount: _reactions.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white12),
                itemBuilder: (context, index) {
                  final reaction = _reactions[index];
                  final isCompleted = reaction.state == ReactionState.completed;
                  final isFailed = reaction.state == ReactionState.error;

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            tileColor: Colors.black.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isCompleted
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : isFailed
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.blue.withValues(alpha: 0.2),
                              child: Icon(
                                isCompleted
                                    ? Icons.check
                                    : isFailed
                                    ? Icons.error_outline
                                    : Icons.sync,
                                color: isCompleted
                                    ? Colors.green
                                    : isFailed
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            ),
                            title: Text(
                              'Reaction: ${reaction.message != null && reaction.message!.isNotEmpty
                                  ? reaction.message
                                  : reaction.reactionId.length > 8
                                  ? '${reaction.reactionId.substring(0, 8)}...'
                                  : reaction.reactionId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Date: ${(reaction.createdAt ?? DateTime.now()).toLocal().toString().split('.')[0]}\nStatus: ${reaction.state.name}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _deleteReaction(reaction.reactionId),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reaction selected.'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when signed out: history needs an account, but the rest of the app does
/// not. Styled from the active theme so it matches every preset.
class _AuthPrompt extends StatelessWidget {
  final VoidCallback onSignIn;
  const _AuthPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
                ),
                child: Icon(Icons.history, size: 30, color: palette.accent),
              ),
              const SizedBox(height: 20),
              Text(
                'History needs an account',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Quantum Forge works fully without signing in. An account only '
                'adds cross-device history, so you can revisit and compare past '
                'runs.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign in to sync history'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
