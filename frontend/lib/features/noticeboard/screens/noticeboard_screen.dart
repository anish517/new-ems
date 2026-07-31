import 'package:ems_app/shared/widgets/responsive_grid_list.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/nepali_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';

// ─── Date formatter ───────────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return '';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMM yyyy')
          .format(DateTime.parse(s).toNepaliDateTime());
    }
    return NepaliDateFormat('dd MMM yyyy').format(NepaliDateTime.parse(s));
  } catch (_) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

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
        _notices =
            res.data is List ? res.data : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadNotices());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateNotice(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
                  : ResponsiveGridList(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notices.length,
                      itemBuilder: (ctx, i) {
                        final n = _notices[i];
                        final desc = n['description'] ?? n['content'] ?? '';
                        // Strip simple HTML tags for preview
                        final cleanDesc =
                            desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                        return InkWell(
                          onTap: () => _showNoticeDetail(ctx, n, isAdmin),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
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
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(n['title'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15)),
                                        Text(
                                            _fmtDate(n['date']?.toString(),
                                                fallback: n['created_at']
                                                    ?.toString()),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    )),
                                    const Icon(Icons.chevron_right,
                                        color: AppColors.textSecondary),
                                  ]),
                                  if (cleanDesc.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(cleanDesc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
            ),
    );
  }

  void _showNoticeDetail(BuildContext ctx, Map n, bool isAdmin) {
    final desc = n['description'] ?? n['content'] ?? '';
    final cleanDesc = desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(n['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                _fmtDate(n['date']?.toString(),
                    fallback: n['created_at']?.toString()),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            if (cleanDesc.isNotEmpty)
              Text(cleanDesc,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textSecondary))
            else
              const Text('No content available.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
          ]),
        ),
      ),
    );
  }

  void _showCreateNotice(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 600),
        backgroundColor: context.surface,
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
  final _dateCtrl = TextEditingController();
  String _title = '', _description = '', _date = '';
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final nepaliPicked = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: 'Select Date',
        initial: NepaliDateTime.now(),
      ),
    );
    if (nepaliPicked != null) {
      setState(() {
        final dateStr =
            '${nepaliPicked.year}-${nepaliPicked.month.toString().padLeft(2, '0')}-${nepaliPicked.day.toString().padLeft(2, '0')}';
        _date = dateStr;
        _dateCtrl.text = dateStr;
      });
    }
  }

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
          if (_date.isNotEmpty) 'date': _date,
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
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Post Notice', style: AppTextStyles.pageTitle),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Notice Title'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    onSaved: (v) => _title = v!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Notice Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _pickDate,
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
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Post Notice'),
                  ),
                ]),
          ),
        ),
      );
}
