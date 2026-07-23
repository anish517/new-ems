import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';

// ─── Date formatter ───────────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  DateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      if (s.contains('T')) return DateTime.parse(s);
      return NepaliDateTime.parse(s).toDateTime();
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
  }

  final date = parseDate(raw) ?? parseDate(fallback);
  if (date != null) {
    return DateFormat('dd MMM yyyy').format(date);
  }
  return DateFormat('dd MMM yyyy').format(DateTime.now());
}

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _requests = [];
  Map<String, dynamic>? _balance;
  List _pending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadLeaves();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      final isAdmin = user?.canManage ?? false;

      // My leave requests
      final res = await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      if (!mounted) return;
      setState(() {
        _requests = res.data is List ? res.data : (res.data['results'] ?? res.data);
      });

      if (isAdmin) {
        // Admin: fetch all pending requests
        try {
          final pendingRes = await ApiService().get(
            '${AppConstants.leaveBase}/leave-requests/',
          );
          final all = pendingRes.data is List
              ? pendingRes.data
              : (pendingRes.data['results'] ?? []);
          if (mounted) {
            setState(() => _pending = all.where((r) =>
              r['is_approved'] != true && r['is_reviewed'] != true).toList());
          }
        } catch (_) {}
      } else {
        // Employee: fetch leave balance
        if (user?.employeeId != null) {
          try {
            final balRes = await ApiService().get(
              '${AppConstants.leaveBase}/leave-balance/${user!.employeeId}/',
            );
            if (mounted) setState(() => _balance = balRes.data);
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _approveLeave(int leaveId, bool approve) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().patch(
        '${AppConstants.leaveBase}/update/$leaveId/',
        data: {'is_approved': approve, 'is_reviewed': true},
      );
      messenger.showSnackBar(SnackBar(
        content: Text(approve ? '✅ Leave approved' : '❌ Leave rejected'),
        backgroundColor: approve ? AppColors.success : AppColors.error,
      ));
      _loadLeaves();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: ${ApiService.getErrorMessage(e)}'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _deleteLeave(int leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Leave Request'),
        content: const Text('Are you sure you want to delete this leave request?'),
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
      await ApiService().delete('${AppConstants.leaveBase}/update/$leaveId/');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request deleted successfully'), backgroundColor: AppColors.success));
      _loadLeaves();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        bottom: TabBar(controller: _tabs, tabs: [
          const Tab(text: 'My Leaves'),
          Tab(text: isAdmin ? 'Pending Approvals' : 'Balance'),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              // Tab 1: My Leaves
              RefreshIndicator(
                onRefresh: _loadLeaves,
                child: _requests.isEmpty
                    ? const Center(child: Text('No leave requests yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _LeaveCard(_requests[i], isAdmin: isAdmin, onDelete: () => _deleteLeave(_requests[i]['id'])),
                      ),
              ),

              // Tab 2: Pending Approvals (admin) OR Balance (employee)
              isAdmin
                  ? RefreshIndicator(
                      onRefresh: _loadLeaves,
                      child: _pending.isEmpty
                          ? const Center(child: Text('No pending requests'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pending.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _AdminLeaveCard(
                                leave: _pending[i],
                                onApprove: () => _approveLeave(_pending[i]['id'], true),
                                onReject:  () => _approveLeave(_pending[i]['id'], false),
                                onDelete:  () => _deleteLeave(_pending[i]['id']),
                              ),
                            ),
                    )
                  : _LeaveBalanceTab(balance: _balance),
            ]),
    );
  }

  void _showApplyLeaveDialog(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _ApplyLeaveSheet(onSuccess: _loadLeaves),
      );
}

// ─── Leave Card (My Leaves) ──────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final Map data;
  final bool isAdmin;
  final VoidCallback onDelete;
  const _LeaveCard(this.data, {required this.isAdmin, required this.onDelete});

  Color get _statusColor {
    if (data['is_approved'] == true) return AppColors.success;
    if (data['is_reviewed'] == true) return AppColors.warning;
    return AppColors.textSecondary;
  }

  String get _status {
    if (data['is_approved'] == true) return 'Approved';
    if (data['is_reviewed'] == true) return 'Under Review';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(data['subject'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('${_fmtDate(data['from_date']?.toString())} → ${_fmtDate(data['till_date']?.toString())}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(data['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
                style: TextStyle(
                    fontSize: 11,
                    color: data['is_paid'] == true
                        ? AppColors.success
                        : AppColors.warning)),
          ]),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              if (isAdmin || _status == 'Pending') ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      );
}

