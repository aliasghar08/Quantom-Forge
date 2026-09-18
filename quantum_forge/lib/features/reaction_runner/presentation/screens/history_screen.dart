import 'package:flutter/material.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/core/services/reaction_repository.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    setState(() => _isLoading = true);
    try {
      final auth = ProviderScope.read<AuthService>(context);
      final userId = await auth.getUserId();
      if (!mounted) return;
      final repo = ProviderScope.read<ReactionRepository>(context);
      final reactions = await repo.listReactions(userId);
      if (mounted) {
        setState(() {
          _reactions = reactions;
        });
      }
    } catch (e) {
      print('Error loading reactions: $e');
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

  Future<void> _deleteReaction(String reactionId) async {
    final repo = ProviderScope.read<ReactionRepository>(context);
    await repo.deleteReaction(reactionId);
    _loadReactions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No past reactions found.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: AnimationLimiter(
              child: ListView.separated(
                itemCount: _reactions.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white12),
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          tileColor: Colors.black.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          leading: CircleAvatar(
                            backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.2) : 
                                             isFailed ? Colors.red.withValues(alpha: 0.2) : 
                                             Colors.blue.withValues(alpha: 0.2),
                            child: Icon(
                              isCompleted ? Icons.check : 
                              isFailed ? Icons.error_outline : 
                              Icons.sync,
                              color: isCompleted ? Colors.green : 
                                     isFailed ? Colors.red : 
                                     Colors.blue,
                            ),
                          ),
                          title: Text(
                            'Reaction: ${reaction.message != null && reaction.message!.isNotEmpty ? reaction.message : reaction.reactionId.length > 8 ? '${reaction.reactionId.substring(0, 8)}...' : reaction.reactionId}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${(reaction.createdAt ?? DateTime.now()).toLocal().toString().split('.')[0]}\nStatus: ${reaction.state.name}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteReaction(reaction.reactionId),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reaction selected.')),
                            );
                          },
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
