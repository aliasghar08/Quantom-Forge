// ============================================================================
// FeedbackService — automatic crash capture + manual issue reporting
// ----------------------------------------------------------------------------
// Automatic path: hooks FlutterError.onError and
//   PlatformDispatcher.instance.onError on startup. Any unhandled error is
//   queued and forwarded to Formspree (email delivery) with device info.
//
// Manual path: call FeedbackService.showFeedbackDialog(context) from anywhere
//   in the UI to open a rich feedback dialog.
//
// Email delivery: powered by https://formspree.io — free tier supports
//   50 submissions / month. Replace FORMSPREE_ENDPOINT with your endpoint.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── Configuration ────────────────────────────────────────────────────────────
/// Replace with your Formspree endpoint:
/// 1. Go to https://formspree.io → New Form → copy the endpoint URL.
/// 2. It looks like https://formspree.io/f/xXXXXXXX
/// The form will email submissions to aliasgharcoolboy28@gmail.com
const _kFormspreeEndpoint = 'https://formspree.io/f/mwpbqkdb';
const _kMaxAutoReportRate = Duration(seconds: 30);

class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  DateTime? _lastAutoReport;
  final List<String> _recentLogs = [];
  static const int _maxLogs = 50;

  // ── Initialise ──────────────────────────────────────────────────────────────

  /// Call once from main() — before runApp.
  void initialize() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      originalOnError?.call(details);
      _captureFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _captureUncaughtError(error, stack);
      return false; // Let the platform also handle it
    };
  }

  // ── Log capture ─────────────────────────────────────────────────────────────

  /// Add a custom log entry (e.g. from debugPrint replacement).
  void log(String message) {
    final entry = '[${DateTime.now().toIso8601String()}] $message';
    _recentLogs.add(entry);
    if (_recentLogs.length > _maxLogs) _recentLogs.removeAt(0);
  }

  String get _logSnapshot => _recentLogs.join('\n');

  // ── Auto-capture ─────────────────────────────────────────────────────────────

  void _captureFlutterError(FlutterErrorDetails details) {
    final now = DateTime.now();
    if (_lastAutoReport != null &&
        now.difference(_lastAutoReport!) < _kMaxAutoReportRate) {
      return;
    }
    _lastAutoReport = now;

    unawaited(_sendReport(
      type: 'Automatic — FlutterError',
      message: details.exceptionAsString(),
      stack: details.stack?.toString() ?? 'No stack',
      logs: _logSnapshot,
    ));
  }

  void _captureUncaughtError(Object error, StackTrace stack) {
    final now = DateTime.now();
    if (_lastAutoReport != null &&
        now.difference(_lastAutoReport!) < _kMaxAutoReportRate) {
      return;
    }
    _lastAutoReport = now;

    unawaited(_sendReport(
      type: 'Automatic — Uncaught Error',
      message: error.toString(),
      stack: stack.toString(),
      logs: _logSnapshot,
    ));
  }

  // ── Manual report ────────────────────────────────────────────────────────────

  Future<bool> sendManualReport({
    required String title,
    required String description,
    String? email,
    String severity = 'bug',
  }) async {
    return _sendReport(
      type: 'Manual ($severity)',
      message: title,
      stack: description,
      logs: _logSnapshot,
      userEmail: email,
    );
  }

  // ── Network ──────────────────────────────────────────────────────────────────

  Future<bool> _sendReport({
    required String type,
    required String message,
    required String stack,
    required String logs,
    String? userEmail,
  }) async {
    try {
      final body = <String, String>{
        'type': type,
        'message': message,
        'stack': stack.length > 2000 ? stack.substring(0, 2000) : stack,
        'logs': logs.length > 2000 ? logs.substring(0, 2000) : logs,
        'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        if (userEmail != null && userEmail.isNotEmpty) '_replyto': userEmail,
        '_subject': 'Quantum Forge Bug Report: $type',
      };

      final response = await http
          .post(
            Uri.parse(_kFormspreeEndpoint),
            headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  /// Shows the manual feedback dialog. Returns true if user submitted.
  static Future<bool> showFeedbackDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => const _FeedbackDialog(),
    ) ?? false;
  }
}

// ─── Feedback Dialog ──────────────────────────────────────────────────────────

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _severity = 'bug';
  bool _sending = false;
  bool _sent = false;
  bool _failed = false;

  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _failed = false;
    });

    final ok = await FeedbackService.instance.sendManualReport(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      severity: _severity,
    );

    if (mounted) {
      setState(() {
        _sending = false;
        _sent = ok;
        _failed = !ok;
      });
    }
    if (ok && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4FC3F7), Color(0xFF6C63FF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bug_report_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send Feedback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Report bugs or suggest improvements', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  if (_sent) ...[
                    _buildSuccessBanner(),
                  ] else ...[
                    // ── Severity ──────────────────────────────────
                    Row(children: [
                      _SeverityChip(label: '🐛 Bug', value: 'bug', selected: _severity == 'bug', onTap: () => setState(() => _severity = 'bug')),
                      const SizedBox(width: 8),
                      _SeverityChip(label: '💡 Idea', value: 'feature', selected: _severity == 'feature', onTap: () => setState(() => _severity = 'feature')),
                      const SizedBox(width: 8),
                      _SeverityChip(label: '🚨 Crash', value: 'crash', selected: _severity == 'crash', onTap: () => setState(() => _severity = 'crash')),
                    ]),
                    const SizedBox(height: 16),

                    // ── Title ─────────────────────────────────────
                    _buildField(
                      controller: _titleCtrl,
                      label: 'Title',
                      hint: 'Brief description of the issue',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a title' : null,
                    ),
                    const SizedBox(height: 12),

                    // ── Description ───────────────────────────────
                    _buildField(
                      controller: _descCtrl,
                      label: 'Details',
                      hint: 'Steps to reproduce, what you expected vs what happened…',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),

                    // ── Email ─────────────────────────────────────
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Your email (optional)',
                      hint: 'So we can follow up',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Recent app logs are included automatically to help diagnose the issue.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                    ),

                    if (_failed) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Text('Failed to send. Check your connection and try again.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Action ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_sending ? 'Sending…' : 'Send Report'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 40),
          SizedBox(height: 12),
          Text('Report sent!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Thank you. We will review and respond if you provided an email.', style: TextStyle(color: Colors.white60, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4FC3F7).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF4FC3F7).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF4FC3F7) : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
