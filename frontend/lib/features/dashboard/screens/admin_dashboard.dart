import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _employeeCount = 0;
  int _pendingLeaves = 0;
  int _onTimeToday = 0;
  List<String> _onTimeTodayNames = [];
  List<String> _alwaysOnTimeEmployees = [];
  List<double> _weeklyAttendance = List.filled(7, 0.0);
  List<dynamic> _pendingRemoteRequests = [];
  List<dynamic> _pendingProfileChangeRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  String _fmtDate(NepaliDateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatNepaliHeaderDate(NepaliDateTime d) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = [
      '', 'Baishakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra',
      'Ashwin', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
    ];
    final wName = weekdays[(d.weekday - 1).clamp(0, 6)];
    final mName = months[d.month.clamp(1, 12)];
    return '$wName, ${d.day.toString().padLeft(2, '0')} $mName, ${d.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _fieldLabel(String fieldName) {
    const labels = {
      'phone_no': 'Phone Number',
      'personal_email': 'Personal Email',
      'emergency_phone_number': 'Emergency Contact',
    };
    return labels[fieldName] ?? fieldName.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _actionProfileChangeRequest(int id, String status) async {
    try {
      await ApiService().post(
        '${AppConstants.organizationBase}/profile-change-requests/$id/action/',
        data: {'status': status},
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Profile change request $status successfully'),
              ],
            ),
            backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating profile request: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _actionRemoteRequest(int id, String status) async {
    try {
      await ApiService().post(
        '${AppConstants.attendanceBase}/remote-requests/$id/action/',
        data: {'status': status},
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Request $status successfully'),
              ],
            ),
            backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating request: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final empRes =
          await ApiService().get('${AppConstants.organizationBase}/employees/');
      final employees =
          empRes.data is List ? empRes.data : (empRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() => _employeeCount = (employees as List).length);

      final leaveRes =
          await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      final leaves = leaveRes.data is List
          ? leaveRes.data
          : (leaveRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() {
        _pendingLeaves = (leaves as List)
            .where((l) => l['is_approved'] != true && l['is_reviewed'] != true)
            .length;
      });

      // Load remote requests
      try {
        final remoteRes = await ApiService().get('${AppConstants.attendanceBase}/remote-requests/');
        final remoteData = remoteRes.data is List ? remoteRes.data : (remoteRes.data['results'] ?? []);
        if (mounted) {
          setState(() {
            _pendingRemoteRequests = (remoteData as List).toList();
          });
        }
      } catch (_) {}

      // Load pending profile change requests
      try {
        final profileRes = await ApiService().get('${AppConstants.organizationBase}/profile-change-requests/?status=pending');
        final profileData = profileRes.data is List ? profileRes.data : (profileRes.data['results'] ?? []);
        if (mounted) {
          setState(() {
            _pendingProfileChangeRequests = (profileData as List).toList();
          });
        }
      } catch (_) {}

      // Load attendance data for on-time count and weekly chart
      try {
        final attRes =
            await ApiService().get('${AppConstants.attendanceBase}/list/');
        final attData =
            attRes.data is List ? attRes.data : (attRes.data['results'] ?? []);
        if (attData is List && attData.isNotEmpty) {
          final now = NepaliDateTime.now();
          final today = _fmtDate(now);

          final daysSinceMonday = now.weekday == 1 ? 6 : now.weekday - 2;
          final weekStart = now.subtract(Duration(days: daysSinceMonday));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final weekStartStr = _fmtDate(weekStart);
          final weekEndStr = _fmtDate(weekEnd);

          const onTimeStartMinutes = 10 * 60; // 10:00 AM
          const onTimeEndMinutes = 10 * 60 + 30; // 10:30 AM

          final weekCounts = List<int>.filled(7, 0); // Mon=0..Sun=6
          final onTimeTodayNames = <String>[];

          final employeeNames = <String, String>{};
          final employeeAttendance = <String, Map<String, bool>>{};

          for (final log in attData) {
            final dateStr = log['date']?.toString() ?? '';
            if (dateStr.isEmpty) continue;

            final employeeName = (log['employee_name'] ??
                    log['employeeName'] ??
                    (log['employee'] is Map
                        ? (log['employee']['full_name'] ??
                            log['employee']['fullName'] ??
                            log['employee']['name'])
                        : null) ??
                    'Unknown')
                .toString();
            final employeeKey = (log['employee_id'] ??
                    log['employeeId'] ??
                    (log['employee'] is Map
                        ? (log['employee']['_id'] ?? log['employee']['id'])
                        : log['employee']) ??
                    employeeName)
                .toString();

            if (dateStr.compareTo(weekStartStr) >= 0 &&
                dateStr.compareTo(weekEndStr) <= 0) {
              try {
                final d = NepaliDateTime.parse(dateStr);
                final index = (d.weekday == 1) ? 6 : d.weekday - 2;
                weekCounts[index]++;
              } catch (_) {}
            }

            bool isOnTime = false;
            final checkInStr = log['check_in_time']?.toString();
            if (checkInStr != null && checkInStr.isNotEmpty) {
              try {
                final parts = checkInStr.split(':');
                final h = int.parse(parts[0]);
                final m = parts.length > 1 ? int.parse(parts[1]) : 0;
                final totalMinutes = h * 60 + m;
                isOnTime = totalMinutes >= onTimeStartMinutes &&
                    totalMinutes <= onTimeEndMinutes;
              } catch (_) {}
            }

            employeeNames[employeeKey] = employeeName;
            employeeAttendance.putIfAbsent(employeeKey, () => {});
            final existing = employeeAttendance[employeeKey]![dateStr];
            employeeAttendance[employeeKey]![dateStr] =
                existing == null ? isOnTime : (existing && isOnTime);

            if (dateStr == today && isOnTime) {
              onTimeTodayNames.add(employeeName);
            }
          }

          final alwaysOnTime = <String>[];
          employeeAttendance.forEach((key, dailyMap) {
            if (dailyMap.isNotEmpty &&
                dailyMap.values.every((onTime) => onTime)) {
              alwaysOnTime.add(employeeNames[key] ?? 'Unknown');
            }
          });

          final maxCount = weekCounts.reduce((a, b) => a > b ? a : b);
          final normalized = weekCounts
              .map((c) => maxCount > 0 ? (c / maxCount) * 90.0 : 0.0)
              .toList();

          if (mounted) {
            setState(() {
              _onTimeToday = onTimeTodayNames.length;
              _onTimeTodayNames = onTimeTodayNames;
              _alwaysOnTimeEmployees = alwaysOnTime;
              _weeklyAttendance = normalized;
            });
          }
        }
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadStats());
    final user = ref.watch(currentUserProvider);
    final isDark = context.isDark;
    final nowNepali = NepaliDateTime.now();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 600;
            return RefreshIndicator(
              onRefresh: _loadStats,
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
                    // ── Top Header Section ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_getGreeting()}, ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Admin Portal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.fullName ?? 'Executive Admin',
                                style: TextStyle(
                                  fontSize: isTight ? 21 : 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
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
                                _formatNepaliHeaderDate(nowNepali),
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
                                          : 'A',
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

                const SizedBox(height: 28),

                // ── KPI Summary Cards ───────────────────────────────────────────
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 680;

                      if (isMobile) {
                        return Column(
                          children: [
                            _KpiCard(
                              title: 'Total Employees',
                              value: '$_employeeCount',
                              subtitle: 'Active staff members',
                              icon: Iconsax.people,
                              color: AppColors.primary,
                              onTap: () => context.go('/employees'),
                            ),
                            const SizedBox(height: 14),
                            _KpiCard(
                              title: 'Pending Leaves',
                              value: '$_pendingLeaves',
                              subtitle: 'Requires review',
                              icon: Iconsax.calendar_remove,
                              color: AppColors.warning,
                              onTap: () => context.go('/leave'),
                            ),
                            const SizedBox(height: 14),
                            _KpiCard(
                              title: 'On Time Today',
                              value: '$_onTimeToday',
                              subtitle: '10:00 - 10:30 AM check-ins',
                              icon: Iconsax.clock,
                              color: AppColors.success,
                              onTap: _onTimeTodayNames.isEmpty
                                  ? null
                                  : () => _showNamesDialog(
                                      'On Time Today', _onTimeTodayNames),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Total Employees',
                              value: '$_employeeCount',
                              subtitle: 'Active staff members',
                              icon: Iconsax.people,
                              color: AppColors.primary,
                              onTap: () => context.go('/employees'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'Pending Leaves',
                              value: '$_pendingLeaves',
                              subtitle: 'Requires review',
                              icon: Iconsax.calendar_remove,
                              color: AppColors.warning,
                              onTap: () => context.go('/leave'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'On Time Today',
                              value: '$_onTimeToday',
                              subtitle: '10:00 - 10:30 AM check-ins',
                              icon: Iconsax.clock,
                              color: AppColors.success,
                              onTap: _onTimeTodayNames.isEmpty
                                  ? null
                                  : () => _showNamesDialog(
                                      'On Time Today', _onTimeTodayNames),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 28),

                // ── Attendance Chart & Quick Actions Row ─────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    return Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weekly Attendance Chart
                        Expanded(
                          flex: isMobile ? 0 : 6,
                          child: Container(
                            height: 340,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Weekly Attendance Analytics',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Current Week (Mon – Sun) Activity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Iconsax.chart_2,
                                              size: 14, color: AppColors.primary),
                                          SizedBox(width: 6),
                                          Text(
                                            'Live Track',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Expanded(
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: 100,
                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipColor: (_) => isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          tooltipPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                          tooltipMargin: 8,
                                          getTooltipItem:
                                              (group, groupIndex, rod, rodIndex) {
                                            const days = [
                                              'Monday',
                                              'Tuesday',
                                              'Wednesday',
                                              'Thursday',
                                              'Friday',
                                              'Saturday',
                                              'Sunday'
                                            ];
                                            return BarTooltipItem(
                                              '${days[group.x.toInt()]}\n',
                                              TextStyle(
                                                color: context.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${rod.toY.toStringAsFixed(0)}% Activity',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (v, meta) {
                                              const days = [
                                                'Mon',
                                                'Tue',
                                                'Wed',
                                                'Thu',
                                                'Fri',
                                                'Sat',
                                                'Sun'
                                              ];
                                              final i = v.toInt();
                                              final isToday = (NepaliDateTime.now().weekday == 1 ? 6 : NepaliDateTime.now().weekday - 2) == i;
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                child: Text(
                                                  i >= 0 && i < 7 ? days[i] : '',
                                                  style: TextStyle(
                                                    color: isToday
                                                        ? AppColors.primary
                                                        : AppColors.textSecondary,
                                                    fontWeight: isToday
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(
                                            sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(
                                            sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(
                                            sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: const FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      barGroups: List.generate(7, (i) {
                                        final val = i < _weeklyAttendance.length
                                            ? _weeklyAttendance[i]
                                            : 0.0;
                                        final isWeekend = i >= 5;
                                        return _bar(i, val, isWeekend: isWeekend);
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (isMobile)
                          const SizedBox(height: 20)
                        else
                          const SizedBox(width: 20),

                        // Quick Actions & Reports
                        Expanded(
                          flex: isMobile ? 0 : 4,
                          child: Container(
                            height: isMobile ? null : 340,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.flash_1,
                                        size: 20, color: AppColors.accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Quick Exports',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Download monthly organization CSV reports',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _QuickActionBtn(
                                  icon: Iconsax.document_download,
                                  title: 'Attendance Report',
                                  subtitle: 'Monthly check-ins & hours CSV',
                                  color: AppColors.info,
                                  onTap: () => _showReportDialog('attendance'),
                                ),
                                const SizedBox(height: 12),
                                _QuickActionBtn(
                                  icon: Iconsax.wallet_money,
                                  title: 'Salary & Payroll Report',
                                  subtitle: 'Monthly payslip & tax breakdown',
                                  color: AppColors.success,
                                  onTap: () => _showReportDialog('salary'),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Iconsax.info_circle,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reports include Bikram Sambat date filters & SSF deductions.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── On Time Employees Recognition ───────────────────────────────
                if (_onTimeTodayNames.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Iconsax.timer_1,
                                      color: AppColors.success, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'On Time Today (10:00 – 10:30 AM)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      'Checked in on schedule this morning',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_onTimeTodayNames.length} Employees',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _onTimeTodayNames.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        AppColors.success.withValues(alpha: 0.15),
                                    child: const Icon(Iconsax.user,
                                        size: 12, color: AppColors.success),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Always On Time Hall of Fame ─────────────────────────────────
                if (_alwaysOnTimeEmployees.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Iconsax.medal_star,
                                  color: AppColors.warning, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Punctuality Champions',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Consistently arrived on schedule on every recorded workday',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _alwaysOnTimeEmployees.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.award,
                                      size: 14, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Pending Profile Update Requests ───────────────────────────────
                if (_pendingProfileChangeRequests.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Iconsax.user_edit, size: 18, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Profile Update Requests (${_pendingProfileChangeRequests.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingProfileChangeRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final req = _pendingProfileChangeRequests[i];
                      final field = req['field_name'] ?? '';
                      final val = req['new_value']?.toString() ?? '-';
                      final oldVal = req['old_value']?.toString() ?? '';
                      final employeeName = req['employee_name']?.toString() ?? 'Staff Member';
                      final employeeCode = req['employee_code']?.toString() ?? '';
                      final int reqId = (req['id'] is int)
                          ? (req['id'] as int)
                          : (int.tryParse('${req['id']}') ?? 0);
                      final createdAt = req['created_at'] != null
                          ? req['created_at'].toString().split('T').first
                          : 'N/A';

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                      child: const Icon(Iconsax.user_edit, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              employeeName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15.5,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            if (employeeCode.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: context.card,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: context.border),
                                                ),
                                                child: Text(
                                                  employeeCode,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _fieldLabel(field),
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Requested: $createdAt',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PENDING REVIEW',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (oldVal.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Current: ',
                                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          oldVal,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.textPrimary.withValues(alpha: 0.7),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Requested New: ',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        val,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _actionProfileChangeRequest(reqId, 'rejected'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Iconsax.close_circle, size: 16, color: Color(0xFFEF4444)),
                                          SizedBox(width: 6),
                                          Text(
                                            'Reject',
                                            style: TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _actionProfileChangeRequest(reqId, 'approved'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            'Approve Update',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // ── Pending Remote Work Requests ─────────────────────────────────
                if (_pendingRemoteRequests.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Iconsax.home_wifi,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Remote Work Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingRemoteRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final req = _pendingRemoteRequests[i];
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.border, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.accent
                                          .withValues(alpha: 0.12),
                                      child: const Icon(Iconsax.user,
                                          size: 16, color: AppColors.accent),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      req['employee_name'] ?? 'Unknown Employee',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: Text(
                                    req['created_at'] != null
                                        ? _fmtDate(DateTime.parse(
                                                req['created_at'])
                                            .toNepaliDateTime())
                                        : 'N/A',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Reason: ${req['reason'] ?? 'No reason provided'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _actionRemoteRequest(req['id'], 'rejected'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Iconsax.close_circle, size: 16, color: Color(0xFFEF4444)),
                                          SizedBox(width: 6),
                                          Text(
                                            'Reject',
                                            style: TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _actionRemoteRequest(req['id'], 'approved'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            'Approve WFH',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // ── Enterprise Management Modules ───────────────────────────────
                Row(
                  children: [
                    const Icon(Iconsax.grid_5,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Management Modules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    if (constraints.maxWidth < 600) {
                      crossAxisCount = 1;
                    } else if (constraints.maxWidth < 980) {
                      crossAxisCount = 2;
                    }

                    final childAspectRatio = constraints.maxWidth < 600 ? 3.2 : 2.5;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: childAspectRatio,
                      children: [
                        _ModuleTile(
                          icon: Iconsax.people,
                          title: 'Employees',
                          subtitle: 'Profiles, documents & contracts',
                          color: const Color(0xFF3B82F6),
                          onTap: () => context.go('/employees'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.clock,
                          title: 'Attendance',
                          subtitle: 'GPS geofencing & time logs',
                          color: const Color(0xFF10B981),
                          onTap: () => context.go('/attendance'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.calendar_remove,
                          title: 'Leaves',
                          subtitle: 'Quota balance & requests',
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.go('/leave'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.money_recive,
                          title: 'Salary & Payroll',
                          subtitle: 'B.S. payroll & payslips',
                          color: const Color(0xFF14B8A6),
                          onTap: () => context.go('/salary'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.task_square,
                          title: 'Tasks & Projects',
                          subtitle: 'Assignments & progress',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.go('/tasks'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.star1,
                          title: 'Performance',
                          subtitle: 'KPIs & appraisal reports',
                          color: const Color(0xFFF43F5E),
                          onTap: () => context.go('/performance'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.message_text,
                          title: 'Notices',
                          subtitle: 'Broadcasts & announcements',
                          color: const Color(0xFF6366F1),
                          onTap: () => context.go('/noticeboard'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.calendar,
                          title: 'Nepali Calendar',
                          subtitle: 'Holidays, events & B.S. dates',
                          color: const Color(0xFF0EA5E9),
                          onTap: () => context.go('/calendar'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.message_question,
                          title: 'Feedback',
                          subtitle: 'Staff inquiries & grievances',
                          color: const Color(0xFFFB923C),
                          onTap: () => context.go('/feedback'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
  }

  BarChartGroupData _bar(int x, double y, {bool isWeekend = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: isWeekend
              ? LinearGradient(
                  colors: [
                    AppColors.textSecondary.withValues(alpha: 0.3),
                    AppColors.textSecondary.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  void _showNamesDialog(String title, List<String> names) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.clock,
                          color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ctx.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: names.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: ctx.border),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: const Icon(Iconsax.user,
                            size: 14, color: AppColors.primary),
                      ),
                      title: Text(
                        names[i],
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ctx.textPrimary,
                        ),
                      ),
                      trailing: const Icon(Iconsax.tick_circle,
                          color: AppColors.success, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDialog(String type) async {
    final now = NepaliDateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: ctx.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: ctx.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (type == 'attendance'
                                      ? AppColors.info
                                      : AppColors.success)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Iconsax.document_download,
                              color: type == 'attendance'
                                  ? AppColors.info
                                  : AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generate ${type == 'attendance' ? 'Attendance' : 'Salary'} Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ctx.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Select Bikram Sambat period',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<int>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year (B.S.)',
                          prefixIcon: Icon(Iconsax.calendar_1, size: 20),
                        ),
                        items: List.generate(11, (index) {
                          final y = (now.year - 5) + index;
                          return DropdownMenuItem(
                              value: y, child: Text('$y B.S.'));
                        }),
                        onChanged: (val) =>
                            setDialogState(() => selectedYear = val!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          prefixIcon: Icon(Iconsax.calendar_2, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Baishakh (01)')),
                          DropdownMenuItem(value: 2, child: Text('Jestha (02)')),
                          DropdownMenuItem(value: 3, child: Text('Ashadh (03)')),
                          DropdownMenuItem(value: 4, child: Text('Shrawan (04)')),
                          DropdownMenuItem(value: 5, child: Text('Bhadra (05)')),
                          DropdownMenuItem(value: 6, child: Text('Ashwin (06)')),
                          DropdownMenuItem(value: 7, child: Text('Kartik (07)')),
                          DropdownMenuItem(value: 8, child: Text('Mangsir (08)')),
                          DropdownMenuItem(value: 9, child: Text('Poush (09)')),
                          DropdownMenuItem(value: 10, child: Text('Magh (10)')),
                          DropdownMenuItem(value: 11, child: Text('Falgun (11)')),
                          DropdownMenuItem(value: 12, child: Text('Chaitra (12)')),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedMonth = val!),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: type == 'attendance'
                                    ? AppColors.info
                                    : AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Download',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.accessTokenKey) ?? '';
      const baseUrl = AppConstants.baseUrl;
      final endpoint = type == 'attendance'
          ? AppConstants.attendanceBase
          : AppConstants.salaryBase;
      final url =
          '$baseUrl$endpoint/generate-report/?year=$selectedYear&month=$selectedMonth&token=$token';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.document_download,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Downloading $type report for $selectedYear / $selectedMonth...'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
      launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.5,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Iconsax.arrow_right_3, size: 16, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.direct_down, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
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
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_right_3,
                  color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
