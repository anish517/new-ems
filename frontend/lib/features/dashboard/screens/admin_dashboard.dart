import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _employeeCount = 0;
  int _pendingLeaves = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // Employee count
      final empRes = await ApiService().get(
          '${AppConstants.organizationBase}/employees/');
      final employees = empRes.data is List
          ? empRes.data
          : (empRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() => _employeeCount = (employees as List).length);

      // Pending leave requests
      final leaveRes = await ApiService().get(
          '${AppConstants.leaveBase}/leave-requests/');
      final leaves = leaveRes.data is List
          ? leaveRes.data
          : (leaveRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() {
        _pendingLeaves = (leaves as List)
            .where((l) => l['is_approved'] != true && l['is_reviewed'] != true)
            .length;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Admin Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(user?.fullName ?? 'Admin',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
          IconButton(
            icon: const Icon(Iconsax.notification),
            onPressed: () => context.go('/notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(user?.firstName[0].toUpperCase() ?? 'A',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stats row
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Row(children: [
                      Expanded(child: _StatCard('Total Employees',
                          '$_employeeCount', Iconsax.people, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard('Pending Leaves',
                          '$_pendingLeaves', Iconsax.calendar_remove, AppColors.warning)),
                    ]),
                  ]),
            const SizedBox(height: 24),

            // Management actions
            const Text('Management',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            _ManagementTile(Iconsax.people, 'Employee Management',
                'Add, edit, deactivate employees', () => context.go('/employees')),
            _ManagementTile(Iconsax.clock, 'Attendance Monitor',
                'View all employee attendance', () => context.go('/attendance')),
            _ManagementTile(Iconsax.calendar_remove, 'Leave Approvals',
                'Review and approve leave requests', () => context.go('/leave')),
            _ManagementTile(Iconsax.money, 'Salary Management',
                'Process monthly payroll', () => context.go('/salary')),
            _ManagementTile(Iconsax.task_square, 'Projects & Tasks',
                'Manage projects and assign tasks', () => context.go('/tasks')),
            _ManagementTile(Iconsax.message_text, 'Notice Board',
                'Post organization notices', () => context.go('/noticeboard')),
            _ManagementTile(Iconsax.calendar, 'Calendar',
                'Manage events and holidays', () => context.go('/calendar')),
            _ManagementTile(Iconsax.message_question, 'Feedback / Complaints',
                'Review employee complaints', () => context.go('/feedback')),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 8),
      Text(value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ManagementTile(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
    onTap: onTap,
  );
}
