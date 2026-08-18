import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../../core/providers/date_provider.dart';

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
      if (user?.employeeId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final res = await ApiService().get(
        '${AppConstants.attendanceBase}/total-working-hour/${user!.employeeId}/',
      );
      if (mounted) {
        setState(() {
          _attendanceData = res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon() {
    final h = DateTime.now().hour;
    if (h < 12) return Iconsax.sun_1;
    if (h < 17) return Iconsax.sun;
    return Iconsax.moon;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadData());
    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final nowNepali = NepaliDateTime.now();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 600;
            return RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTight ? 14 : 24,
                  vertical: isTight ? 16 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Bar ───────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_getGreetingIcon(),
                                      size: 16, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_getGreeting()},',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.fullName ?? 'Employee',
                                style: TextStyle(
                                  fontSize: isTight ? 20 : 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: context.textPrimary,
                                ),
                              ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Iconsax.calendar_1,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '${NepaliDateFormat('EEEE, MMMM d, y').format(nowNepali)} (B.S.)',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const ThemeToggleBtn(),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Iconsax.notification, size: 20),
                              tooltip: 'Notifications',
                              onPressed: () => context.go('/notifications'),
                              style: IconButton.styleFrom(
                                backgroundColor: context.surface,
                                padding: const EdgeInsets.all(10),
                                side: BorderSide(color: context.border, width: 1),
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: context.surface,
                              backgroundImage: user?.profilePicture != null
                                  ? NetworkImage(user!.profilePicture!)
                                  : null,
                              child: user?.profilePicture == null
                                  ? Text(
                                      user?.firstName.isNotEmpty == true
                                          ? user!.firstName[0].toUpperCase()
                                          : 'E',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Responsive Layout Builder ────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Side: Attendance Hero Card + Fast Action
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _AttendanceSummaryCard(
                                  data: _attendanceData,
                                  isLoading: _isLoading,
                                  onClockTap: () => context.go('/attendance'),
                                ),
                                const SizedBox(height: 20),
                                _buildShiftInfoCard(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Right Side: Quick Action Modules
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Workspace & Actions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Quick shortcuts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildActionsGrid(context, crossAxisCount: 3),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile / Narrow Layout
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AttendanceSummaryCard(
                          data: _attendanceData,
                          isLoading: _isLoading,
                          onClockTap: () => context.go('/attendance'),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Workspace & Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              'Tap to open',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildActionsGrid(context, crossAxisCount: 2),
                        const SizedBox(height: 20),
                        _buildShiftInfoCard(context),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
  }

  Widget _buildShiftInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.info_circle,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standard Shift: 10:00 AM – 5:00 PM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Punctuality window is 10:00 to 10:30 AM. Saturday is a weekly holiday.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context, {required int crossAxisCount}) {
    final actions = [
      _QuickCard(
        label: 'Attendance',
        subtitle: 'Check in / out & GPS log',
        icon: Iconsax.clock,
        color: const Color(0xFF10B981),
        onTap: () => context.go('/attendance'),
      ),
      _QuickCard(
        label: 'Apply Leave',
        subtitle: 'Request time off & balance',
        icon: Iconsax.calendar_remove,
        color: const Color(0xFFF59E0B),
        onTap: () => context.go('/leave'),
      ),
      _QuickCard(
        label: 'My Tasks',
        subtitle: 'Projects, to-dos & progress',
        icon: Iconsax.task_square,
        color: const Color(0xFF0EA5E9),
        onTap: () => context.go('/tasks'),
      ),
      _QuickCard(
        label: 'Salary & Payslip',
        subtitle: 'Monthly payroll & records',
        icon: Iconsax.money_recive,
        color: const Color(0xFF14B8A6),
        onTap: () => context.go('/salary'),
      ),
      _QuickCard(
        label: 'Noticeboard',
        subtitle: 'Company announcements',
        icon: Iconsax.message_text,
        color: const Color(0xFF6366F1),
        onTap: () => context.go('/noticeboard'),
      ),
      _QuickCard(
        label: 'Nepali Calendar',
        subtitle: 'B.S. dates & holidays',
        icon: Iconsax.calendar,
        color: const Color(0xFF3B82F6),
        onTap: () => context.go('/calendar'),
      ),
      _QuickCard(
        label: 'Performance',
        subtitle: 'Scores & appraisal metrics',
        icon: Iconsax.star1,
        color: const Color(0xFFF43F5E),
        onTap: () => context.go('/performance'),
      ),
      _QuickCard(
        label: 'Policy',
        subtitle: 'Workplace code & terms',
        icon: Iconsax.document_text,
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/policy'),
      ),
      _QuickCard(
        label: 'Feedback',
        subtitle: 'Staff inquiries & suggestions',
        icon: Iconsax.message_question,
        color: const Color(0xFFFB923C),
        onTap: () => context.go('/feedback'),
      ),
    ];

    return ResponsiveGridList(
      scrollable: false,
      padding: EdgeInsets.zero,
      minItemWidth: 150,
      itemCount: actions.length,
      itemBuilder: (context, index) => AspectRatio(
        aspectRatio: 1.45,
        child: actions[index],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Hero Card
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final VoidCallback onClockTap;

  const _AttendanceSummaryCard({
    this.data,
    required this.isLoading,
    required this.onClockTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final totalHours = data?['total_working_hour'] ?? 0;
    final daysPresent = data?['total_no_of_days_present'] ?? 0;
    final remainingHours = data?['remaining_working_hour'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
              : [const Color(0xFF4F46E5), const Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.calendar_tick,
                              color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'This Month Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onClockTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.finger_scan,
                                size: 15, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Clock In / Out',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '$totalHours hrs worked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recorded working hours for current Nepali month',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Iconsax.user_tick,
                        label: 'Days Present',
                        value: '$daysPresent days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        icon: Iconsax.timer_pause,
                        label: 'Remaining Hours',
                        value: '$remainingHours hrs',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Module Card
// ─────────────────────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Icon(Iconsax.arrow_right_3,
                      size: 15, color: context.textSecondary),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
