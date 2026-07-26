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
import '../../auth/providers/auth_provider.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Zero-padded YYYY-MM-DD, matching the format used for string-based
  // date comparisons against the API's `date` field.
  String _fmtDate(NepaliDateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

      // Load attendance data for on-time count and weekly chart
      try {
        final attRes =
            await ApiService().get('${AppConstants.attendanceBase}/list/');
        final attData =
            attRes.data is List ? attRes.data : (attRes.data['results'] ?? []);
        if (attData is List && attData.isNotEmpty) {
          final now = NepaliDateTime.now();
          final today = _fmtDate(now);

          // Current week window (Monday -> Sunday) for the bar chart,
          // so it resets each week instead of accumulating all-time totals.
          // NepaliDateTime.weekday: 1=Sun .. 7=Sat
          final daysSinceMonday = now.weekday == 1 ? 6 : now.weekday - 2;
          final weekStart = now.subtract(Duration(days: daysSinceMonday));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final weekStartStr = _fmtDate(weekStart);
          final weekEndStr = _fmtDate(weekEnd);

          // Office hours: 10:00 AM - 5:00 PM.
          // "On time" window: check-in between 10:00 AM and 10:30 AM inclusive.
          const onTimeStartMinutes = 10 * 60; // 10:00 AM
          const onTimeEndMinutes = 10 * 60 + 30; // 10:30 AM

          final weekCounts = List<int>.filled(7, 0); // Mon=0..Sun=6
          final onTimeTodayNames = <String>[];

          // employeeKey -> display name
          final employeeNames = <String, String>{};
          // employeeKey -> { date -> wasOnTimeThatDay }
          final employeeAttendance = <String, Map<String, bool>>{};

          for (final log in attData) {
            final dateStr = log['date']?.toString() ?? '';
            if (dateStr.isEmpty) continue;

            // NOTE: adjust these field lookups to match your actual
            // /attendance/list/ response shape (verify against the API,
            // e.g. via the Node/Express attendance controller or a sample
            // response) - this tries the common shapes but silently falls
            // back to 'Unknown' / the raw id if none match.
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

            // Day-of-week for chart - only count if within the current week
            if (dateStr.compareTo(weekStartStr) >= 0 &&
                dateStr.compareTo(weekEndStr) <= 0) {
              try {
                final d = NepaliDateTime.parse(dateStr);
                // NepaliDateTime.weekday: 1=Sun .. 7=Sat
                // Chart index: 0=Mon, 1=Tue, ..., 5=Sat, 6=Sun
                final index = (d.weekday == 1) ? 6 : d.weekday - 2;
                weekCounts[index]++;
              } catch (_) {}
            }

            // Determine on-time status for this log entry
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
            // If an employee has more than one log for the same date,
            // treat the day as on-time only if every entry that day was.
            final existing = employeeAttendance[employeeKey]![dateStr];
            employeeAttendance[employeeKey]![dateStr] =
                existing == null ? isOnTime : (existing && isOnTime);

            if (dateStr == today && isOnTime) {
              onTimeTodayNames.add(employeeName);
            }
          }

          // Employees on-time on every single day they have a record for
          final alwaysOnTime = <String>[];
          employeeAttendance.forEach((key, dailyMap) {
            if (dailyMap.isNotEmpty &&
                dailyMap.values.every((onTime) => onTime)) {
              alwaysOnTime.add(employeeNames[key] ?? 'Unknown');
            }
          });

          // Normalize this week's counts relative to its busiest day
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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 16, right: 24, top: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome Back,',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                        Text(user?.fullName ?? 'Admin',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Iconsax.notification),
                        onPressed: () => context.go('/notifications'),
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceDark),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary,
                          backgroundImage: user?.profilePicture != null
                              ? NetworkImage(user!.profilePicture!)
                              : null,
                          child: user?.profilePicture == null
                              ? Text(user?.firstName[0].toUpperCase() ?? 'A',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                LayoutBuilder(builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  if (isMobile) {
                    return Column(children: [
                      _KpiCard(
                          title: 'Total Employees',
                          value: '$_employeeCount',
                          icon: Iconsax.people,
                          color: AppColors.primary),
                      const SizedBox(height: 16),
                      _KpiCard(
                          title: 'Pending Leaves',
                          value: '$_pendingLeaves',
                          icon: Iconsax.calendar_remove,
                          color: AppColors.warning),
                      const SizedBox(height: 16),
                      _KpiCard(
                          title: 'On Time Today',
                          value: '$_onTimeToday',
                          icon: Iconsax.clock,
                          color: AppColors.success,
                          onTap: _onTimeTodayNames.isEmpty
                              ? null
                              : () => _showNamesDialog(
                                  'On Time Today', _onTimeTodayNames)),
                    ]);
                  }
                  return Row(children: [
                    Expanded(
                        child: _KpiCard(
                            title: 'Total Employees',
                            value: '$_employeeCount',
                            icon: Iconsax.people,
                            color: AppColors.primary)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _KpiCard(
                            title: 'Pending Leaves',
                            value: '$_pendingLeaves',
                            icon: Iconsax.calendar_remove,
                            color: AppColors.warning)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _KpiCard(
                            title: 'On Time Today',
                            value: '$_onTimeToday',
                            icon: Iconsax.clock,
                            color: AppColors.success,
                            onTap: _onTimeTodayNames.isEmpty
                                ? null
                                : () => _showNamesDialog(
                                    'On Time Today', _onTimeTodayNames))),
                  ]);
                }),
              const SizedBox(height: 32),
              LayoutBuilder(builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isMobile
                          ? double.infinity
                          : constraints.maxWidth * 0.64,
                      height: 300,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance Overview',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: BarChart(BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 100,
                              barTouchData: BarTouchData(enabled: false),
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
                                    return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                            i >= 0 && i < 7 ? days[i] : '',
                                            style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12)));
                                  },
                                )),
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
                                return isWeekend
                                    ? _bar(i, val,
                                        color: AppColors.textSecondary)
                                    : _bar(i, val);
                              }),
                            )),
                          ),
                        ],
                      ),
                    ),
                    if (isMobile)
                      const SizedBox(height: 24)
                    else
                      const SizedBox(width: 24),
                    Container(
                      width: isMobile
                          ? double.infinity
                          : constraints.maxWidth * 0.33,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Actions',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _QuickActionBtn(
                            icon: Iconsax.document_download,
                            label: 'Attendance Report (CSV)',
                            color: AppColors.info,
                            onTap: () => _showReportDialog('attendance'),
                          ),
                          const SizedBox(height: 12),
                          _QuickActionBtn(
                            icon: Iconsax.document_download,
                            label: 'Salary Report (CSV)',
                            color: AppColors.success,
                            onTap: () => _showReportDialog('salary'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),
              if (_onTimeTodayNames.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Iconsax.clock,
                              color: AppColors.success, size: 20),
                          SizedBox(width: 8),
                          Text('On Time Today (10:00–10:30 AM)',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _onTimeTodayNames.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: AppColors.borderDark),
                        itemBuilder: (_, i) => ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Iconsax.user,
                                color: AppColors.primary, size: 18),
                          ),
                          title: Text(_onTimeTodayNames[i],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text('On Time',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              if (_alwaysOnTimeEmployees.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Iconsax.medal_star,
                              color: AppColors.success, size: 20),
                          SizedBox(width: 8),
                          Text('Always On Time (10:00–10:30 AM)',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Employees who checked in within the on-time window every recorded day',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _alwaysOnTimeEmployees
                            .map((name) => Chip(
                                  label: Text(name),
                                  backgroundColor:
                                      AppColors.success.withValues(alpha: 0.12),
                                  side: BorderSide(
                                      color: AppColors.success
                                          .withValues(alpha: 0.3)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              const Text('Management Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                int count = 3;
                if (constraints.maxWidth < 500) {
                  count = 1;
                } else if (constraints.maxWidth < 800) {
                  count = 2;
                }
                final ratio = constraints.maxWidth < 500 ? 4.0 : 2.5;
                return GridView.count(
                  crossAxisCount: count,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: ratio,
                  children: [
                    _ModuleTile(
                        icon: Iconsax.people,
                        title: 'Employees',
                        subtitle: 'Manage organization staff',
                        onTap: () => context.go('/employees')),
                    _ModuleTile(
                        icon: Iconsax.clock,
                        title: 'Attendance',
                        subtitle: 'View check-ins & logs',
                        onTap: () => context.go('/attendance')),
                    _ModuleTile(
                        icon: Iconsax.calendar_remove,
                        title: 'Leaves',
                        subtitle: 'Review leave requests',
                        onTap: () => context.go('/leave')),
                    _ModuleTile(
                        icon: Iconsax.money,
                        title: 'Salary',
                        subtitle: 'Process monthly payroll',
                        onTap: () => context.go('/salary')),
                    _ModuleTile(
                        icon: Iconsax.task_square,
                        title: 'Tasks',
                        subtitle: 'Assign and track projects',
                        onTap: () => context.go('/tasks')),
                    _ModuleTile(
                        icon: Iconsax.star1,
                        title: 'Performance',
                        subtitle: 'Review employee scores',
                        onTap: () => context.go('/performance')),
                    _ModuleTile(
                        icon: Iconsax.message_text,
                        title: 'Notices',
                        subtitle: 'Publish announcements',
                        onTap: () => context.go('/noticeboard')),
                    _ModuleTile(
                        icon: Iconsax.calendar,
                        title: 'Calendar',
                        subtitle: 'Holidays & Events',
                        onTap: () => context.go('/calendar')),
                    _ModuleTile(
                        icon: Iconsax.message_question,
                        title: 'Feedback',
                        subtitle: 'Employee complaints',
                        onTap: () => context.go('/feedback')),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, {Color color = AppColors.primary}) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
    ]);
  }

  void _showNamesDialog(String title, List<String> names) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: names.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              dense: true,
              leading: const Icon(Iconsax.user, size: 18),
              title: Text(names[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
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
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(
                'Generate ${type == 'attendance' ? 'Attendance' : 'Salary'} Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: List.generate(11, (index) {
                    final y = (now.year - 5) + index;
                    return DropdownMenuItem(
                        value: y, child: Text(y.toString()));
                  }),
                  onChanged: (val) => setState(() => selectedYear = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(12, (index) {
                    final m = index + 1;
                    return DropdownMenuItem(value: m, child: Text('Month $m'));
                  }),
                  onChanged: (val) => setState(() => selectedMonth = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Download')),
            ],
          );
        });
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
            SnackBar(content: Text('Downloading $type report...')));
      }
      launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ]),
        ]),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right, color: color, size: 20),
        ]),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          )),
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 18),
        ]),
      ),
    );
  }
}
