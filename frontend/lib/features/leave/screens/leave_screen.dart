import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    try {
      final res = await ApiService().get('${AppConstants.leaveBase}/');
      setState(() { _requests = res.data['results'] ?? res.data; _isLoading = false; });
    } catch (_) { setState(() => _isLoading = false); }
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
          if (isAdmin) const Tab(text: 'Pending Approvals'),
          if (!isAdmin) const Tab(text: 'Balance'),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
        backgroundColor: AppColors.primary,
      ),
      body: TabBarView(controller: _tabs, children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? const Center(child: Text('No leave requests found'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _LeaveCard(_requests[i]),
                  ),
        const Center(child: Text('Pending approvals coming soon')),
      ]),
    );
  }

  void _showApplyLeaveDialog(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ApplyLeaveSheet(),
  );
}

class _LeaveCard extends StatelessWidget {
  final Map data;
  const _LeaveCard(this.data);

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
      title: Text(data['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('${data['from_date']} → ${data['till_date']}',
            style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(data['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
            style: TextStyle(fontSize: 11,
                color: data['is_paid'] == true ? AppColors.success : AppColors.warning)),
      ]),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_status, style: TextStyle(color: _statusColor, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

class _ApplyLeaveSheet extends StatelessWidget {
  const _ApplyLeaveSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 24, right: 24, top: 24,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Apply for Leave', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const TextField(decoration: InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'From Date (BS)')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Till Date (BS)')),
        const SizedBox(height: 12),
        const TextField(maxLines: 3, decoration: InputDecoration(labelText: 'Reason')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => Navigator.pop(context),
            child: const Text('Submit Leave Request')),
      ]),
  );
}
