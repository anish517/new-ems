import 'package:flutter/material.dart';
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
      return NepaliDateFormat('dd MMM yyyy').format(DateTime.parse(s).toNepaliDateTime());
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
  String _searchQuery = '';

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

      // My leave requests (admins get all org requests, employees get only theirs)
      final res =
          await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      if (!mounted) return;
      final all =
          res.data is List ? res.data : (res.data['results'] ?? res.data);

      setState(() {
        _requests = all;
        // For admins: derive pending list from the same response — no second request needed
        if (isAdmin) {
          _pending = (all as List)
              .where((r) =>
                  r['is_approved'] != true && r['is_reviewed'] != true)
              .toList();
        }
      });

      if (!isAdmin) {
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
        content:
            const Text('Are you sure you want to delete this leave request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().delete('${AppConstants.leaveBase}/update/$leaveId/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Leave request deleted successfully'),
            backgroundColor: AppColors.success));
      }
      _loadLeaves();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadLeaves());
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(text: isAdmin ? 'All Leaves' : 'My Leaves'),
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
              // Tab 1: All Leaves (Admin) or My Leaves (Employee)
              RefreshIndicator(
                onRefresh: _loadLeaves,
                child: Builder(builder: (context) {
                  var filtered = _requests;
                  if (isAdmin && _searchQuery.isNotEmpty) {
                    filtered = _requests.where((r) {
                      final name =
                          (r['employee_name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList();
                  }

                  return Column(
                    children: [
                      if (isAdmin)
                        Padding(
                          padding:
                              const EdgeInsets.all(16.0).copyWith(bottom: 0),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by employee name...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No leave requests found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => _LeaveCard(filtered[i],
                                    isAdmin: isAdmin,
                                    onDelete: () =>
                                        _deleteLeave(filtered[i]['id'])),
                              ),
                      ),
                    ],
                  );
                }),
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
                                onApprove: () =>
                                    _approveLeave(_pending[i]['id'], true),
                                onReject: () =>
                                    _approveLeave(_pending[i]['id'], false),
                                onDelete: () => _deleteLeave(_pending[i]['id']),
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
        child: InkWell(
          onTap: () => _showLeaveDetails(context, data, isAdmin),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin && data['employee_name'] != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(data['employee_name'],
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(data['subject'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          data['is_half_day'] == true
                              ? 'Half Day (${data['half_day_period'] ?? 'N/A'}) • ${_fmtDate(data['from_date']?.toString())}'
                              : '${_fmtDate(data['from_date']?.toString())} → ${_fmtDate(data['till_date']?.toString())}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                          data['is_paid'] == true
                              ? 'Paid Leave'
                              : 'Unpaid Leave',
                          style: TextStyle(
                              fontSize: 11,
                              color: data['is_paid'] == true
                                  ? AppColors.success
                                  : AppColors.warning)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        onPressed: onDelete,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── Admin Leave Approval Card ───────────────────────────────────────────────
class _AdminLeaveCard extends StatelessWidget {
  final Map leave;
  final VoidCallback onApprove, onReject, onDelete;
  const _AdminLeaveCard(
      {required this.leave,
      required this.onApprove,
      required this.onReject,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: () => _showLeaveDetails(context, leave, true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(leave['subject'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Pending',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(leave['employee_name'] ?? 'Unknown Employee',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                    leave['is_half_day'] == true
                        ? 'Half Day (${leave['half_day_period'] ?? 'N/A'}) • ${_fmtDate(leave['from_date']?.toString())}'
                        : '${_fmtDate(leave['from_date']?.toString())} → ${_fmtDate(leave['till_date']?.toString())}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ]),
              if (leave['remarks'] != null &&
                  (leave['remarks'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(leave['remarks'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                )),
              ]),
            ]),
          ),
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
    final leaveBalances = (balance!['leave_balances'] as List?) ?? [];

    // Compute totals from the per-type list
    int totalTaken = 0;
    int totalQuota = 0;
    for (final lb in leaveBalances) {
      totalTaken += (lb['leaves_taken'] as num? ?? 0).toInt();
      totalQuota += (lb['leave_type']?['quota'] as num? ?? 0).toInt();
    }
    final remaining = (totalQuota - totalTaken).clamp(0, totalQuota);

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
            const Text('Leave Summary',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('$totalTaken days taken',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            Text('$remaining days remaining',
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
    // Backend fields: leaves_taken (int), leave_type.quota (int), leave_type.name (str)
    final used = (lb['leaves_taken'] as num? ?? 0).toInt();
    final total = (lb['leave_type']?['quota'] as num? ?? 1).toInt();
    final remaining = (total - used).clamp(0, total);
    final pct = total > 0 ? (used / total).clamp(0.0, 1.0).toDouble() : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(lb['leave_type']?['name'] ?? 'Leave',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$used used · $remaining left',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text('Total quota: $total days',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
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
  bool _isHalfDay = false;
  String _halfDayPeriod = 'First Half';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        final dateStr =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
          'is_half_day': _isHalfDay,
          if (_isHalfDay) 'half_day_period': _halfDayPeriod,
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
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Apply for Leave',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Subject'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    onSaved: (v) => _subject = v!,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                      controller: _fromCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(true),
                      decoration: const InputDecoration(
                        labelText: 'From Date',
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                      controller: _tillCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(false),
                      decoration: const InputDecoration(
                        labelText: 'Till Date',
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Reason (optional)'),
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
                  SwitchListTile(
                    title: const Text('Half Day Leave'),
                    subtitle: const Text('Apply for half-day only'),
                    value: _isHalfDay,
                    onChanged: (v) => setState(() {
                      _isHalfDay = v;
                      if (v) {
                        _tillCtrl.text = _fromCtrl
                            .text; // sync till date with from date for half day
                      }
                      if (v) _tillDate = _fromDate;
                    }),
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isHalfDay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Half Day Period'),
                        initialValue: _halfDayPeriod,
                        items: const [
                          DropdownMenuItem(
                              value: 'First Half', child: Text('First Half')),
                          DropdownMenuItem(
                              value: 'Second Half', child: Text('Second Half')),
                        ],
                        onChanged: (v) => setState(() => _halfDayPeriod = v!),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Leave Request'),
                  ),
                ]),
          ),
        ),
      );
}

void _showLeaveDetails(BuildContext context, Map leave, bool isAdmin) {
  String status = 'Pending';
  Color statusColor = AppColors.textSecondary;
  if (leave['is_approved'] == true) {
    status = 'Approved';
    statusColor = AppColors.success;
  } else if (leave['is_reviewed'] == true) {
    status = 'Under Review';
    statusColor = AppColors.warning;
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Expanded(
              child: Text('Leave Details',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin && leave['employee_name'] != null) ...[
              _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Employee',
                  value: leave['employee_name']),
              const SizedBox(height: 12),
            ],
            _DetailRow(
                icon: Icons.description_outlined,
                label: 'Subject',
                value: leave['subject'] ?? 'No Subject'),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: leave['is_half_day'] == true
                  ? '${_fmtDate(leave['from_date']?.toString())} (Half Day)'
                  : 'From ${_fmtDate(leave['from_date']?.toString())} to ${_fmtDate(leave['till_date']?.toString())}',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Duration',
              value: leave['is_half_day'] == true
                  ? '0.5 days (${leave['half_day_period'] ?? 'N/A'})'
                  : '${leave['no_days']} days',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.credit_card_outlined,
              label: 'Type',
              value: leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
              valueColor: leave['is_paid'] == true
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(height: 16),
            const Text('Description',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(leave['description'] ?? 'No description provided.',
                style: const TextStyle(fontSize: 14)),
            if (leave['remarks'] != null &&
                (leave['remarks'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Remarks',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(leave['remarks'], style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: valueColor ?? AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
