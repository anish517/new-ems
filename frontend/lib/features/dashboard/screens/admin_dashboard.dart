import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Admin Dashboard', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text('${user?.fullName ?? 'Admin'}', style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
        ]),
        centerTitle: false,
        actions: [
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stats row
          Row(children: [
            Expanded(child: _StatCard('Employees', '—', Iconsax.people, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Present Today', '—', Iconsax.clock, AppColors.success)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard('Pending Leaves', '—', Iconsax.calendar_remove, AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Active Projects', '—', Iconsax.task_square, AppColors.accent)),
          ]),
          const SizedBox(height: 24),

          // Management actions
          const Text('Management', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: const TextStyle(
        fontSize: 12, color: AppColors.textSecondary)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
    onTap: onTap,
  );
}
