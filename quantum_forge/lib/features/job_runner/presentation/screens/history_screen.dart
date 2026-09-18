import 'package:flutter/material.dart';
import 'package:quantum_forge/core/state/provider.dart';
import 'package:quantum_forge/core/services/job_repository.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<JobStatusResponse> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final auth = ProviderScope.read<AuthService>(context);
      final userId = await auth.getUserId();
      if (!mounted) return;
      final repo = ProviderScope.read<JobRepository>(context);
      final jobs = await repo.listJobs(userId);
      if (mounted) {
        setState(() {
          _jobs = jobs;
        });
      }
    } catch (e) {
      print('Error loading jobs: $e');
      if (mounted) {
        setState(() {
          _jobs = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteJob(String jobId) async {
    final repo = ProviderScope.read<JobRepository>(context);
    await repo.deleteJob(jobId);
    _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_jobs.isEmpty) {
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
            child: ListView.separated(
              itemCount: _jobs.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final job = _jobs[index];
                final isCompleted = job.state == JobState.completed;
                final isFailed = job.state == JobState.error;
                
                return ListTile(
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
                    'Reaction: ${job.message != null && job.message!.isNotEmpty ? job.message : job.jobId.length > 8 ? '${job.jobId.substring(0, 8)}...' : job.jobId}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: ${(job.createdAt ?? DateTime.now()).toLocal().toString().split('.')[0]}\nStatus: ${job.state.name}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteJob(job.jobId),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reaction selected.')),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
