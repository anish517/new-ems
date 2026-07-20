import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user?.employeeId == null) return;
      final res = await ApiService().get(
        '${AppConstants.attendanceBase}/total-working-hour/${user!.employeeId}/',
      );
      if (mounted) setState(() { _attendanceData = res.data; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Good ${_greeting()}, ${user?.firstName ?? ''}!',
              style: const TextStyle(fontSize: 16)),
          const Text('Welcome back', style: TextStyle(fontSize: 12,
              color: AppColors.textSecondary)),
        ]),
        centerTitle: false,
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Iconsax.notification),
                onPressed: () => context.go('/notifications')),
            if (unread > 0)
              Positioned(right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
                )),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(user?.firstName[0].toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Attendance card
            _AttendanceSummaryCard(data: _attendanceData, isLoading: _isLoading),
            const SizedBox(height: 16),

            // Quick actions grid
            const Text('Quick Actions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _QuickCard('Check In/Out', Iconsax.clock, AppColors.primary,
                    () => context.go('/attendance')),
                _QuickCard('Apply Leave', Iconsax.calendar_remove, AppColors.warning,
                    () => context.go('/leave')),
                _QuickCard('My Tasks', Iconsax.task_square, AppColors.accent,
                    () => context.go('/tasks')),
                _QuickCard('Salary', Iconsax.money, AppColors.success,
                    () => context.go('/salary')),
                _QuickCard('Noticeboard', Iconsax.message_text, AppColors.info,
                    () => context.go('/noticeboard')),
                _QuickCard('Feedback', Iconsax.message_question, AppColors.remote,
                    () => context.go('/feedback')),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  const _AttendanceSummaryCard({this.data, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This Month', style: TextStyle(
                  color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${data?['total_working_hour'] ?? 0} hrs worked',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                _StatChip('Days Present',
                    '${data?['total_no_of_days_present'] ?? 0}'),
                const SizedBox(width: 12),
                _StatChip('Remaining',
                    '${data?['remaining_working_hour'] ?? 0} hrs'),
              ]),
            ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Text(value, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ],
      ),
    ),
  );
}