// ─── Admin Leave Approval Card ───────────────────────────────────────────────
class _AdminLeaveCard extends StatelessWidget {
  final Map leave;
  final VoidCallback onApprove, onReject, onDelete;
  const _AdminLeaveCard({required this.leave, required this.onApprove, required this.onReject, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(leave['subject'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Pending',
                    style: TextStyle(color: AppColors.warning, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ]),

            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(leave['employee_name'] ?? 'Unknown Employee',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${_fmtDate(leave['from_date']?.toString())} → ${_fmtDate(leave['till_date']?.toString())}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
            if (leave['remarks'] != null && (leave['remarks'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(leave['remarks'],
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              )),
            ]),
          ]),
        ),
      );
}

// ─── Leave Balance Tab ───────────────────────────────────────────────────────
class _LeaveBalanceTab extends StatelessWidget {
  final Map<String, dynamic>? balance;
  const _LeaveBalanceTab({this.balance});

  @override
  Widget build(BuildContext context) {
    if (balance == null) {
      return const Center(child: Text('Leave balance not available'));
    }
    final leaveBalances = balance!['leave_balances'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('Leave Summary', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('${balance!['no_of_leaves_taken'] ?? 0} days taken',
                style: const TextStyle(color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.bold)),
            Text('${balance!['remaining_leaves'] ?? 0} days remaining',
                style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 20),
        if (leaveBalances.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('By Leave Type',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ...leaveBalances.map((lb) => _LeaveTypeTile(lb)),
        ],
      ]),
    );
  }
}

class _LeaveTypeTile extends StatelessWidget {
  final dynamic lb;
  const _LeaveTypeTile(this.lb);

  @override
  Widget build(BuildContext context) {
    final used = lb['used_days'] ?? 0;
    final total = lb['leave_type']?['maximum_leave'] ?? 1;
    final pct = (used / total).clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(lb['leave_type']?['name'] ?? 'Leave',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$used / $total days',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.surfaceDark,
            color: pct > 0.8 ? AppColors.error : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ]),
      ),
    );
  }
}

// ─── Apply Leave Sheet ───────────────────────────────────────────────────────
class _ApplyLeaveSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _ApplyLeaveSheet({required this.onSuccess});

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();
  String _subject = '', _fromDate = '', _tillDate = '', _reason = '';
  bool _isPaid = true;
  bool _isLoading = false;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        if (isFrom) {
          _fromDate = dateStr;
          _fromCtrl.text = dateStr;
        } else {
          _tillDate = dateStr;
          _tillCtrl.text = dateStr;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_fromDate.isEmpty || _tillDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select both From Date and Till Date'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        '${AppConstants.leaveBase}/leave-requests/',
        data: {
          'subject': _subject,
          'from_date': _fromDate,
          'till_date': _tillDate,
          'remarks': _reason,
          'is_paid': _isPaid,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Leave request submitted!'),
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
              const Text('Apply for Leave',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _subject = v!,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _fromCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(true),
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _tillCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(false),
                  decoration: const InputDecoration(
                    labelText: 'Till Date',
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
                onSaved: (v) => _reason = v ?? '',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Paid Leave'),
                subtitle: const Text('Toggle off for unpaid leave'),
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Leave Request'),
              ),
            ]),
          ),
        ),
      );
}
