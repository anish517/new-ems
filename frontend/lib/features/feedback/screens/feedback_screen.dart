import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  List _complaints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('${AppConstants.feedbackBase}/');
      if (!mounted) return;
      setState(() {
        _complaints = res.data is List
            ? res.data
            : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadComplaints());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Complaints'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadComplaints)]), 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubmitDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadComplaints,
              child: _complaints.isEmpty
                  ? const Center(child: Text('No complaints filed yet'))
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _complaints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = _complaints[i];
                        final status = c['status'] ?? 'pending';
                        final statusColor = status == 'resolved'
                            ? AppColors.success
                            : status == 'in_review'
                                ? AppColors.warning
                                : AppColors.textSecondary;
                        return GestureDetector(
                          onTap: () => _showComplaintDetails(c, isAdmin),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['title'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        if (c['owner_name'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text('By: ${c['owner_name']}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                        ],
                                        if (c['description'] != null) ...[
                                          const SizedBox(height: 6),
                                          Text(c['description'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status.replaceAll('_', ' ').toUpperCase(),
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          c['visibility'] ?? 'anonymous',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
            ),
    );
  }

  void _showComplaintDetails(Map c, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ComplaintDetailsSheet(
        complaint: c, 
        isAdmin: isAdmin,
        onReplySuccess: _loadComplaints
      ),
    );
  }

  void _showSubmitDialog(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _SubmitComplaintSheet(onSuccess: _loadComplaints),
      );
}

// ─── Submit Complaint Sheet ───────────────────────────────────────────────────
class _SubmitComplaintSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SubmitComplaintSheet({required this.onSuccess});

  @override
  State<_SubmitComplaintSheet> createState() => _SubmitComplaintSheetState();
}

class _SubmitComplaintSheetState extends State<_SubmitComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  String _title = '', _description = '';
  String _visibility = 'anonymous';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        '${AppConstants.feedbackBase}/',
        data: {
          'title': _title,
          'description': _description,
          'visibility': _visibility,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Complaint submitted successfully!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Submit Complaint',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _title = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description', alignLabelWithHint: true),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _description = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Visibility to Administration'),
                items: const [
                  DropdownMenuItem(value: 'identified', child: Text('Show my Name (Identified)')),
                  DropdownMenuItem(value: 'anonymous', child: Text('Hide my Name (Anonymous)')),
                ],
                onChanged: (v) => setState(() => _visibility = v!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ]),
          ),
        ),
      );
}

// ─── Complaint Details & Replies Sheet ────────────────────────────────────────
class _ComplaintDetailsSheet extends StatefulWidget {
  final Map complaint;
  final bool isAdmin;
  final VoidCallback onReplySuccess;
  const _ComplaintDetailsSheet({required this.complaint, required this.isAdmin, required this.onReplySuccess});

  @override
  State<_ComplaintDetailsSheet> createState() => _ComplaintDetailsSheetState();
}

class _ComplaintDetailsSheetState extends State<_ComplaintDetailsSheet> {
  final _replyController = TextEditingController();
  bool _isReplying = false;

  Future<void> _deleteComplaint() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Complaint'),
        content: const Text('Are you sure you want to delete this complaint?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete')
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().delete('${AppConstants.feedbackBase}/${widget.complaint['id']}/');
      widget.onReplySuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint deleted successfully'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e)), backgroundColor: AppColors.error));
    }
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isReplying = true);
    try {
      await ApiService().post(
        '${AppConstants.feedbackBase}/${widget.complaint['id']}/reply/',
        data: {'content': text},
      );
      if (mounted) {
        _replyController.clear();
        widget.onReplySuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Reply sent!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final replies = widget.complaint['replies'] as List? ?? [];
    
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.complaint['title'] ?? 'Complaint',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: _deleteComplaint,
                ),
            ],
          ),
          if (widget.complaint['owner_name'] != null) ...[
            const SizedBox(height: 4),
            Text('Submitted by: ${widget.complaint['owner_name']}',
                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 8),
          if (widget.complaint['description'] != null)
            Text(widget.complaint['description'],
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const Divider(height: 32),
          const Text('Replies',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (replies.isEmpty)
            const Text('No replies yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: replies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final reply = replies[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reply['employee_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(reply['content'] ?? '', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    hintText: 'Write a reply...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _isReplying ? null : _submitReply,
                icon: _isReplying
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
