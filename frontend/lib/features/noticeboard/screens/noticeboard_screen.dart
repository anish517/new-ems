import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class NoticeboardScreen extends ConsumerStatefulWidget {
  const NoticeboardScreen({super.key});
  @override
  ConsumerState<NoticeboardScreen> createState() => _NoticeboardScreenState();
}

class _NoticeboardScreenState extends ConsumerState<NoticeboardScreen> {
  List _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get(AppConstants.noticesEndpoint);
      if (!mounted) return;
      setState(() {
        _notices = res.data is List
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
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board')),
      floatingActionButton: isAdmin

          ? FloatingActionButton.extended(
              onPressed: () => _showCreateNotice(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Post Notice'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotices,
              child: _notices.isEmpty
                  ? const Center(child: Text('No notices yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _notices[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      Text(n['date'] ?? n['created_at'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                    ],
                                  )),
                                ]),
                                if (n['description'] != null ||
                                    n['content'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(n['description'] ?? n['content'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
            ),
    );
  }

  void _showCreateNotice(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _CreateNoticeSheet(onSuccess: _loadNotices),
      );
}

// ─── Create Notice Sheet ─────────────────────────────────────────────────────
class _CreateNoticeSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _CreateNoticeSheet({required this.onSuccess});

  @override
  State<_CreateNoticeSheet> createState() => _CreateNoticeSheetState();
}

class _CreateNoticeSheetState extends State<_CreateNoticeSheet> {
  final _formKey = GlobalKey<FormState>();
  String _title = '', _description = '';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        AppConstants.noticesEndpoint,
        data: {
          'title': _title,
          'description': _description,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Notice posted!'),
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
              const Text('Post Notice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notice Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _title = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Content', alignLabelWithHint: true),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _description = v!,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post Notice'),
              ),
            ]),
          ),
        ),
      );
}
